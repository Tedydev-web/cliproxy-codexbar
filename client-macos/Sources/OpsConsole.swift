import SwiftUI
import AppKit

enum OpsHost: String, CaseIterable, Identifiable {
    case homelab = "Homelab"
    case node = "Node"
    var id: String { rawValue }
    var icon: String { self == .homelab ? "house.fill" : "cloud.fill" }
    var role: String { self == .homelab ? "Ubuntu · tại nhà" : "Azure JP · aarch64" }
}

enum OpsSection: String, CaseIterable, Identifiable {
    case overview = "Tổng quan"
    case services = "Dịch vụ"
    case egress = "Egress"
    case sync = "Đồng bộ"
    case logs = "Nhật ký"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .services: return "gearshape.2"
        case .egress: return "arrow.triangle.branch"
        case .sync: return "arrow.triangle.2.circlepath"
        case .logs: return "text.alignleft"
        }
    }
}

struct OpsUnit: Decodable, Identifiable {
    let unit: String
    let scope: String
    let kind: String
    let description: String?
    let state: String
    let sub: String?
    let result: String?
    let restarts: Int?
    let memory: Int?
    let since: String?
    let next: String?
    let last: String?
    var id: String { scope + ":" + unit }
    var isTimer: Bool { kind == "timer" }
}

struct OpsFailedUnit: Decodable, Identifiable {
    let unit: String
    let scope: String
    var id: String { scope + ":" + unit }
}

struct OpsEgressServer: Decodable, Identifiable {
    let name: String
    let status: String
    let backup: Bool
    let sessions: Int
    var id: String { name }
}

struct OpsEgress: Decodable {
    let ok: Bool
    let servers: [OpsEgressServer]?
    let active: String?
    let error: String?
}

struct OpsSyncFolder: Decodable, Identifiable {
    let id: String
    let state: String
    let needFiles: Int
    let needBytes: Int64
    let errors: Int
    let pct: Double
}

struct OpsSyncPeer: Decodable, Identifiable {
    let name: String
    let connected: Bool
    var id: String { name }
}

struct OpsSync: Decodable {
    let ok: Bool
    let folders: [OpsSyncFolder]?
    let peers: [OpsSyncPeer]?
    let error: String?
}

struct OpsMetrics: Decodable {
    let cpuPercent: Double
    let cpuCount: Int
    let loadAvg: [Double]
    let ramTotalGb: Double
    let ramUsedGb: Double
    let ramPercent: Double
    let diskTotalGb: Double
    let diskUsedGb: Double
    let diskPercent: Double
    let uptime: String
}

struct OpsStatus: Decodable {
    let host: String
    let time: Int
    let units: [OpsUnit]
    let failed: [OpsFailedUnit]
    let egress: OpsEgress?
    let sync: OpsSync?
    let metrics: OpsMetrics?
}

struct OpsLogRaw: Decodable {
    let ts: Int
    let prio: Int
    let msg: String
}

struct OpsLogs: Decodable {
    let entries: [OpsLogRaw]
    let cursor: String
}

struct OpsLogEntry: Identifiable {
    let id = UUID()
    let ts: Int
    let prio: Int
    let msg: String
}

struct OpsAttention: Identifiable {
    let id = UUID()
    let color: Color
    let icon: String
    let title: String
    let detail: String
    let section: OpsSection
}

final class OpsModel: ObservableObject {
    let state: QuotaState
    @Published var host: OpsHost = .homelab
    @Published var section: OpsSection = .overview
    @Published var statuses: [OpsHost: OpsStatus] = [:]
    @Published var errors: [OpsHost: String] = [:]
    @Published var updated: [OpsHost: Date] = [:]
    @Published var logUnit: OpsUnit?
    @Published var logs: [OpsLogEntry] = []
    @Published var logError: String?
    @Published var priority = ""
    @Published var query = ""
    @Published var banner: String?
    private var cursor = ""
    private var logGeneration = 0
    private var logBusy = false
    private var statusTimer: Timer?
    private var logTimer: Timer?
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()
    private let session: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 12
        return URLSession(configuration: c)
    }()

    init(state: QuotaState) {
        self.state = state
    }

    var status: OpsStatus? { statuses[host] }
    var statusError: String? { errors[host] }

    func baseUrl(_ h: OpsHost) -> String {
        h == .homelab ? state.hostUrl : state.baseUrl
    }

    func available(_ s: OpsSection) -> Bool {
        switch s {
        case .egress: return status?.egress != nil
        case .sync: return status?.sync != nil
        default: return true
        }
    }

    func start() {
        stop()
        refreshStatus()
        statusTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { [weak self] _ in self?.refreshStatus() }
        logTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.pollLogs() }
    }

    func stop() {
        statusTimer?.invalidate()
        statusTimer = nil
        logTimer?.invalidate()
        logTimer = nil
    }

    func switchHost(_ newHost: OpsHost) {
        guard newHost != host else { return }
        host = newHost
        logUnit = nil
        logs = []
        cursor = ""
        logGeneration += 1
        logBusy = false
        if !available(section) { section = .overview }
    }

    private func failureMessage(_ err: Error?, _ resp: URLResponse?) -> String? {
        if let err = err { return err.localizedDescription }
        if let http = resp as? HTTPURLResponse, http.statusCode != 200 { return "HTTP \(http.statusCode)" }
        return nil
    }

    func refreshStatus() {
        for h in OpsHost.allCases { fetchStatus(h) }
    }

    private func fetchStatus(_ h: OpsHost) {
        guard let url = URL(string: baseUrl(h) + "/v1/ops-status") else { return }
        session.dataTask(with: state.authedRequest(url)) { [weak self] data, resp, err in
            guard let self = self else { return }
            var decoded: OpsStatus?
            var message = self.failureMessage(err, resp)
            if message == nil, let data = data {
                do { decoded = try self.decoder.decode(OpsStatus.self, from: data) }
                catch { message = "Bridge chưa hỗ trợ Ops (cần cập nhật backend)" }
            }
            DispatchQueue.main.async {
                if let decoded = decoded {
                    self.statuses[h] = decoded
                    self.errors[h] = nil
                    self.updated[h] = Date()
                } else {
                    self.errors[h] = message ?? "Không có dữ liệu"
                }
            }
        }.resume()
    }

    func selectLog(_ unit: OpsUnit?) {
        logUnit = unit
        resetLogs()
    }

    func openLogs(_ unit: OpsUnit) {
        section = .logs
        selectLog(unit)
    }

    func resetLogs() {
        logGeneration += 1
        logs = []
        cursor = ""
        logError = nil
        logBusy = false
        pollLogs()
    }

    func pollLogs() {
        guard let unit = logUnit, !logBusy else { return }
        var comps = URLComponents(string: baseUrl(host) + "/v1/ops-logs")
        var items = [
            URLQueryItem(name: "unit", value: unit.unit),
            URLQueryItem(name: "scope", value: unit.scope),
            URLQueryItem(name: "lines", value: cursor.isEmpty ? "300" : "500")
        ]
        if !cursor.isEmpty { items.append(URLQueryItem(name: "cursor", value: cursor)) }
        if !priority.isEmpty { items.append(URLQueryItem(name: "priority", value: priority)) }
        if !query.isEmpty { items.append(URLQueryItem(name: "q", value: query)) }
        comps?.queryItems = items
        guard let url = comps?.url else { return }
        logBusy = true
        let gen = logGeneration
        session.dataTask(with: state.authedRequest(url)) { [weak self] data, resp, err in
            guard let self = self else { return }
            var decoded: OpsLogs?
            var message = self.failureMessage(err, resp)
            if message == nil, let data = data {
                do { decoded = try self.decoder.decode(OpsLogs.self, from: data) }
                catch { message = "Phản hồi log không hợp lệ" }
            }
            DispatchQueue.main.async {
                guard gen == self.logGeneration else { return }
                self.logBusy = false
                guard let decoded = decoded else {
                    self.logError = message
                    return
                }
                self.logError = nil
                if !decoded.cursor.isEmpty { self.cursor = decoded.cursor }
                if !decoded.entries.isEmpty {
                    self.logs.append(contentsOf: decoded.entries.map { OpsLogEntry(ts: $0.ts, prio: $0.prio, msg: $0.msg) })
                    if self.logs.count > 3000 { self.logs.removeFirst(self.logs.count - 3000) }
                }
            }
        }.resume()
    }

    func restart(_ unit: OpsUnit) {
        let alert = NSAlert()
        alert.messageText = "Restart \(unit.unit) trên \(host.rawValue)?"
        alert.informativeText = "Dịch vụ sẽ gián đoạn trong vài giây."
        alert.addButton(withTitle: "Restart")
        alert.addButton(withTitle: "Hủy")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        guard let url = URL(string: baseUrl(host) + "/v1/ops-restart") else { return }
        var req = state.authedRequest(url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 70
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["unit": unit.unit, "scope": unit.scope])
        session.dataTask(with: req) { [weak self] _, resp, _ in
            guard let self = self else { return }
            let ok = (resp as? HTTPURLResponse)?.statusCode == 200
            DispatchQueue.main.async {
                self.banner = ok ? "Đã restart \(unit.unit)" : "Restart thất bại: \(unit.unit) (ngoài quyền cho phép hoặc lỗi hệ thống)"
                self.refreshStatus()
                DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in self?.banner = nil }
            }
        }.resume()
    }

    func attention(_ h: OpsHost) -> [OpsAttention] {
        guard let st = statuses[h] else { return [] }
        var items: [OpsAttention] = []
        for f in st.failed {
            items.append(OpsAttention(color: .red, icon: "xmark.octagon.fill", title: "Unit failed: \(f.unit)", detail: "Phạm vi \(f.scope)", section: .services))
        }
        for u in st.units where (u.restarts ?? 0) >= 3 {
            items.append(OpsAttention(color: .orange, icon: "arrow.clockwise.circle.fill", title: "\(u.unit) đã restart \(u.restarts ?? 0) lần", detail: "Có thể đang crash loop hoặc bị kill", section: .services))
        }
        if let eg = st.egress {
            if !eg.ok {
                items.append(OpsAttention(color: .red, icon: "exclamationmark.triangle.fill", title: "Không đọc được HAProxy", detail: eg.error ?? "", section: .egress))
            } else {
                if let a = eg.active, a != "homelab" {
                    items.append(OpsAttention(color: .orange, icon: "arrow.triangle.branch", title: "Egress đang chạy tầng dự phòng: \(a)", detail: "Tầng chính (homelab) không sẵn sàng", section: .egress))
                } else if eg.active == nil {
                    items.append(OpsAttention(color: .red, icon: "exclamationmark.triangle.fill", title: "Không có tầng egress nào sống", detail: "Mọi tầng đều DOWN", section: .egress))
                }
                for s in eg.servers ?? [] where !s.status.hasPrefix("UP") {
                    items.append(OpsAttention(color: .yellow, icon: "circle.slash", title: "Tầng \(s.name) đang DOWN", detail: s.backup ? "Tầng dự phòng" : "Tầng chính", section: .egress))
                }
            }
        }
        if let sync = st.sync, sync.ok {
            for p in sync.peers ?? [] where !p.connected {
                items.append(OpsAttention(color: .orange, icon: "link.badge.plus", title: "Syncthing: \(p.name) chưa kết nối", detail: "Đồng bộ với máy này đang tạm dừng", section: .sync))
            }
            for f in sync.folders ?? [] {
                if f.errors > 0 {
                    items.append(OpsAttention(color: .red, icon: "xmark.octagon.fill", title: "Thư mục \(f.id) có \(f.errors) lỗi sync", detail: "", section: .sync))
                } else if f.pct < 99.9 {
                    items.append(OpsAttention(color: .blue, icon: "arrow.down.circle.fill", title: "Thư mục \(f.id) mới đạt \(String(format: "%.1f", f.pct))%", detail: "Còn \(f.needFiles) file", section: .sync))
                }
            }
        }
        if let m = st.metrics {
            if m.diskPercent >= 85 {
                items.append(OpsAttention(color: .orange, icon: "internaldrive.fill", title: "Ổ đĩa đã dùng \(Int(m.diskPercent))%", detail: String(format: "%.0f / %.0f GB", m.diskUsedGb, m.diskTotalGb), section: .overview))
            }
            if m.ramPercent >= 90 {
                items.append(OpsAttention(color: .orange, icon: "memorychip.fill", title: "RAM đã dùng \(Int(m.ramPercent))%", detail: "", section: .overview))
            }
        }
        return items
    }
}

private let opsLogFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "dd/MM HH:mm:ss"
    return f
}()

private let opsClockFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "HH:mm:ss"
    return f
}()

private func opsBytes(_ n: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: n, countStyle: .binary)
}

private func opsShortTime(_ raw: String?) -> String {
    guard let raw = raw, !raw.isEmpty else { return "—" }
    let parts = raw.split(separator: " ")
    return parts.count > 2 ? parts.dropFirst().joined(separator: " ") : raw
}

func opsGaugeColor(_ pct: Double) -> Color {
    if pct >= 90 { return .red }
    if pct >= 75 { return .orange }
    return Color(red: 0.20, green: 0.78, blue: 0.35)
}

let opsGreen = Color(red: 0.20, green: 0.78, blue: 0.35)
private let opsTerminalBg = Color(red: 0.07, green: 0.08, blue: 0.09)

private func opsUnitStatus(_ u: OpsUnit) -> (String, Color) {
    switch u.state {
    case "failed": return ("Failed", .red)
    case "active":
        if let r = u.result, !r.isEmpty, r != "success" { return ("Lỗi trước đó", .orange) }
        if u.isTimer { return ("Đang hẹn giờ", opsGreen) }
        return (u.sub == "exited" ? "Hoàn tất" : "Đang chạy", opsGreen)
    case "activating", "deactivating", "reloading": return ("Đang chuyển", .orange)
    case "inactive": return ("Dừng", .gray)
    default: return ("Không rõ", .gray)
    }
}

private func opsLogLevel(_ prio: Int) -> (String, Color) {
    if prio <= 3 { return ("ERR", Color(red: 1.0, green: 0.42, blue: 0.42)) }
    if prio == 4 { return ("WRN", Color(red: 1.0, green: 0.78, blue: 0.30)) }
    if prio == 7 { return ("DBG", Color.gray) }
    return ("INF", Color(red: 0.45, green: 0.78, blue: 1.0))
}

struct OpsPill: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.16)))
    }
}

struct OpsCard<Content: View>: View {
    let title: String?
    let trailing: String?
    let content: Content
    init(_ title: String? = nil, trailing: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.trailing = trailing
        self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title = title {
                HStack {
                    Text(title).font(.system(size: 13, weight: .semibold))
                    Spacer()
                    if let trailing = trailing {
                        Text(trailing).font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
            }
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.08), lineWidth: 1))
    }
}

struct OpsGauge: View {
    let pct: Double
    let color: Color
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.10))
                Capsule().fill(color).frame(width: max(4, geo.size.width * CGFloat(min(max(pct, 0), 100) / 100)))
            }
        }
        .frame(height: 6)
    }
}

struct OpsConsoleView: View {
    @ObservedObject var model: OpsModel
    @State private var follow = true

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            VStack(spacing: 0) {
                topBar
                Divider()
                if let banner = model.banner {
                    Text(banner)
                        .font(.system(size: 12))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.accentColor.opacity(0.14))
                }
                content
            }
        }
        .frame(minWidth: 900, minHeight: 600)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 8) {
                Image(systemName: "waveform.path.ecg.rectangle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.accentColor)
                Text("Orbiter Ops").font(.system(size: 15, weight: .bold))
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("MÁY CHỦ").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                ForEach(OpsHost.allCases) { hostCard($0) }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("MỤC").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).padding(.bottom, 4)
                ForEach(OpsSection.allCases.filter { model.available($0) }) { navItem($0) }
            }
            Spacer()
        }
        .padding(.top, 40)
        .padding([.horizontal, .bottom], 14)
        .frame(width: 230)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.6))
    }

    private func healthLabel(_ h: OpsHost) -> (String, Color) {
        if model.errors[h] != nil { return ("Mất kết nối", .red) }
        guard let st = model.statuses[h] else { return ("Đang tải", .gray) }
        if !st.failed.isEmpty { return ("\(st.failed.count) unit lỗi", .orange) }
        if model.attention(h).contains(where: { $0.color == .red }) { return ("Có sự cố", .red) }
        return ("Ổn định", opsGreen)
    }

    private func hostCard(_ h: OpsHost) -> some View {
        let selected = model.host == h
        let health = healthLabel(h)
        let m = model.statuses[h]?.metrics
        return Button { model.switchHost(h) } label: {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Image(systemName: h.icon).font(.system(size: 12)).foregroundStyle(selected ? Color.accentColor : .secondary)
                    Text(h.rawValue).font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Circle().fill(health.1).frame(width: 8, height: 8)
                }
                Text(h.role).font(.system(size: 11)).foregroundStyle(.secondary)
                if let m = m {
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("CPU \(Int(m.cpuPercent))%").font(.system(size: 10)).foregroundStyle(.secondary)
                            OpsGauge(pct: m.cpuPercent, color: opsGaugeColor(m.cpuPercent))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("RAM \(Int(m.ramPercent))%").font(.system(size: 10)).foregroundStyle(.secondary)
                            OpsGauge(pct: m.ramPercent, color: opsGaugeColor(m.ramPercent))
                        }
                    }
                }
                Text(health.0).font(.system(size: 11, weight: .medium)).foregroundStyle(health.1)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(selected ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.03)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? Color.accentColor.opacity(0.55) : Color.primary.opacity(0.08), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func navItem(_ s: OpsSection) -> some View {
        let selected = model.section == s
        let badge = s == .services ? (model.status?.failed.count ?? 0) : 0
        return Button { model.section = s } label: {
            HStack(spacing: 9) {
                Image(systemName: s.icon).frame(width: 18)
                Text(s.rawValue).font(.system(size: 13))
                Spacer()
                if badge > 0 {
                    Text("\(badge)").font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 1).background(Capsule().fill(Color.red))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .foregroundStyle(selected ? Color.accentColor : Color.primary)
            .background(RoundedRectangle(cornerRadius: 8).fill(selected ? Color.accentColor.opacity(0.14) : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(model.host.rawValue) · \(model.section.rawValue)").font(.system(size: 17, weight: .semibold))
                if let m = model.status?.metrics {
                    Text("Uptime \(m.uptime) · \(m.cpuCount) core · RAM \(String(format: "%.1f", m.ramTotalGb)) GB")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let err = model.statusError {
                OpsPill(text: err, color: .red)
            } else if let at = model.updated[model.host] {
                HStack(spacing: 5) {
                    Circle().fill(opsGreen).frame(width: 6, height: 6)
                    Text("Trực tiếp · " + opsClockFormatter.string(from: at)).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            Button { model.refreshStatus() } label: { Image(systemName: "arrow.clockwise") }
                .buttonStyle(.borderless)
                .help("Làm mới")
        }
        .padding(.horizontal, 16)
        .padding(.top, 34)
        .padding(.bottom, 12)
        .background(Color(nsColor: .windowBackgroundColor))
        .zIndex(1)
    }

    @ViewBuilder
    private var content: some View {
        switch model.section {
        case .overview: overviewView
        case .services: servicesView
        case .egress: egressView
        case .sync: syncView
        case .logs: logsView
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            if let err = model.statusError {
                Image(systemName: "wifi.exclamationmark").font(.system(size: 30)).foregroundStyle(.red)
                Text(err).font(.system(size: 13)).foregroundStyle(.secondary)
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func metricTile(_ title: String, _ icon: String, _ value: String, _ sub: String, _ pct: Double) -> some View {
        OpsCard {
            HStack {
                Image(systemName: icon).foregroundStyle(.secondary)
                Text(title).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                Spacer()
            }
            Text(value).font(.system(size: 26, weight: .semibold, design: .rounded))
            OpsGauge(pct: pct, color: opsGaugeColor(pct))
            Text(sub).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
        }
    }

    private var overviewView: some View {
        ScrollView {
            if let st = model.status {
                VStack(alignment: .leading, spacing: 14) {
                    if let m = st.metrics {
                        HStack(spacing: 12) {
                            metricTile("CPU", "cpu", "\(Int(m.cpuPercent))%", "\(m.cpuCount) core", m.cpuPercent)
                            metricTile("RAM", "memorychip", "\(Int(m.ramPercent))%", String(format: "%.1f / %.1f GB", m.ramUsedGb, m.ramTotalGb), m.ramPercent)
                            metricTile("Ổ đĩa", "internaldrive", "\(Int(m.diskPercent))%", String(format: "%.0f / %.0f GB", m.diskUsedGb, m.diskTotalGb), m.diskPercent)
                            let l1 = m.loadAvg.first ?? 0
                            metricTile("Load", "gauge.medium", String(format: "%.2f", l1), m.loadAvg.map { String(format: "%.2f", $0) }.joined(separator: "  "), l1 / Double(max(m.cpuCount, 1)) * 100)
                        }
                    }
                    summaryRow(st)
                    attentionCard
                }
                .padding(16)
            } else {
                emptyState
            }
        }
    }

    private func summaryRow(_ st: OpsStatus) -> some View {
        let services = st.units.filter { !$0.isTimer }
        let running = services.filter { $0.state == "active" }.count
        let timers = st.units.filter { $0.isTimer }
        let timersOk = timers.filter { $0.state == "active" }.count
        return HStack(spacing: 12) {
            summaryItem("Dịch vụ chạy", "\(running)/\(services.count)", running == services.count ? opsGreen : .orange)
            summaryItem("Timer hoạt động", "\(timersOk)/\(timers.count)", timersOk == timers.count ? opsGreen : .orange)
            summaryItem("Unit failed", "\(st.failed.count)", st.failed.isEmpty ? opsGreen : .red)
            summaryItem("Tổng restart", "\(st.units.reduce(0) { $0 + ($1.restarts ?? 0) })", .secondary)
        }
    }

    private func summaryItem(_ title: String, _ value: String, _ color: Color) -> some View {
        OpsCard {
            Text(title).font(.system(size: 11)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 20, weight: .semibold, design: .rounded)).foregroundStyle(color)
        }
    }

    private var attentionCard: some View {
        let items = model.attention(model.host)
        return OpsCard("Cần chú ý", trailing: items.isEmpty ? nil : "\(items.count) mục") {
            if items.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(opsGreen)
                    Text("Không có gì cần xử lý. Mọi thành phần đang theo dõi đều bình thường.").font(.system(size: 13))
                }
            } else {
                ForEach(items) { item in
                    Button { model.section = item.section } label: {
                        HStack(spacing: 10) {
                            Image(systemName: item.icon).foregroundStyle(item.color).frame(width: 20)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.title).font(.system(size: 13, weight: .medium))
                                if !item.detail.isEmpty {
                                    Text(item.detail).font(.system(size: 11)).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 10)).foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 3)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var servicesView: some View {
        ScrollView {
            if let st = model.status {
                VStack(alignment: .leading, spacing: 14) {
                    unitTable("Dịch vụ", st.units.filter { !$0.isTimer })
                    unitTable("Timer", st.units.filter { $0.isTimer })
                }
                .padding(16)
            } else {
                emptyState
            }
        }
    }

    private func unitTable(_ title: String, _ units: [OpsUnit]) -> some View {
        OpsCard(title, trailing: "\(units.count)") {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Text("TRẠNG THÁI").frame(width: 104, alignment: .leading)
                    Text("UNIT").frame(maxWidth: .infinity, alignment: .leading)
                    Text(title == "Timer" ? "LẦN TỚI" : "BỘ NHỚ").frame(width: 150, alignment: .trailing)
                    Text("RESTART").frame(width: 62, alignment: .trailing)
                    Text("").frame(width: 62)
                }
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.vertical, 6)
                Divider()
                ForEach(Array(units.enumerated()), id: \.element.id) { idx, u in
                    unitRow(u).background(idx % 2 == 1 ? Color.primary.opacity(0.03) : Color.clear)
                }
            }
        }
    }

    private func unitRow(_ u: OpsUnit) -> some View {
        let s = opsUnitStatus(u)
        return HStack(spacing: 10) {
            OpsPill(text: s.0, color: s.1).frame(width: 104, alignment: .leading)
            VStack(alignment: .leading, spacing: 1) {
                Text(u.unit).font(.system(size: 12, design: .monospaced)).lineLimit(1)
                Text(unitDetail(u)).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(u.isTimer ? opsShortTime(u.next) : ((u.memory ?? 0) > 0 ? opsBytes(Int64(u.memory ?? 0)) : "—"))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 150, alignment: .trailing)
            Text((u.restarts ?? 0) > 0 ? "\(u.restarts ?? 0)" : "—")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle((u.restarts ?? 0) >= 3 ? Color.orange : Color.secondary)
                .frame(width: 62, alignment: .trailing)
            HStack(spacing: 10) {
                Button { model.openLogs(u) } label: { Image(systemName: "text.alignleft") }
                    .buttonStyle(.borderless)
                    .help("Xem log")
                if u.isTimer {
                    Image(systemName: "arrow.clockwise").foregroundStyle(.clear)
                } else {
                    Button { model.restart(u) } label: { Image(systemName: "arrow.clockwise") }
                        .buttonStyle(.borderless)
                        .help("Restart")
                }
            }
            .frame(width: 62, alignment: .trailing)
        }
        .padding(.vertical, 7)
    }

    private func unitDetail(_ u: OpsUnit) -> String {
        if u.state == "unknown" { return "không đọc được trạng thái" }
        if u.isTimer { return "lần cuối: \(opsShortTime(u.last))" }
        var text = "\(u.scope) · từ \(opsShortTime(u.since))"
        if let r = u.result, !r.isEmpty, r != "success" { text += " · \(r)" }
        return text
    }

    private var egressView: some View {
        ScrollView {
            if let eg = model.status?.egress {
                VStack(alignment: .leading, spacing: 14) {
                    if eg.ok, let servers = eg.servers {
                        OpsCard("Đường ra internet của Claude (HAProxy)") {
                            HStack(alignment: .top, spacing: 8) {
                                ForEach(Array(servers.enumerated()), id: \.element.id) { idx, s in
                                    egressTier(s, idx, active: s.name == eg.active)
                                    if idx < servers.count - 1 {
                                        Image(systemName: "chevron.right").foregroundStyle(.tertiary).padding(.top, 38)
                                    }
                                }
                            }
                            Text("HAProxy luôn dùng tầng sống đầu tiên theo thứ tự trái sang phải. Tầng chính phục hồi thì tự quay về.")
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                    } else {
                        OpsCard("Egress") {
                            Label("Không đọc được HAProxy: \(eg.error ?? "lỗi không rõ")", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
                        }
                    }
                }
                .padding(16)
            } else {
                emptyState
            }
        }
    }

    private func egressTier(_ s: OpsEgressServer, _ idx: Int, active: Bool) -> some View {
        let up = s.status.hasPrefix("UP")
        let color: Color = up ? opsGreen : .red
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(idx == 0 ? "TẦNG CHÍNH" : "DỰ PHÒNG \(idx)").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
                if active { OpsPill(text: "ĐANG DÙNG", color: opsGreen) }
            }
            Text(s.name).font(.system(size: 17, weight: .semibold))
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(up ? "UP" : "DOWN").font(.system(size: 12, weight: .semibold)).foregroundStyle(color)
            }
            Text("\(s.sessions) phiên đang mở").font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(active ? opsGreen.opacity(0.10) : Color.primary.opacity(0.03)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(active ? opsGreen.opacity(0.7) : Color.primary.opacity(0.1), lineWidth: active ? 1.5 : 1))
    }

    private var syncView: some View {
        ScrollView {
            if let sync = model.status?.sync {
                VStack(alignment: .leading, spacing: 14) {
                    if sync.ok {
                        OpsCard("Thiết bị") {
                            HStack(spacing: 10) {
                                ForEach(sync.peers ?? []) { p in
                                    HStack(spacing: 6) {
                                        Circle().fill(p.connected ? opsGreen : Color.orange).frame(width: 8, height: 8)
                                        Text(p.name).font(.system(size: 13, weight: .medium))
                                        Text(p.connected ? "đã kết nối" : "ngoại tuyến").font(.system(size: 11)).foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(Color.primary.opacity(0.05)))
                                }
                            }
                        }
                        OpsCard("Thư mục", trailing: "\((sync.folders ?? []).count)") {
                            ForEach((sync.folders ?? []).sorted { $0.pct < $1.pct }) { f in syncRow(f) }
                        }
                    } else {
                        OpsCard("Syncthing") {
                            Label("Không đọc được Syncthing: \(sync.error ?? "lỗi không rõ")", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
                        }
                    }
                }
                .padding(16)
            } else {
                emptyState
            }
        }
    }

    private func syncRow(_ f: OpsSyncFolder) -> some View {
        let color: Color = f.errors > 0 ? .red : (f.pct >= 99.9 ? opsGreen : .blue)
        return HStack(spacing: 10) {
            Text(f.id).font(.system(size: 12, design: .monospaced)).frame(width: 230, alignment: .leading).lineLimit(1)
            OpsGauge(pct: f.pct, color: color)
            Text(String(format: "%.1f%%", f.pct)).font(.system(size: 11, design: .monospaced)).frame(width: 52, alignment: .trailing)
            Text(f.errors > 0 ? "\(f.errors) lỗi" : (f.needFiles > 0 ? "\(f.needFiles) file · \(opsBytes(f.needBytes))" : "Đã đồng bộ"))
                .font(.system(size: 11))
                .foregroundStyle(f.errors > 0 ? Color.red : Color.secondary)
                .frame(width: 150, alignment: .trailing)
        }
        .padding(.vertical, 3)
    }

    private var logsView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Picker("", selection: Binding(
                    get: { model.logUnit?.id ?? "" },
                    set: { id in model.selectLog(model.status?.units.first { $0.id == id }) }
                )) {
                    Text("Chọn unit để xem log").tag("")
                    ForEach(model.status?.units ?? []) { Text($0.unit).tag($0.id) }
                }
                .labelsHidden()
                .frame(width: 260)
                Picker("", selection: Binding(
                    get: { model.priority },
                    set: { model.priority = $0; model.resetLogs() }
                )) {
                    Text("Tất cả").tag("")
                    Text("Cảnh báo+").tag("4")
                    Text("Lỗi").tag("3")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 230)
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Tìm trong log", text: $model.query)
                        .textFieldStyle(.plain)
                        .onSubmit { model.resetLogs() }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.06)))
                Toggle("Tự cuộn", isOn: $follow).toggleStyle(.switch).controlSize(.small)
                Button { copyLogs() } label: { Image(systemName: "doc.on.doc") }
                    .buttonStyle(.borderless)
                    .help("Sao chép log")
                Button { model.logs = [] } label: { Image(systemName: "trash") }
                    .buttonStyle(.borderless)
                    .help("Xóa màn hình")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(nsColor: .windowBackgroundColor))
            .zIndex(1)
            Divider()
            Group {
                if model.logUnit == nil {
                    Text("Chọn một unit ở trên, hoặc bấm biểu tượng log ở trang Dịch vụ.")
                        .font(.system(size: 12)).foregroundStyle(.gray)
                } else {
                    logList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(opsTerminalBg, ignoresSafeAreaEdges: [])
            .clipped()
            logStatusBar
        }
    }

    private var logList: some View {
        GeometryReader { geo in
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(model.logs) { e in
                        let lv = opsLogLevel(e.prio)
                        HStack(alignment: .top, spacing: 8) {
                            Text(opsLogFormatter.string(from: Date(timeIntervalSince1970: Double(e.ts) / 1000)))
                                .foregroundStyle(Color.gray)
                            Text(lv.0).fontWeight(.bold).foregroundStyle(lv.1)
                            Text(e.msg)
                                .foregroundStyle(e.prio <= 4 ? lv.1 : Color.white.opacity(0.88))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .font(.system(size: 11, design: .monospaced))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 1.5)
                        .background(e.prio <= 3 ? Color.red.opacity(0.10) : Color.clear)
                        .id(e.id)
                    }
                }
                .padding(.vertical, 8)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .onChange(of: model.logs.count) { _ in
                if follow, let last = model.logs.last { proxy.scrollTo(last.id, anchor: .bottom) }
            }
        }
        }
    }

    private var logStatusBar: some View {
        HStack(spacing: 8) {
            if let err = model.logError {
                Circle().fill(Color.red).frame(width: 7, height: 7)
                Text(err).foregroundStyle(.red)
            } else if let u = model.logUnit {
                Circle().fill(opsGreen).frame(width: 7, height: 7)
                Text("Đang theo dõi \(u.unit)")
                Text("·")
                Text("\(model.logs.count) dòng")
            } else {
                Text("Chưa chọn unit")
            }
            Spacer()
            Text("Secret đã được che ở phía máy chủ").foregroundStyle(.secondary)
        }
        .font(.system(size: 11))
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func copyLogs() {
        let text = model.logs.map { opsLogFormatter.string(from: Date(timeIntervalSince1970: Double($0.ts) / 1000)) + " " + $0.msg }.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
