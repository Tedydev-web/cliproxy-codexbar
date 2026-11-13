import SwiftUI
import AppKit

let quickMenuWidth: CGFloat = 440

private let quickClock: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "HH:mm:ss"
    return f
}()

private func quickAddress(_ url: String) -> String {
    URL(string: url)?.host ?? "-"
}

extension OpsModel {
    func health(_ h: OpsHost) -> (String, Color) {
        guard let st = statuses[h] else {
            return errors[h] == nil ? ("Đang tải", .gray) : ("Mất kết nối", .red)
        }
        if errors[h] != nil { return ("Mất kết nối", .red) }
        if !st.failed.isEmpty { return ("\(st.failed.count) unit lỗi", .orange) }
        let warn = warnings(h)
        if warn > 0 { return ("\(warn) cảnh báo", .orange) }
        return ("Ổn định", opsGreen)
    }

    func warnings(_ h: OpsHost) -> Int {
        attention(h).filter { $0.color == .red || $0.color == .orange || $0.color == .yellow }.count
    }
}

struct OpsQuickMetric: View {
    let label: String
    let pct: Double
    let detail: String

    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 2)
                Text(detail)
                    .font(.system(size: 9.5))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                Text("\(Int(pct))%")
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .frame(width: 34, alignment: .trailing)
            }
            OpsGauge(pct: pct, color: opsGaugeColor(pct))
        }
    }
}

struct OpsQuickHostCard: View {
    @ObservedObject var ops: OpsModel
    let host: OpsHost
    let address: String

    var body: some View {
        let st = ops.statuses[host]
        let health = ops.health(host)
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: host.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.accentColor)
                Text(host.rawValue)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Circle().fill(health.1).frame(width: 8, height: 8)
            }
            Text("\(address) · \(st?.metrics?.uptime ?? "—")")
                .font(.system(size: 9.5, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if let m = st?.metrics {
                OpsQuickMetric(label: "CPU", pct: m.cpuPercent, detail: "\(m.cpuCount) core")
                OpsQuickMetric(label: "RAM", pct: m.ramPercent, detail: String(format: "%.1f/%.1f GB", m.ramUsedGb, m.ramTotalGb))
                OpsQuickMetric(label: "Ổ đĩa", pct: m.diskPercent, detail: String(format: "%.0f/%.0f GB", m.diskUsedGb, m.diskTotalGb))
                Text("Load " + m.loadAvg.map { String(format: "%.2f", $0) }.joined(separator: "  "))
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(.secondary)
            } else {
                Text(ops.errors[host] ?? "Đang tải dữ liệu…")
                    .font(.system(size: 10.5))
                    .foregroundStyle(ops.errors[host] == nil ? Color.secondary : Color.red)
                    .lineLimit(2)
            }
            Divider().opacity(0.5)
            HStack {
                OpsPill(text: health.0, color: health.1)
                Spacer()
                if let st = st {
                    let services = st.units.filter { !$0.isTimer }
                    let running = services.filter { $0.state == "active" }.count
                    Text("\(running)/\(services.count) dịch vụ")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            if let st = st {
                let timers = st.units.filter { $0.isTimer }
                let restarts = st.units.reduce(0) { $0 + ($1.restarts ?? 0) }
                Text("Timer \(timers.filter { $0.state == "active" }.count)/\(timers.count) · restart \(restarts)")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                if let hl = st.health {
                    let line = opsHealthLine(hl)
                    if !line.isEmpty {
                        Text(line)
                            .font(.system(size: 10))
                            .foregroundStyle(hl.rebootRequired || hl.backups.contains { !$0.ok } ? Color.orange : Color.secondary)
                            .lineLimit(2)
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.08), lineWidth: 0.5))
    }
}

struct UbuntuServerQuickMenuView: View {
    @ObservedObject var state: QuotaState
    @ObservedObject var ops: OpsModel
    @State private var searchText: String = ""
    @Environment(\.colorScheme) private var scheme

    var activeDevPorts: [PortInfo] {
        let primary = state.sysPorts.filter { !$0.isInternal && $0.port != 8317 && $0.port != 8318 }
        let base = !primary.isEmpty ? primary : state.sysPorts.filter { !$0.isInternal }
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if q.isEmpty { return base }
        return base.filter { p in
            String(p.port).contains(q) ||
            p.process.lowercased().contains(q) ||
            p.project.lowercased().contains(q) ||
            p.cwd.lowercased().contains(q)
        }
    }

    var attentionRows: [(OpsHost, OpsAttention)] {
        OpsHost.allCases.flatMap { h in
            ops.attention(h)
                .filter { $0.color != .blue }
                .map { (h, $0) }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            HStack(alignment: .top, spacing: 8) {
                OpsQuickHostCard(ops: ops, host: .homelab, address: quickAddress(state.hostUrl))
                OpsQuickHostCard(ops: ops, host: .node, address: quickAddress(state.baseUrl))
            }
            egressSection
            syncSection
            attentionSection
            eventsSection
            portsSection
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(width: quickMenuWidth, alignment: .topLeading)
    }

    private var header: some View {
        let total = OpsHost.allCases.reduce(0) { $0 + ops.warnings($1) }
        let lost = OpsHost.allCases.filter { ops.errors[$0] != nil }.count
        let pill: (String, Color) = lost > 0 ? ("\(lost) máy mất kết nối", .red) : (total > 0 ? ("\(total) cảnh báo", .orange) : ("Mọi thứ ổn định", opsGreen))
        let stamp = ops.updated.values.max().map { quickClock.string(from: $0) } ?? "—"
        return HStack(spacing: 8) {
            Image(systemName: "waveform.path.ecg.rectangle.fill")
                .font(.system(size: 16))
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 1) {
                Text("Orbiter Ops").font(.system(size: 14, weight: .bold))
                Text("Cập nhật \(stamp)").font(.system(size: 9.5)).foregroundStyle(.secondary)
            }
            Spacer()
            OpsPill(text: pill.0, color: pill.1)
        }
    }

    private func sectionTitle(_ title: String, _ trailing: String? = nil) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            if let t = trailing {
                Text(t).font(.system(size: 9.5)).foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder
    private var egressSection: some View {
        if let eg = ops.statuses[.node]?.egress, eg.ok, let servers = eg.servers, !servers.isEmpty {
            VStack(alignment: .leading, spacing: 5) {
                sectionTitle("Egress 3 tầng", eg.active.map { "đang dùng: \($0)" } ?? "không có tầng sống")
                HStack(spacing: 6) {
                    ForEach(servers) { s in
                        let up = s.status.hasPrefix("UP")
                        let active = s.name == eg.active
                        HStack(spacing: 4) {
                            Circle().fill(up ? opsGreen : Color.red).frame(width: 6, height: 6)
                            Text(s.name).font(.system(size: 10.5, weight: .medium)).lineLimit(1)
                            Spacer(minLength: 0)
                            Text(active ? "ĐANG DÙNG" : (up ? "sẵn sàng" : "DOWN"))
                                .font(.system(size: 8.5, weight: .bold))
                                .foregroundStyle(active ? opsGreen : (up ? Color.secondary : Color.red))
                                .brightness(scheme == .light && (active || !up) ? -0.25 : 0)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 5)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 7).fill(active ? opsGreen.opacity(0.14) : Color.primary.opacity(0.05)))
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(active ? opsGreen.opacity(0.6) : Color.primary.opacity(0.08), lineWidth: 0.5))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var syncSection: some View {
        if let sync = ops.statuses[.homelab]?.sync, sync.ok {
            let peers = sync.peers ?? []
            let folders = (sync.folders ?? []).sorted { $0.pct < $1.pct }
            VStack(alignment: .leading, spacing: 5) {
                sectionTitle("Syncthing", "\(peers.filter { $0.connected }.count)/\(peers.count) thiết bị")
                HStack(spacing: 10) {
                    ForEach(peers) { p in
                        HStack(spacing: 4) {
                            Circle().fill(p.connected ? opsGreen : Color.orange).frame(width: 6, height: 6)
                            Text(p.name).font(.system(size: 10.5, weight: .medium))
                        }
                    }
                    Spacer()
                }
                ForEach(folders.prefix(3)) { f in
                    HStack(spacing: 8) {
                        Text(f.id)
                            .font(.system(size: 10, design: .monospaced))
                            .frame(width: 78, alignment: .leading)
                            .lineLimit(1)
                        OpsGauge(pct: f.pct, color: f.errors > 0 ? .red : (f.pct >= 99.9 ? opsGreen : Color.accentColor))
                        Text(String(format: "%.1f%%", f.pct))
                            .font(.system(size: 10, weight: .semibold).monospacedDigit())
                            .frame(width: 44, alignment: .trailing)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var attentionSection: some View {
        let rows = attentionRows
        VStack(alignment: .leading, spacing: 4) {
            sectionTitle("Cần chú ý", rows.isEmpty ? nil : "\(rows.count) mục")
            if rows.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(opsGreen)
                    Text("Không có gì cần xử lý trên cả hai máy").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                .padding(.vertical, 3)
            } else {
                ForEach(Array(rows.prefix(3).enumerated()), id: \.element.1.id) { _, row in
                    Button {
                        AppDelegate.shared?.openOps(host: row.0, section: row.1.section)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: row.1.icon)
                                .font(.system(size: 12))
                                .foregroundStyle(row.1.color)
                                .frame(width: 16)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(row.1.title).font(.system(size: 11, weight: .medium)).lineLimit(1)
                                if !row.1.detail.isEmpty {
                                    Text(row.1.detail).font(.system(size: 9.5)).foregroundStyle(.secondary).lineLimit(1)
                                }
                            }
                            Spacer(minLength: 4)
                            Text(row.0.rawValue)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.primary.opacity(0.08)))
                        }
                        .padding(.vertical, 2)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                if rows.count > 3 {
                    Text("và \(rows.count - 3) mục khác trong Ops Console")
                        .font(.system(size: 9.5))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    @ViewBuilder
    private var eventsSection: some View {
        let rows = ops.mergedEvents()
        VStack(alignment: .leading, spacing: 4) {
            sectionTitle("Sự kiện gần đây", rows.isEmpty ? nil : "\(rows.count) trong 24 giờ")
            if rows.isEmpty {
                Text("Chưa ghi nhận sự kiện nào.").font(.system(size: 10.5)).foregroundStyle(.secondary).padding(.vertical, 3)
            } else {
                ForEach(Array(rows.prefix(4))) { row in
                    let style = opsEventStyle(row.event.level)
                    Button {
                        AppDelegate.shared?.openOps(host: row.host, section: .events)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: style.0)
                                .font(.system(size: 11))
                                .foregroundStyle(style.1)
                                .frame(width: 16)
                            Text(row.event.title).font(.system(size: 11, weight: .medium)).lineLimit(1)
                            Spacer(minLength: 4)
                            Text(opsEventAgo(row.date)).font(.system(size: 9.5)).foregroundStyle(.secondary)
                            Text(row.host.rawValue)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.primary.opacity(0.08)))
                        }
                        .padding(.vertical, 2)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var portsSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            sectionTitle("Cổng dev trên Homelab", "\(min(4, activeDevPorts.count))/\(activeDevPorts.count) cổng")
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary.opacity(0.8))
                TextField("Tìm port, tiến trình, dự án...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4.5)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .textBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.12), lineWidth: 0.5))

            if activeDevPorts.isEmpty {
                Text(searchText.isEmpty ? "Không có tiến trình dev nào đang chiếm cổng." : "Không tìm thấy port nào khớp với từ khóa.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(activeDevPorts.prefix(4).enumerated()), id: \.element.id) { idx, p in
                        if idx > 0 { Divider().opacity(0.2) }
                        HStack(spacing: 8) {
                            Text(":\(p.displayPort)")
                                .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 58, alignment: .leading)
                            Text(p.process)
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                            Text(!p.project.isEmpty ? p.project : (!p.cwd.isEmpty ? p.cwd : ""))
                                .font(.system(size: 9.5, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer(minLength: 4)
                            Button(action: { state.killPort(port: p.port, pid: p.pid) }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12.5))
                                    .foregroundStyle(Color.red.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                            .help("Dừng tiến trình trên cổng :\(p.displayPort)")
                        }
                        .padding(.vertical, 3)
                    }
                }
            }
        }
    }
}
