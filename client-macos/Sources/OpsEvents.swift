import SwiftUI
import AppKit

struct OpsEvent: Decodable, Identifiable {
    let id: Int
    let ts: Int
    let kind: String
    let level: String
    let title: String
    let detail: String
}

struct OpsEventsResponse: Decodable {
    let events: [OpsEvent]
    let last: Int
}

struct OpsBackup: Decodable {
    let unit: String
    let scope: String
    let ok: Bool
    let result: String
    let last: String
}

struct OpsUpdates: Decodable {
    let total: Int
    let security: Int
}

struct OpsSsh: Decodable {
    let failed: Int
    let sources: Int
}

struct OpsTailscale: Decodable {
    let online: Int
    let total: Int
    let offline: [String]
}

struct OpsHealth: Decodable {
    let backups: [OpsBackup]
    let rebootRequired: Bool
    let updates: OpsUpdates?
    let ssh: OpsSsh?
    let tailscale: OpsTailscale?
}

struct OpsHostEvent: Identifiable {
    let host: OpsHost
    let event: OpsEvent
    var id: String { host.rawValue + "#" + String(event.id) }
    var date: Date { Date(timeIntervalSince1970: Double(event.ts) / 1000) }
}

let opsEventKinds: [(String, String)] = [("all", "Tất cả loại"), ("egress", "Đường hầm"), ("unit", "Dịch vụ"), ("net", "Mạng"), ("sync", "Đồng bộ")]

func opsEventKindLabel(_ kind: String) -> String {
    opsEventKinds.first { $0.0 == kind }?.1 ?? kind
}

func opsEventStyle(_ level: String) -> (String, Color) {
    switch level {
    case "ok": return ("checkmark.circle.fill", opsGreen)
    case "warn": return ("exclamationmark.triangle.fill", .orange)
    case "error": return ("xmark.octagon.fill", .red)
    default: return ("info.circle.fill", .blue)
    }
}

private let opsEventFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "dd/MM HH:mm:ss"
    return f
}()

private let opsRelativeFormatter: RelativeDateTimeFormatter = {
    let f = RelativeDateTimeFormatter()
    f.locale = Locale(identifier: "vi")
    f.unitsStyle = .short
    return f
}()

func opsEventClock(_ date: Date) -> String {
    opsEventFormatter.string(from: date)
}

func opsEventAgo(_ date: Date) -> String {
    opsRelativeFormatter.localizedString(for: date, relativeTo: Date())
}

func opsBackupTime(_ raw: String) -> String {
    let parts = raw.split(separator: " ")
    guard parts.count >= 3 else { return "—" }
    return "\(parts[1].suffix(5)) \(parts[2].prefix(5))"
}

func opsHealthLine(_ h: OpsHealth) -> String {
    var parts: [String] = []
    if let b = h.backups.first { parts.append(b.ok ? "Backup " + opsBackupTime(b.last) : "Backup lỗi") }
    if h.rebootRequired { parts.append("cần reboot") }
    if let u = h.updates, u.total > 0 { parts.append("\(u.total) gói chờ" + (u.security > 0 ? " (\(u.security) bảo mật)" : "")) }
    return parts.joined(separator: " · ")
}

extension OpsModel {
    func fetchEvents(_ h: OpsHost) {
        if eventBusy.contains(h) { return }
        let after = eventCursor[h] ?? 0
        guard let url = URL(string: baseUrl(h) + "/v1/ops-events?after=\(after)&limit=500") else { return }
        eventBusy.insert(h)
        session.dataTask(with: state.authedRequest(url)) { [weak self] data, resp, _ in
            guard let self = self else { return }
            var decoded: OpsEventsResponse?
            if (resp as? HTTPURLResponse)?.statusCode == 200, let data = data {
                decoded = try? self.decoder.decode(OpsEventsResponse.self, from: data)
            }
            DispatchQueue.main.async {
                self.eventBusy.remove(h)
                guard let r = decoded else { return }
                if r.last < after {
                    self.events[h] = r.events
                } else if !r.events.isEmpty {
                    var list = (self.events[h] ?? []) + r.events
                    if list.count > 500 { list.removeFirst(list.count - 500) }
                    self.events[h] = list
                }
                self.eventCursor[h] = r.last
            }
        }.resume()
    }

    func mergedEvents(_ only: OpsHost? = nil) -> [OpsHostEvent] {
        let hosts = only.map { [$0] } ?? OpsHost.allCases
        return hosts
            .flatMap { h in (events[h] ?? []).map { OpsHostEvent(host: h, event: $0) } }
            .sorted { $0.event.ts > $1.event.ts }
    }

    func recentErrorCount(_ h: OpsHost, within seconds: TimeInterval = 3600) -> Int {
        let cutoff = Date().addingTimeInterval(-seconds)
        return (events[h] ?? []).filter { $0.level == "error" && Date(timeIntervalSince1970: Double($0.ts) / 1000) > cutoff }.count
    }
}

struct OpsHealthTile: View {
    let title: String
    let value: String
    let sub: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 11)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 16, weight: .semibold, design: .rounded)).foregroundStyle(color).lineLimit(1)
            Text(sub).font(.system(size: 10.5)).foregroundStyle(.secondary).lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct OpsHealthCard: View {
    let health: OpsHealth?

    var body: some View {
        OpsCard("Sức khỏe hệ thống") {
            if let h = health {
                HStack(alignment: .top, spacing: 14) {
                    backup(h)
                    Divider()
                    OpsHealthTile(title: "Khởi động lại", value: h.rebootRequired ? "Cần reboot" : "Không cần", sub: h.rebootRequired ? "Có bản cập nhật chờ áp dụng" : "Hệ thống đang dùng bản mới nhất", color: h.rebootRequired ? .orange : opsGreen)
                    Divider()
                    updates(h)
                    Divider()
                    ssh(h)
                    Divider()
                    tailscale(h)
                }
            } else {
                Text("Bridge chưa trả dữ liệu sức khỏe (đang thu thập hoặc chưa cập nhật backend).")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func backup(_ h: OpsHealth) -> some View {
        if h.backups.isEmpty {
            OpsHealthTile(title: "Backup", value: "—", sub: "Không có timer backup", color: .secondary)
        } else if h.backups.allSatisfy({ $0.ok }) {
            OpsHealthTile(title: "Backup", value: "Thành công", sub: "Lần gần nhất " + opsBackupTime(h.backups[0].last), color: opsGreen)
        } else {
            OpsHealthTile(title: "Backup", value: "Lỗi", sub: h.backups.filter { !$0.ok }.map { $0.unit }.joined(separator: ", "), color: .red)
        }
    }

    @ViewBuilder
    private func updates(_ h: OpsHealth) -> some View {
        if let u = h.updates {
            if u.total == 0 {
                OpsHealthTile(title: "Cập nhật", value: "Mới nhất", sub: "Không có gói chờ", color: opsGreen)
            } else {
                OpsHealthTile(title: "Cập nhật", value: "\(u.total) gói", sub: "\(u.security) bản vá bảo mật", color: u.security > 0 ? .orange : .secondary)
            }
        } else {
            OpsHealthTile(title: "Cập nhật", value: "—", sub: "Không đọc được", color: .secondary)
        }
    }

    @ViewBuilder
    private func ssh(_ h: OpsHealth) -> some View {
        if let s = h.ssh {
            OpsHealthTile(title: "SSH thất bại 24h", value: "\(s.failed)", sub: s.failed == 0 ? "Không có lần nào" : "Từ \(s.sources) địa chỉ nguồn", color: s.failed == 0 ? opsGreen : (s.failed >= 20 ? .red : .orange))
        } else {
            OpsHealthTile(title: "SSH thất bại 24h", value: "—", sub: "Không đọc được", color: .secondary)
        }
    }

    @ViewBuilder
    private func tailscale(_ h: OpsHealth) -> some View {
        if let t = h.tailscale {
            OpsHealthTile(title: "Tailscale", value: "\(t.online)/\(t.total) online", sub: t.offline.isEmpty ? "Mọi thiết bị đang kết nối" : "Offline: " + t.offline.joined(separator: ", "), color: t.offline.isEmpty ? opsGreen : .secondary)
        } else {
            OpsHealthTile(title: "Tailscale", value: "—", sub: "Không đọc được", color: .secondary)
        }
    }
}

struct OpsEventsPage: View {
    @ObservedObject var model: OpsModel
    @State private var hostFilter = "all"
    @State private var kind = "all"
    @State private var onlyIssues = false

    private var rows: [OpsHostEvent] {
        let only = OpsHost(rawValue: hostFilter)
        return model.mergedEvents(only).filter { row in
            (kind == "all" || row.event.kind == kind) && (!onlyIssues || row.event.level == "warn" || row.event.level == "error")
        }
    }

    var body: some View {
        let list = rows
        VStack(spacing: 0) {
            toolbar(list)
                .background(Color(nsColor: .windowBackgroundColor))
                .zIndex(1)
            Divider()
            if list.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.badge.checkmark").font(.system(size: 28)).foregroundStyle(.secondary)
                    Text("Chưa có sự kiện nào khớp bộ lọc trong 24 giờ qua").font(.system(size: 13)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(list.prefix(300)) { row in
                            eventRow(row)
                            Divider().opacity(0.4)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    private func toolbar(_ list: [OpsHostEvent]) -> some View {
        let errors = list.filter { $0.event.level == "error" }.count
        let warns = list.filter { $0.event.level == "warn" }.count
        let oks = list.filter { $0.event.level == "ok" }.count
        return HStack(spacing: 10) {
            Picker("", selection: $hostFilter) {
                Text("Cả hai máy").tag("all")
                ForEach(OpsHost.allCases) { Text($0.rawValue).tag($0.rawValue) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 250)
            Picker("", selection: $kind) {
                ForEach(opsEventKinds, id: \.0) { Text($0.1).tag($0.0) }
            }
            .labelsHidden()
            .frame(width: 130)
            Toggle("Chỉ cảnh báo và lỗi", isOn: $onlyIssues).toggleStyle(.switch).controlSize(.small).lineLimit(1).fixedSize()
            Spacer()
            OpsPill(text: "\(errors) lỗi", color: errors > 0 ? .red : .secondary)
            OpsPill(text: "\(warns) cảnh báo", color: warns > 0 ? .orange : .secondary)
            OpsPill(text: "\(oks) phục hồi", color: oks > 0 ? opsGreen : .secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func eventRow(_ row: OpsHostEvent) -> some View {
        let style = opsEventStyle(row.event.level)
        return HStack(alignment: .top, spacing: 10) {
            Text(opsEventClock(row.date))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)
            Image(systemName: style.0).foregroundStyle(style.1).frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(row.event.title).font(.system(size: 12.5, weight: .medium))
                if !row.event.detail.isEmpty {
                    Text(row.event.detail).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            Text(opsEventKindLabel(row.event.kind))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7).padding(.vertical, 2)
                .background(Capsule().fill(Color.primary.opacity(0.08)))
            if hostFilter == "all" {
                Text(row.host.rawValue)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Capsule().fill(Color.accentColor.opacity(0.14)))
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 6)
        .background(row.event.level == "error" ? Color.red.opacity(0.06) : Color.clear)
    }
}
