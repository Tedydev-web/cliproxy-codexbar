import AppKit
import SwiftUI

// MARK: - Menu Hosting View
final class MenuHostingView<Content: View>: NSHostingView<Content> {
}

// MARK: - CodexBar Reset Time & Timestamp Formatter
func formatResetWithEst(raw: String) -> String {
    var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleaned.isEmpty, cleaned != "-" else { return "" }
    
    // Clean redundant prefixes if already present
    cleaned = cleaned.replacingOccurrences(of: "Đặt lại sau ", with: "")
    cleaned = cleaned.replacingOccurrences(of: "Đặt lại ", with: "")
    cleaned = cleaned.replacingOccurrences(of: "Đặt lại: ", with: "")
    cleaned = cleaned.replacingOccurrences(of: "Resets in ", with: "")
    cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleaned.isEmpty, cleaned != "-" else { return "" }
    
    var totalSeconds: Double = 0
    let parts = cleaned.components(separatedBy: " ")
    for part in parts {
        let p = part.trimmingCharacters(in: .whitespacesAndNewlines)
        if p.hasSuffix("d"), let num = Double(p.dropLast()) {
            totalSeconds += num * 86400
        } else if p.hasSuffix("h"), let num = Double(p.dropLast()) {
            totalSeconds += num * 3600
        } else if p.hasSuffix("m"), let num = Double(p.dropLast()) {
            totalSeconds += num * 60
        } else if p.hasSuffix("s"), let num = Double(p.dropLast()) {
            totalSeconds += num
        }
    }
    
    if totalSeconds <= 0 {
        return "Hồi: " + cleaned
    }
    
    let target = Date().addingTimeInterval(totalSeconds)
    let calendar = Calendar.current
    let timeFormatter = DateFormatter()
    timeFormatter.dateFormat = "HH:mm"
    let timeStr = timeFormatter.string(from: target)
    
    if totalSeconds < 86400 && calendar.isDateInToday(target) {
        return "Hồi sau " + cleaned + " · " + timeStr
    } else if calendar.isDateInTomorrow(target) {
        return "Hồi sau " + cleaned + " · Mai " + timeStr
    } else {
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "dd/MM HH:mm"
        return "Hồi sau " + cleaned + " · " + dayFormatter.string(from: target)
    }
}


// MARK: - Exact Progress Bar from CodexBar (UsageProgressBar.swift)
struct UsageProgressBar: View {
    let percent: Double
    let tint: Color
    var warningMarkerPercents: [Double] = [33.33, 66.66]
    var accentPaceMarker: Double? = nil
    var height: CGFloat = 6
    
    var body: some View {
        Canvas { context, size in
            let cornerRadius = size.height / 2
            let cornerSize = CGSize(width: cornerRadius, height: cornerRadius)
            let rect = CGRect(origin: .zero, size: size)
            
            context.clip(to: Path(rect))
            
            // 1. Background Track
            let trackPath = Path { p in p.addRoundedRect(in: rect, cornerSize: cornerSize) }
            context.fill(trackPath, with: .color(Color(white: 0.28, opacity: 0.6)))
            
            // 2. Main Fill
            let clamped = max(0.0, min(100.0, self.percent))
            let fillWidth = size.width * CGFloat(clamped / 100.0)
            if fillWidth > 0 {
                let fillRect = CGRect(x: 0, y: 0, width: max(fillWidth, cornerRadius * 2), height: size.height)
                let fillPath = Path { p in p.addRoundedRect(in: fillRect, cornerSize: cornerSize) }
                context.fill(fillPath, with: .color(self.tint))
            }
            
            // 3. Hairline Punch Dividers (2px subtle tick cuts)
            for markerPct in self.warningMarkerPercents {
                let mx = (size.width * CGFloat(markerPct / 100.0)).rounded()
                let punchRect = CGRect(x: mx - 1.0, y: 0, width: 2.0, height: size.height)
                context.fill(Path(punchRect), with: .color(Color(white: 0.12, opacity: 0.95)))
            }
            
            // 4. Pace indicator tick (green hairline marker)
            if let pacePct = self.accentPaceMarker {
                let px = (size.width * CGFloat(pacePct / 100.0)).rounded()
                let paceRect = CGRect(x: px - 1.0, y: 0, width: 2.5, height: size.height)
                context.fill(Path(paceRect), with: .color(Color(red: 52/255, green: 199/255, blue: 89/255)))
            }
        }
        .frame(height: self.height)
    }
}

// MARK: - Metric Row Component (MenuCardMetricRow.swift)
struct MetricRow: View {
    let title: String
    let percent: Double
    let resetText: String?
    let tint: Color
    var paceText: String? = nil
    var paceMarker: Double? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(self.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                Spacer()
                if let resetText = self.resetText {
                    Text(resetText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            UsageProgressBar(percent: self.percent, tint: self.tint, accentPaceMarker: self.paceMarker)
            if let pace = self.paceText {
                Text(pace)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Minimal Sleek Account Row (Exact CodexBar Native Row Style)
struct BackupModelItem: Identifiable {
    let key: String
    let label: String
    let usable: Bool
    let selected: Bool
    var id: String { key }
}

struct BackupInfo {
    let online: Bool
    let latencyMs: Int
    let enabled: Bool
    let models: [BackupModelItem]

    var selected: BackupModelItem? { models.first { $0.selected } }
    var anyUsable: Bool { models.contains { $0.usable } }

    var statusText: String {
        if !online { return "Ngoại tuyến" }
        let sec = String(format: "%.1fs", Double(latencyMs) / 1000.0)
        return anyUsable ? "Có thể dùng · \(sec)" : "Model không khả dụng"
    }
}

struct BackupSectionView: View {
    let info: BackupInfo
    let onToggle: () -> Void
    let onSelect: (String) -> Void
    private let brand = Color(red: 218/255, green: 119/255, blue: 86/255)

    private var statusColor: Color {
        info.online && info.anyUsable ? Color(nsColor: .systemGreen) : Color(nsColor: .systemRed)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("Dự phòng")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 4) {
                    Circle().fill(statusColor).frame(width: 6, height: 6)
                    Text(info.statusText)
                        .font(.footnote)
                        .foregroundStyle(statusColor)
                }
            }

            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Aperture")
                            .font(.system(size: 11.5, weight: info.enabled ? .semibold : .regular))
                            .foregroundStyle(Color.primary)
                        Text("Tailscale")
                            .font(.system(size: 8.5, weight: .semibold))
                            .foregroundStyle(Color.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.white.opacity(0.10)))
                            .fixedSize()
                    }
                    Text(info.enabled
                        ? "Hết quota Claude và capi → tự chuyển sang \(info.selected?.label ?? "model dự phòng")"
                        : "Đang tắt · chỉ dùng khi gọi đích danh aperture/…")
                        .font(.footnote)
                        .foregroundStyle(info.enabled ? brand : Color.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                Toggle("", isOn: Binding(get: { info.enabled }, set: { _ in onToggle() }))
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .tint(brand)
                    .scaleEffect(0.65)
                    .frame(width: 30, height: 18)
                    .disabled(!info.enabled && !(info.online && info.anyUsable))
                    .help(info.enabled ? "Đang bật · tắt để không tự chuyển" : "Bật để tự chuyển sang Aperture khi hết quota")
            }

            HStack(alignment: .top, spacing: 14) {
                ForEach(info.models) { model in
                    Button(action: { onSelect(model.key) }) {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: model.selected ? "largecircle.fill.circle" : "circle")
                                .font(.system(size: 11))
                                .foregroundStyle(model.selected ? brand : Color.secondary.opacity(0.7))
                                .padding(.top, 1)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(model.label)
                                    .font(.footnote.weight(model.selected ? .semibold : .regular))
                                    .foregroundStyle(model.selected ? Color.primary : Color.secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                                Text(model.usable ? "Sẵn sàng" : "Không khả dụng")
                                    .font(.caption2)
                                    .foregroundStyle(model.usable ? Color(nsColor: .systemGreen) : Color(nsColor: .systemRed))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(model.selected ? "Model dự phòng đang chọn" : "Chọn làm model dự phòng")
                    .accessibilityLabel("\(model.label), \(model.usable ? "sẵn sàng" : "không khả dụng"), \(model.selected ? "đang chọn" : "chưa chọn")")
                }
            }
        }
        .padding(.vertical, 2)
    }
}

struct ConsoleKeyItem: Identifiable {
    let id: String
    let org: String
    let state: String
    let enabled: Bool

    var isUsable: Bool { enabled && (state == "ok" || state == "rate_limited" || state == "unknown" || state == "error") }

    var stateLabel: String {
        switch state {
        case "ok": return "Còn credit"
        case "no_credit": return "Hết credit"
        case "invalid": return "Key không hợp lệ"
        case "rate_limited": return "Đang bị giới hạn"
        case "disabled": return "Đang tắt"
        case "unknown": return "Đang kiểm tra"
        default: return "Chưa kiểm tra được"
        }
    }

    var detailText: String {
        switch state {
        case "no_credit": return "Cần nạp thêm tại Console"
        case "ok": return "Không xem được số dư"
        case "rate_limited": return "Đang bị giới hạn tốc độ"
        case "invalid": return "Key bị từ chối (401/403)"
        case "disabled": return "Đang tắt"
        case "unknown": return "Đang kiểm tra..."
        default: return "Chưa kiểm tra được"
        }
    }

    var displayName: String { org.isEmpty ? id : org }
}

struct RouteRow: Identifiable {
    let id: String
    let subDetails: String
    var cells: [QuotaCell] = []
    let isAvailable: Bool
    var isProbeError: Bool = false
    var isDisabled: Bool = false
    var isPaused: Bool = false
    var isConsole: Bool = false
    var unavailableLabel: String = "Hết hạn"
    var statusText: String? = nil
    var title: String? = nil
    var badge: String? = nil
}

struct CompactAccountRowView: View {
    let email: String
    let index: Int
    let totalCount: Int
    let subDetails: String
    var cells: [QuotaCell] = []
    let isAvailable: Bool
    let isCurrent: Bool
    var isProbeError: Bool = false
    var isDisabled: Bool = false
    var onMoveUp: (() -> Void)? = nil
    var onMoveDown: (() -> Void)? = nil
    let onSwitch: () -> Void
    var onToggleEnabled: (() -> Void)? = nil
    var unavailableLabel: String = "Hết hạn"
    var statusText: String? = nil
    var title: String? = nil
    var badge: String? = nil

    @State private var isHovered: Bool = false

    static func shortIdentity(_ value: String) -> String {
        guard let at = value.firstIndex(of: "@") else { return value }
        return String(value[..<at])
    }

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            rowContent
                .help(self.email)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(self.title ?? Self.shortIdentity(self.email)) \(self.badge ?? ""), \(self.statusText ?? (self.isAvailable ? "" : self.unavailableLabel)), \(self.cells.isEmpty ? self.subDetails : self.cells.map { "\($0.label) \($0.value), \($0.recovery)" }.joined(separator: "; "))")
            if let onToggleEnabled = onToggleEnabled {
                Toggle("", isOn: Binding(get: { !self.isDisabled }, set: { _ in onToggleEnabled() }))
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .tint(Color(red: 218/255, green: 119/255, blue: 86/255))
                    .scaleEffect(0.65)
                    .frame(width: 30, height: 18)
                    .help(self.isDisabled ? "Đang tắt · bật để dùng lại" : "Đang bật · tắt để tạm ngưng")
                    .accessibilityLabel(self.isDisabled ? "Bật \(self.title ?? self.email)" : "Tắt \(self.title ?? self.email)")
            }
        }
        .opacity(self.isDisabled ? 0.55 : 1)
        .contextMenu {
            if let onToggleEnabled = onToggleEnabled {
                Button(self.isDisabled ? "Bật account" : "Tắt account", action: onToggleEnabled)
            }
            if !self.isDisabled {
                Button("Đặt làm #1", action: onSwitch)
            }
            Button("Copy email") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(self.email, forType: .string)
            }
        }
    }

    private var rowContent: some View {
        HStack(alignment: .center, spacing: 6) {
            // 1. Subtle Inline Order & Priority Arrows
            if let onMoveUp = onMoveUp, let onMoveDown = onMoveDown {
                HStack(spacing: 1) {
                    Text("#\(index + 1)")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(self.isCurrent ? Color.accentColor : Color.secondary.opacity(0.6))
                        .frame(width: 18, alignment: .leading)
                    
                    VStack(spacing: 0) {
                        Button(action: onMoveUp) {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 6.5, weight: .bold))
                                .foregroundStyle(index > 0 ? Color.secondary : Color.clear)
                                .frame(width: 12, height: 9)
                        }
                        .buttonStyle(.plain)
                        .disabled(index == 0)
                        
                        Button(action: onMoveDown) {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 6.5, weight: .bold))
                                .foregroundStyle(index < totalCount - 1 ? Color.secondary : Color.clear)
                                .frame(width: 12, height: 9)
                        }
                        .buttonStyle(.plain)
                        .disabled(index >= totalCount - 1)
                    }
                }
            }
            
            // 2. Native CodexBar Style Account Row
            Button(action: onSwitch) {
                VStack(alignment: .leading, spacing: 2) {
                    // Line 1: Identity & Headroom / Status (CodexBar MenuCardCompactAccountRow layout)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(self.title ?? Self.shortIdentity(self.email))
                            .font(.system(size: 11.5, weight: self.isCurrent ? .semibold : .regular))
                            .foregroundStyle(self.isCurrent ? Color.primary : (self.isAvailable ? Color.primary.opacity(0.88) : Color.secondary))
                            .lineLimit(1)
                            .truncationMode(.middle)

                        if let badge = self.badge, !badge.isEmpty {
                            Text(badge)
                                .font(.system(size: 8.5, weight: .semibold))
                                .foregroundStyle(Color.secondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(Color.white.opacity(0.10)))
                                .lineLimit(1)
                                .fixedSize()
                        }
                        
                        Spacer(minLength: 8)
                        
                        if self.isProbeError {
                            HStack(spacing: 2) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 8))
                                Text("429")
                                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            }
                            .foregroundStyle(Color(nsColor: .systemOrange))
                        } else if !self.isAvailable {
                            Text(self.unavailableLabel)
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundStyle(Color(nsColor: .systemRed))
                        } else if let statusText = self.statusText {
                            Text(statusText)
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundStyle(self.isCurrent ? Color.accentColor : Color(nsColor: .systemGreen))
                        }
                    }
                    
                    if !self.cells.isEmpty {
                        QuotaCellsView(cells: self.cells)
                            .padding(.top, 3)
                    } else {
                        Text(self.subDetails)
                            .font(.footnote)
                            .foregroundStyle(self.isProbeError ? Color(nsColor: .systemOrange) : Color.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(self.isHovered ? Color.white.opacity(0.06) : (self.isCurrent ? Color.white.opacity(0.03) : Color.clear))
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { h in self.isHovered = h }
        }
        .padding(.vertical, 1)
    }
}

// MARK: - Navigation Action Row
struct MenuActionRow: View {
    let iconName: String?
    let title: String
    let value: String?
    let hasChevron: Bool
    var action: (() -> Void)? = nil
    
    var body: some View {
        Button(action: { self.action?() }) {
            HStack(spacing: 8) {
                if let ic = self.iconName {
                    Image(systemName: ic)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .frame(width: 16, alignment: .center)
                }
                Text(self.title)
                    .font(.body)
                    .foregroundStyle(.primary)
                Spacer()
                if let val = self.value {
                    Text(val)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                if self.hasChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// Account Data Model
struct ScopedQuota: Identifiable {
    var id: String { model }
    let model: String
    let used: Int
    let resetText: String
}

struct PoolAccountItem: Identifiable {
    var id: String { email }
    let email: String
    let name: String
    let plan: String
    let isAvailable: Bool
    var isProbeError: Bool = false
    var errorHint: String = ""
    let remaining5h: Int
    let used5h: Int
    let reset5h: String
    let remainingWeekly: Int
    let usedWeekly: Int
    let resetWeekly: String
    var isDisabled: Bool = false
    var isPaused: Bool = false
    var scoped: [ScopedQuota] = []

    var scopedSummary: String {
        scoped.isEmpty ? "" : " · " + scoped.map { "\($0.model): \($0.used)%" }.joined(separator: " · ")
    }

    var statusLine: String {
        isPaused ? "Đã cách ly · \(errorHint.isEmpty ? "Cần đăng nhập lại" : errorHint)" : ""
    }

    func quotaCells(isUsedMode: Bool) -> [QuotaCell] {
        guard !isPaused else { return [] }
        return [
            QuotaCell.make(label: "5h", used: used5h, remaining: remaining5h, reset: reset5h, emptyReset: "Chưa bắt đầu", isUsedMode: isUsedMode),
            QuotaCell.make(label: "Tuần", used: usedWeekly, remaining: remainingWeekly, reset: resetWeekly, emptyReset: "Chưa có mốc", isUsedMode: isUsedMode)
        ]
    }
}

struct QuotaCell: Identifiable {
    let label: String
    let value: String
    let percent: Double
    let level: Int
    let recovery: String
    var id: String { label }

    static func make(label: String, used: Int, remaining: Int, reset: String, emptyReset: String, isUsedMode: Bool) -> QuotaCell {
        let est = formatResetWithEst(raw: reset).replacingOccurrences(of: "Hồi sau ", with: "Hồi ")
        return QuotaCell(
            label: label,
            value: isUsedMode ? "\(used)% dùng" : "\(remaining)% còn",
            percent: Double(isUsedMode ? used : remaining),
            level: used >= 100 ? 2 : (used >= 80 ? 1 : 0),
            recovery: est.isEmpty ? emptyReset : est
        )
    }
}

struct QuotaCellsView: View {
    let cells: [QuotaCell]
    private let brand = Color(red: 218/255, green: 119/255, blue: 86/255)

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ForEach(cells) { cell in
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(cell.label)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text(cell.value)
                            .font(.footnote.weight(.medium).monospacedDigit())
                            .foregroundStyle(cell.level == 2 ? Color(nsColor: .systemRed) : Color.primary)
                    }
                    UsageProgressBar(
                        percent: cell.percent,
                        tint: cell.level == 2 ? Color(nsColor: .systemRed) : brand,
                        warningMarkerPercents: [],
                        height: 4
                    )
                    Text(cell.recovery)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// Gateway Command Data Model
struct GatewayCommandItem: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let command: String
}

// MARK: - System Telemetry Data Models
struct HostMetricInfo {
    var cpuPercent: Double = 0.0
    var cpuCount: Int = 0
    var loadAvg: [Double] = [0.0, 0.0, 0.0]
    var ramTotalGb: Double = 0.0
    var ramUsedGb: Double = 0.0
    var ramPercent: Double = 0.0
    var diskTotalGb: Double = 0.0
    var diskUsedGb: Double = 0.0
    var diskFreeGb: Double = 0.0
    var diskPercent: Double = 0.0
    var diskFreePercent: Double = 0.0
    var uptime: String = "-"
}

struct PortInfo: Identifiable {
    var id: String { "\(host):\(port)-\(pid ?? 0)" }
    let port: Int
    let host: String
    let pid: Int?
    let process: String
    let command: String
    let cwd: String
    let user: String
    let isDocker: Bool
    let project: String
    let isInternal: Bool
    
    // Explicit raw integer string to prevent locale thousands separator (avoid 30.071)
    var displayPort: String {
        return String(format: "%d", port)
    }
}

struct ServiceInfo: Identifiable {
    var id: String { name }
    let name: String
    let unit: String
    let active: Bool
    let version: String
    let port: Int?
    let canRestart: Bool
    let canUpdate: Bool
}

struct DockerContainerInfo: Identifiable {
    let id: String
    let name: String
    let status: String
    let image: String
    let ports: String
}

struct TunnelInfo: Identifiable {
    let id: String
    let type: String
    let target: String
    let url: String
    let isActive: Bool
    let isQuick: Bool
    let port: Int?
    let startedAt: String?
}

// MARK: - Claude Full Card View
struct ClaudeFullCardView: View {
    @ObservedObject var state: QuotaState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            // 1. Header (Active Account) - Exact CodexBar 1:1 Layout & Subtitle
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    HStack(alignment: .center, spacing: 6) {
                        if let nsImg = loadTemplateIcon(name: "claude") {
                            Image(nsImage: nsImg)
                                .renderingMode(.template)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 14, height: 14)
                                .foregroundStyle(Color(red: 218/255, green: 119/255, blue: 86/255))
                        }
                        Text("Claude")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    Spacer()
                    Text(self.state.claudeEmail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                HStack(alignment: .firstTextBaseline) {
                    if !self.state.switchingMessage.isEmpty {
                        Text(self.state.switchingMessage)
                            .font(.footnote)
                            .foregroundColor(Color.blue)
                    } else {
                        Text(self.state.lastQuotaFetchAgoText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("Gói \(self.state.claudePlan)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            Divider()
            
            // 2. Active Account Quota Metrics
            VStack(alignment: .leading, spacing: 11) {
                let isUsedMode = self.state.quotaDisplayMode == "used"
                let c5hVal = isUsedMode ? self.state.claude5h : max(0, 100 - self.state.claude5h)
                let c5hTitle = isUsedMode ? "Phiên 5h: \(c5hVal)% đã dùng" : "Phiên 5h: \(c5hVal)% còn lại"
                let c5hPace = isUsedMode ? "Còn \(self.state.claudePaceReserve)% trong phiên này" : "Đã dùng \(self.state.claude5h)%"
                
                MetricRow(
                    title: c5hTitle,
                    percent: Double(c5hVal),
                    resetText: formatResetWithEst(raw: self.state.claude5hReset),
                    tint: Color(red: 218/255, green: 119/255, blue: 86/255),
                    paceText: c5hPace,
                    paceMarker: isUsedMode ? Double(self.state.claudePaceReserve) : nil
                )
                
                let c7dVal = isUsedMode ? self.state.claude7d : max(0, 100 - self.state.claude7d)
                let c7dTitle = isUsedMode ? "Hàng tuần: \(c7dVal)% đã dùng" : "Hàng tuần: \(c7dVal)% còn lại"
                
                MetricRow(
                    title: c7dTitle,
                    percent: Double(c7dVal),
                    resetText: formatResetWithEst(raw: self.state.claude7dReset),
                    tint: Color(red: 218/255, green: 119/255, blue: 86/255)
                )
                
                ForEach(self.state.claudeScoped) { scoped in
                    let sVal = isUsedMode ? scoped.used : max(0, 100 - scoped.used)
                    MetricRow(
                        title: isUsedMode ? "\(scoped.model) tuần: \(sVal)% đã dùng" : "\(scoped.model) tuần: \(sVal)% còn lại",
                        percent: Double(sVal),
                        resetText: formatResetWithEst(raw: scoped.resetText),
                        tint: Color(red: 218/255, green: 119/255, blue: 86/255)
                    )
                }
            }
            
            Divider()
            
            // 3. Pool Account List (Minimal Card-based with Instant Reordering)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Thứ tự sử dụng")
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("▲▼ đổi mức ưu tiên")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                
                let rows = self.state.routeRows
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    CompactAccountRowView(
                        email: row.id,
                        index: index,
                        totalCount: rows.count,
                        subDetails: row.subDetails,
                        cells: row.cells,
                        isAvailable: row.isAvailable,
                        isCurrent: self.state.activeRouteId == row.id,
                        isProbeError: row.isProbeError,
                        isDisabled: row.isDisabled,
                        onMoveUp: { self.state.moveRoute(fromIndex: index, toIndex: index - 1) },
                        onMoveDown: { self.state.moveRoute(fromIndex: index, toIndex: index + 1) },
                        onSwitch: { AppDelegate.shared?.confirmSwitch(to: row.id) },
                        onToggleEnabled: row.isPaused ? nil : { AppDelegate.shared?.confirmToggleEnabled(email: row.id, enable: row.isDisabled) },
                        unavailableLabel: row.unavailableLabel,
                        statusText: row.statusText,
                        title: row.title,
                        badge: row.badge
                    )
                }
            }
            
            if let backup = self.state.backup {
                Divider()
                BackupSectionView(
                    info: backup,
                    onToggle: { AppDelegate.shared?.confirmBackupToggle(enable: !backup.enabled) },
                    onSelect: { key in
                        guard backup.selected?.key != key else { return }
                        self.state.setBackup(enabled: nil, model: key, onError: { AppDelegate.shared?.showBackupError($0) })
                    }
                )
            }

            Divider()
            
            // 4. Token Keeper Proactive Section (Clickable -> Opens Detail Window)
            Button(action: {
                AppDelegate.shared?.openKeeperWindow()
            }) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline) {
                        HStack(spacing: 6) {
                            Image(systemName: "shield.lefthalf.filled")
                                .font(.system(size: 12))
                                .foregroundStyle(Color(red: 52/255, green: 199/255, blue: 89/255))
                            Text("Token Keeper Proactive")
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                        }
                        Spacer()
                        HStack(spacing: 4) {
                            Text(self.state.keeperStatus)
                                .font(.footnote)
                                .foregroundStyle(Color(red: 52/255, green: 199/255, blue: 89/255))
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    
                    // Progress Bar cho chu kỳ Keeper 4h
                    UsageProgressBar(
                        percent: self.state.keeperCyclePercent,
                        tint: Color(red: 52/255, green: 199/255, blue: 89/255),
                        warningMarkerPercents: [50.0],
                        accentPaceMarker: nil
                    )
                    
                    HStack(alignment: .firstTextBaseline) {
                        Text("Lần làm mới trước: \(self.state.lastRefresh)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("Kế tiếp: \(self.state.nextRefresh) · \(Int(self.state.keeperCyclePercent))% chu kỳ")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 6)
        .frame(width: 365, alignment: .topLeading)
    }
}

// MARK: - Model Quota Row in AGY
struct AgyModelRowView: View {
    let name: String
    let used: Int
    let remaining: Int
    let reset: String
    let tint: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(self.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(self.used)% đã dùng")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            UsageProgressBar(percent: Double(self.used), tint: self.tint)
            HStack(alignment: .firstTextBaseline) {
                Text("Còn lại \(self.remaining)%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(self.reset.isEmpty ? "Hồi: Sẵn sàng" : (self.reset.hasPrefix("Hồi") ? self.reset : "Hồi: \(self.reset)"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Antigravity Full Card View (100% Consistent with ClaudeFullCardView & CodexBar Design)
struct AntigravityFullCardView: View {
    @ObservedObject var state: QuotaState
    
    // Consistent colors with CodexBar design system
    let geminiTint = Color(red: 66/255, green: 133/255, blue: 244/255) // Google Blue
    let claudeGptTint = Color(red: 139/255, green: 92/255, blue: 246/255) // Purple
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 1. Header (Active Account Identifier & Tier) - Exact CodexBar 1:1 Layout & Subtitle
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    HStack(alignment: .center, spacing: 6) {
                        if let nsImg = loadTemplateIcon(name: "antigravity") {
                            Image(nsImage: nsImg)
                                .renderingMode(.template)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 14, height: 14)
                                .foregroundStyle(Color(red: 0/255, green: 195/255, blue: 137/255))
                        }
                        Text("Antigravity")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    Spacer()
                    Text(self.state.agyEmail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                HStack(alignment: .firstTextBaseline) {
                    Text(self.state.lastQuotaFetchAgoText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Gói \(self.state.agyTier)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            Divider()
            
            // 2. Models Breakdown (All 4 Quota Bars using standard MetricRow)
            VStack(alignment: .leading, spacing: 12) {
                let isUsedMode = self.state.quotaDisplayMode == "used"
                
                // Group 1: Gemini Models
                VStack(alignment: .leading, spacing: 6) {
                    Text("GEMINI MODELS (Flash, Pro)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    
                    let g5hVal = isUsedMode ? (100 - self.state.agyGemini5hRemaining) : self.state.agyGemini5hRemaining
                    let g5hTitle = isUsedMode ? "Giới hạn 5h: \(g5hVal)% đã dùng" : "Giới hạn 5h còn lại: \(g5hVal)%"
                    let g5hPace = isUsedMode ? "\(self.state.agyGemini5hRemaining)% còn lại" : "Đã dùng \(100 - self.state.agyGemini5hRemaining)%"
                    
                    MetricRow(
                        title: g5hTitle,
                        percent: Double(g5hVal),
                        resetText: formatResetWithEst(raw: self.state.agyGemini5hRefresh),
                        tint: Color(red: 0/255, green: 195/255, blue: 137/255), // Teal Green (Antigravity)
                        paceText: g5hPace,
                        paceMarker: nil
                    )
                    
                    let gWkVal = isUsedMode ? (100 - self.state.agyGeminiWeeklyRemaining) : self.state.agyGeminiWeeklyRemaining
                    let gWkTitle = isUsedMode ? "Giới hạn tuần: \(gWkVal)% đã dùng" : "Giới hạn tuần còn lại: \(gWkVal)%"
                    let gWkPace = isUsedMode ? "\(self.state.agyGeminiWeeklyRemaining)% còn lại" : "Đã dùng \(100 - self.state.agyGeminiWeeklyRemaining)%"
                    
                    MetricRow(
                        title: gWkTitle,
                        percent: Double(gWkVal),
                        resetText: formatResetWithEst(raw: self.state.agyGeminiWeeklyRefresh),
                        tint: Color(red: 245/255, green: 197/255, blue: 66/255), // Amber Yellow (Antigravity)
                        paceText: gWkPace,
                        paceMarker: nil
                    )
                }
                
                Divider()
                
                // Group 2: Claude & GPT Models
                VStack(alignment: .leading, spacing: 6) {
                    Text("CLAUDE & GPT MODELS (Opus, Sonnet, GPT-OSS)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    
                    let cg5hVal = isUsedMode ? (100 - self.state.agyClaudeGpt5hRemaining) : self.state.agyClaudeGpt5hRemaining
                    let cg5hTitle = isUsedMode ? "Giới hạn 5h: \(cg5hVal)% đã dùng" : "Giới hạn 5h còn lại: \(self.state.agyClaudeGpt5hText)"
                    let cg5hPace = isUsedMode ? "\(self.state.agyClaudeGpt5hRemaining)% còn lại" : "100% khả dụng"
                    
                    MetricRow(
                        title: cg5hTitle,
                        percent: Double(cg5hVal),
                        resetText: formatResetWithEst(raw: self.state.agyClaudeGpt5hRefresh),
                        tint: Color(red: 0/255, green: 195/255, blue: 137/255), // Teal Green (Antigravity)
                        paceText: cg5hPace,
                        paceMarker: nil
                    )
                    
                    let cgWkVal = isUsedMode ? (100 - self.state.agyClaudeGptWeeklyRemaining) : self.state.agyClaudeGptWeeklyRemaining
                    let cgWkTitle = isUsedMode ? "Giới hạn tuần: \(cgWkVal)% đã dùng" : "Giới hạn tuần còn lại: \(cgWkVal)%"
                    let cgWkPace = isUsedMode ? "\(self.state.agyClaudeGptWeeklyRemaining)% còn lại" : "Đã dùng \(100 - self.state.agyClaudeGptWeeklyRemaining)%"
                    
                    MetricRow(
                        title: cgWkTitle,
                        percent: Double(cgWkVal),
                        resetText: formatResetWithEst(raw: self.state.agyClaudeGptWeeklyRefresh),
                        tint: Color(red: 245/255, green: 197/255, blue: 66/255), // Amber Yellow (Antigravity)
                        paceText: cgWkPace,
                        paceMarker: nil
                    )
                }
            }
            
            Divider()
            
            // 3. Connected Account
            VStack(alignment: .leading, spacing: 6) {
                Text("Tài khoản kết nối")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                
                CompactAccountRowView(
                    email: self.state.agyEmail,
                    index: 0,
                    totalCount: 1,
                    subDetails: "Google CloudCode · Project: \(self.state.agyProject)",
                    isAvailable: true,
                    isCurrent: true,
                    isProbeError: false,
                    onMoveUp: nil,
                    onMoveDown: nil,
                    onSwitch: {},
                    statusText: "Hoạt động"
                )
            }
            
            Divider()
            
            // 4. Token Keeper Proactive Section
            Button(action: {
                AppDelegate.shared?.openKeeperWindow()
            }) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline) {
                        HStack(spacing: 6) {
                            Image(systemName: "shield.lefthalf.filled")
                                .font(.system(size: 12))
                                .foregroundStyle(Color(red: 52/255, green: 199/255, blue: 89/255))
                            Text("Token Keeper Proactive")
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                        }
                        Spacer()
                        HStack(spacing: 4) {
                            Text(self.state.keeperStatus)
                                .font(.footnote)
                                .foregroundStyle(Color(red: 52/255, green: 199/255, blue: 89/255))
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    
                    UsageProgressBar(
                        percent: self.state.keeperCyclePercent,
                        tint: Color(red: 52/255, green: 199/255, blue: 89/255),
                        warningMarkerPercents: [50.0],
                        accentPaceMarker: nil
                    )
                    
                    HStack(alignment: .firstTextBaseline) {
                        Text("Lần làm mới trước: \(self.state.lastRefresh)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("Kế tiếp: \(self.state.nextRefresh) · \(Int(self.state.keeperCyclePercent))% chu kỳ")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 6)
        .frame(width: 365, alignment: .topLeading)
    }
}


func formatTelemetryInterval(_ ms: Double) -> String {
    if ms < 1000.0 {
        return "\(Int(ms)) ms"
    } else if ms < 60_000.0 {
        let sec = ms / 1000.0
        if sec == floor(sec) {
            return "\(Int(sec)) giây"
        } else {
            return String(format: "%.1f giây", sec)
        }
    } else if ms < 3_600_000.0 {
        let mins = ms / 60_000.0
        if mins == floor(mins) {
            return "\(Int(mins)) phút"
        } else {
            return String(format: "%.1f phút", mins)
        }
    } else {
        let hours = ms / 3_600_000.0
        if hours == floor(hours) {
            return "\(Int(hours)) giờ"
        } else {
            return String(format: "%.1f giờ", hours)
        }
    }
}

// MARK: - Native Settings View (CodexBarCustom Preferences)
struct SettingsView: View {
    @ObservedObject var state: QuotaState
    let onSave: () -> Void
    
    let intervals = [1, 15, 30, 60, 300]
    
    var contentView: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cài đặt Orbiter Menubar")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("Tùy chỉnh tần suất cập nhật Quota AI & Server Telemetry")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 14) {
                Toggle("Làm mới ngay khi mở Menu (Refresh on Open)", isOn: Binding(
                    get: { self.state.refreshOnOpen },
                    set: { newVal in
                        self.state.refreshOnOpen = newVal
                        UserDefaults.standard.set(newVal, forKey: "quota_refresh_on_open")
                    }
                ))
                .font(.headline)
                
                Text("Tự động gửi yêu cầu kiểm tra dữ liệu quota & thông số phần cứng Ubuntu mới nhất mỗi khi bạn click vào biểu tượng trên Menubar.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Chế độ hiển thị Quota AI (Toàn bộ Nhà cung cấp):")
                    .font(.headline)
                
                Picker("Kiểu hiển thị Quota", selection: Binding(
                    get: { self.state.quotaDisplayMode },
                    set: { newVal in
                        self.state.quotaDisplayMode = newVal
                        self.onSave()
                    }
                )) {
                    HStack(spacing: 6) {
                        Image(systemName: "chart.bar.fill")
                        Text("Đã sử dụng (% đã dùng – Giống Claude / Chuẩn CodexBar)")
                    }.tag("used")
                    
                    HStack(spacing: 6) {
                        Image(systemName: "gauge.with.needle.fill")
                        Text("Còn lại (% khả dụng – Giống Antigravity mặc định)")
                    }.tag("remaining")
                }
                .pickerStyle(.radioGroup)
                .padding(.leading, 8)
                
                Text("Lựa chọn này được đồng bộ tức thì trên cả thanh Menubar, thẻ Claude, Antigravity và danh sách tài khoản.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Tần suất tự động làm mới Quota AI:")
                    .font(.headline)
                
                Picker("Tần suất Quota", selection: Binding(
                    get: { self.state.refreshInterval },
                    set: { newVal in
                        self.state.refreshInterval = newVal
                        self.onSave()
                    }
                )) {
                    Text("15 giây (Nhanh)").tag(15)
                    Text("30 giây (Chuẩn)").tag(30)
                    Text("1 phút (Mặc định)").tag(60)
                    Text("5 phút (Tiết kiệm pin)").tag(300)
                }
                .pickerStyle(.radioGroup)
                .padding(.leading, 8)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Tần suất cập nhật Menubar & Hệ thống:")
                        .font(.headline)
                    Spacer()
                    Text(formatTelemetryInterval(self.state.telemetryIntervalMs))
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.accentColor)
                }
                
                // Fine-tuning Stepper & Direct Adjustment Buttons
                HStack(spacing: 8) {
                    Text("Tinh chỉnh:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Button("-500ms") {
                        let current = self.state.telemetryIntervalMs
                        self.state.telemetryIntervalMs = max(100.0, current - 500.0)
                        self.onSave()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button("-100ms") {
                        let current = self.state.telemetryIntervalMs
                        self.state.telemetryIntervalMs = max(100.0, current - 100.0)
                        self.onSave()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button("+100ms") {
                        let current = self.state.telemetryIntervalMs
                        self.state.telemetryIntervalMs = min(86_400_000.0, current + 100.0)
                        self.onSave()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button("+500ms") {
                        let current = self.state.telemetryIntervalMs
                        self.state.telemetryIntervalMs = min(86_400_000.0, current + 500.0)
                        self.onSave()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Spacer()
                    
                    Button("Mặc định (2000 ms)") {
                        self.state.telemetryIntervalMs = 2000.0
                        self.onSave()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                
                // Quick Presets
                VStack(alignment: .leading, spacing: 6) {
                    Text("Mốc chọn nhanh (Tối thiểu 100 ms – Tối đa 24 giờ):")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 78), spacing: 6)], spacing: 6) {
                        ForEach([
                            (100.0, "100 ms"),
                            (250.0, "250 ms"),
                            (500.0, "500 ms"),
                            (1000.0, "1 s"),
                            (2000.0, "2 s (MĐ)"),
                            (3000.0, "3 s"),
                            (5000.0, "5 s"),
                            (10000.0, "10 s"),
                            (30000.0, "30 s"),
                            (60000.0, "1 phút"),
                            (300000.0, "5 phút"),
                            (3600000.0, "1 giờ"),
                            (86400000.0, "24 giờ")
                        ], id: \.0) { item in
                            Button(action: {
                                self.state.telemetryIntervalMs = item.0
                                self.onSave()
                            }) {
                                Text(item.1)
                                    .font(.system(size: 11, weight: abs(self.state.telemetryIntervalMs - item.0) < 1.0 ? .bold : .regular))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 3)
                            }
                            .buttonStyle(.bordered)
                            .tint(abs(self.state.telemetryIntervalMs - item.0) < 1.0 ? Color.accentColor : Color.secondary.opacity(0.3))
                        }
                    }
                }
                
                Text("Hỗ trợ phạm vi từ 100 ms (tốc độ cực nhanh như btop/glances) đến 24 giờ (tiết kiệm tài nguyên tuyệt đối). Mặc định chuẩn: 2000 ms.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Thông tin kết nối:")
                    .font(.headline)
                HStack {
                    Text("Quota Bridge Host:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("http://100.127.1.234:8318")
                        .font(.subheadline.monospaced())
                }
                HStack {
                    Text("Token Keeper Proactive:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Đang chạy (Chu kỳ 4h)")
                        .font(.subheadline)
                        .foregroundStyle(Color(red: 52/255, green: 199/255, blue: 89/255))
                }
            }
            
            Spacer()
            
            HStack {
                Spacer()
                Button("Đóng") {
                    NSApp.keyWindow?.close()
                }
                .keyboardShortcut(.defaultAction)
                .controlSize(.regular)
            }
        }
        .padding(22)
    }
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            contentView
        }
        .frame(minWidth: 500, idealWidth: 520, maxWidth: 650, minHeight: 450, idealHeight: 620)
    }
}

// MARK: - State Management with Remote Priority Switching
class QuotaState: ObservableObject {
    @Published var claudeEmail = ""
    @Published var claudePlan = "Max 5x"
    @Published var claude5h = 11
    @Published var claude7d = 26
    @Published var claude5hReset = "3h"
    @Published var claude7dReset = "6d 13h"
    @Published var claudePaceReserve = 89
    @Published var switchingMessage = ""
    @Published var claudeAccounts: [PoolAccountItem] = []
    @Published var claudeScoped: [ScopedQuota] = []
    
    @Published var agyEmail = "hieudat2310.bh@gmail.com"
    @Published var agyProject = "hazel-dock"
    @Published var agyTier = "Pro"
    @Published var geminiUsed = 48
    @Published var geminiReset = "3h 14m"
    @Published var agyClaudeUsed = 57
    @Published var agyClaudeReset = "3d 19h"
    @Published var agyGptUsed = 57
    
    // Antigravity structured groups matching CodexBar
    @Published var agyGemini5hRemaining: Int = 52
    @Published var agyGemini5hRefresh: String = "3h 14m"
    @Published var agyGeminiWeeklyRemaining: Int = 66
    @Published var agyGeminiWeeklyRefresh: String = "3d 7h"
    
    @Published var consoleKeys: [ConsoleKeyItem] = []
    @Published var backup: BackupInfo? = nil
    @Published var routingOrder: [String] = []
    @Published var agyClaudeGpt5hText: String = "Quota available"
    @Published var agyClaudeGpt5hRemaining: Int = 100
    @Published var agyClaudeGpt5hRefresh: String = "4h 24m"
    @Published var agyClaudeGptWeeklyRemaining: Int = 43
    @Published var agyClaudeGptWeeklyRefresh: String = "3d 19h"
    
    @Published var lastRefresh = "12:29"
    @Published var nextRefresh = "16:29"
    @Published var keeperStatus = "Hoạt động"
    @Published var keeperCyclePercent: Double = 65.0
    @Published var keeperSchedule: String = "Mỗi 4 giờ (Proactive Refresh)"
    @Published var keeperBackupCount: Int = 34
    @Published var keeperLogs: [String] = []
    
    // Gateway / DeepSeek Usage Telemetry
    @Published var gwEnabled: Bool = true
    @Published var gwProviderName: String = "LiteLLM / DeepSeek Gateway"
    @Published var gwBaseUrl: String = "https://luong-30005.motcaigido.xyz"
    @Published var gwKeyAlias: String = "HieuDat"
    @Published var gwSpendFormatted: String = "$0.00786"
    @Published var gwMaxBudgetFormatted: String = "$50.00"
    @Published var gwSpendPercent: Double = 0.02
    @Published var gwIsActiveNow: Bool = false
    @Published var gwLastActiveHuman: String = "Chưa hoạt động"
    @Published var gwLastActiveTime: String = ""
    @Published var gwQuickCommands: [GatewayCommandItem] = []
    
    // Ubuntu System & Port & Tunnel Telemetry
    @Published var sysMetrics: HostMetricInfo = HostMetricInfo()
    @Published var sysPorts: [PortInfo] = []
    @Published var sysServices: [ServiceInfo] = []
    @Published var sysDocker: [DockerContainerInfo] = []
    @Published var sysTunnels: [TunnelInfo] = []
    @Published var sysActionMessage: String = ""
    @Published var isStartingTunnel: Bool = false
    
    // Default refresh: 60s (1 phút)
    @Published var lastQuotaFetchDate: Date = Date()
    @Published var lastQuotaFetchAgoText: String = "Vừa xong"
    @Published var bridgeHost: String = UserDefaults.standard.string(forKey: "quota_bridge_host") ?? "http://100.127.1.234:8318"
    @Published var refreshOnOpen: Bool = UserDefaults.standard.bool(forKey: "quota_refresh_on_open")
    @Published var refreshInterval: Int = UserDefaults.standard.integer(forKey: "quota_refresh_interval") == 0 ? 60 : UserDefaults.standard.integer(forKey: "quota_refresh_interval")
    @Published var telemetryIntervalMs: Double = {
        let val = UserDefaults.standard.double(forKey: "ubuntu_telemetry_interval_ms")
        if val > 0 { return min(86_400_000.0, max(100.0, val)) }
        // Migration from legacy seconds key
        let legacySec = UserDefaults.standard.integer(forKey: "ubuntu_telemetry_interval")
        if legacySec > 0 { return Double(legacySec) * 1000.0 }
        return 2000.0 // Default 2000ms
    }()
    @Published var quotaDisplayMode: String = UserDefaults.standard.string(forKey: "quota_display_mode") ?? "used" // "used" hoặc "remaining"
    @Published var showGatewaySpendOnMenubar: Bool = false
    
    var baseUrl: String {
        let host = bridgeHost.trimmingCharacters(in: .whitespacesAndNewlines)
        return host.hasSuffix("/") ? String(host.dropLast()) : host
    }

    static let bridgeSecret = "__CLIPROXY_BRIDGE_SECRET__"

    func authedRequest(_ url: URL) -> URLRequest {
        var req = URLRequest(url: url)
        req.setValue("Bearer \(Self.bridgeSecret)", forHTTPHeaderField: "Authorization")
        return req
    }
    
    var onUpdate: (() -> Void)?
    
    func saveInterval() {
        UserDefaults.standard.set(refreshInterval, forKey: "quota_refresh_interval")
        UserDefaults.standard.set(telemetryIntervalMs, forKey: "ubuntu_telemetry_interval_ms")
        UserDefaults.standard.set(Int(telemetryIntervalMs / 1000.0), forKey: "ubuntu_telemetry_interval")
        UserDefaults.standard.set(quotaDisplayMode, forKey: "quota_display_mode")
        UserDefaults.standard.set(bridgeHost, forKey: "quota_bridge_host")
        AppDelegate.shared?.updateTimer()
        self.onUpdate?()
    }
    
    func saveOrder() {
        let newOrder = self.routeRows.map { $0.id }
        self.switchingMessage = "Đang lưu thứ tự Pool..."
        
        guard let url = URL(string: "\(self.baseUrl)/v1/set-order") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(Self.bridgeSecret)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["order": newOrder]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: req) { data, _, _ in
            DispatchQueue.main.async {
                self.switchingMessage = "Đã cập nhật thứ tự selector!"
                // Re-fetch to synchronize active account metrics with backend
                self.fetchData()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.switchingMessage = ""
                }
            }
        }.resume()
    }

    static func currentAccount(in accounts: [PoolAccountItem]) -> PoolAccountItem? {
        accounts.first { !$0.isDisabled && !$0.isPaused && $0.isAvailable }
            ?? accounts.first { !$0.isDisabled && !$0.isPaused }
            ?? accounts.first
    }

    var routeRows: [RouteRow] {
        var byId: [String: RouteRow] = [:]
        let isUsedMode = quotaDisplayMode == "used"
        for a in claudeAccounts {
            byId[a.email] = RouteRow(id: a.email, subDetails: a.statusLine, cells: a.quotaCells(isUsedMode: isUsedMode), isAvailable: a.isAvailable, isProbeError: a.isProbeError, isDisabled: a.isDisabled, isPaused: a.isPaused, unavailableLabel: a.isPaused ? "Cách ly" : "Hết hạn", statusText: (a.isAvailable && !a.isDisabled && !a.isPaused) ? "Sẵn sàng" : nil, badge: a.plan)
        }
        for k in consoleKeys {
            byId[k.id] = RouteRow(id: k.id, subDetails: k.detailText, isAvailable: k.isUsable, isProbeError: k.state == "rate_limited", isDisabled: !k.enabled, isConsole: true, unavailableLabel: k.state == "no_credit" ? "Hết credit" : "Lỗi key", statusText: (k.state == "ok" && k.enabled) ? "Còn credit" : nil, title: k.displayName, badge: k.id)
        }
        var rows = routingOrder.compactMap { byId[$0] }
        let seen = Set(rows.map { $0.id })
        rows += claudeAccounts.filter { !seen.contains($0.email) }.compactMap { byId[$0.email] }
        if let activeIndex = rows.firstIndex(where: { !$0.isDisabled && !$0.isPaused && $0.isAvailable }) {
            rows[activeIndex].statusText = "Đang dùng"
        }
        return rows
    }

    var activeRouteId: String? {
        let rows = routeRows
        return rows.first { !$0.isDisabled && !$0.isPaused && $0.isAvailable }?.id
            ?? rows.first { !$0.isDisabled && !$0.isPaused }?.id
    }

    func moveRoute(fromIndex: Int, toIndex: Int) {
        var ids = routeRows.map { $0.id }
        guard fromIndex >= 0, fromIndex < ids.count, toIndex >= 0, toIndex < ids.count, fromIndex != toIndex else { return }
        let moved = ids.remove(at: fromIndex)
        ids.insert(moved, at: toIndex)
        self.routingOrder = ids
        let poolIds = ids.filter { id in claudeAccounts.contains { $0.email == id } }
        self.claudeAccounts = poolIds.compactMap { id in claudeAccounts.first { $0.email == id } } + claudeAccounts.filter { !poolIds.contains($0.email) }
        if let topAcc = Self.currentAccount(in: claudeAccounts) {
            self.claudeEmail = topAcc.email
            self.claudePlan = topAcc.plan
            self.claude5h = topAcc.used5h
            self.claude7d = topAcc.usedWeekly
            self.claude5hReset = topAcc.reset5h.isEmpty ? "Đầy đủ" : topAcc.reset5h
            self.claude7dReset = topAcc.resetWeekly
            self.claudePaceReserve = topAcc.remaining5h
            self.claudeScoped = topAcc.scoped
            self.onUpdate?()
        }
        self.saveOrder()
    }

    func moveAccount(fromIndex: Int, toIndex: Int) {
        guard fromIndex >= 0, fromIndex < claudeAccounts.count,
              toIndex >= 0, toIndex < claudeAccounts.count,
              fromIndex != toIndex else { return }
        
        var accounts = claudeAccounts
        let moved = accounts.remove(at: fromIndex)
        accounts.insert(moved, at: toIndex)
        self.claudeAccounts = accounts
        
        // If the top account changed, immediately update claudeEmail to follow the new #1 priority
        if let topAcc = Self.currentAccount(in: accounts) {
            self.claudeEmail = topAcc.email
            self.claudePlan = topAcc.plan
            self.claude5h = topAcc.used5h
            self.claude7d = topAcc.usedWeekly
            self.claude5hReset = topAcc.reset5h.isEmpty ? "Đầy đủ" : topAcc.reset5h
            self.claude7dReset = topAcc.resetWeekly
            self.claudePaceReserve = topAcc.remaining5h
            self.claudeScoped = topAcc.scoped
            self.onUpdate?()
        }
        
        self.saveOrder()
    }

    func updateAgoText() {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let timeStr = timeFormatter.string(from: self.lastQuotaFetchDate)
        
        let delta = Date().timeIntervalSince(self.lastQuotaFetchDate)
        let elapsed = max(0, Int(delta))
        let relativeStr: String
        if elapsed < 15 {
            relativeStr = "Vừa xong"
        } else if elapsed < 60 {
            relativeStr = "\(elapsed)s trước"
        } else if elapsed < 3600 {
            relativeStr = "\(elapsed / 60)m trước"
        } else if elapsed < 86400 {
            relativeStr = "\(elapsed / 3600)h trước"
        } else {
            relativeStr = "1d trước"
        }
        self.lastQuotaFetchAgoText = "Cập nhật lúc \(timeStr) · \(relativeStr)"
    }

    func switchPriority(to email: String) {
        self.switchingMessage = "Đang chuyển sang \(email)..."
        guard let url = URL(string: "\(self.baseUrl)/v1/set-priority") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(Self.bridgeSecret)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["email": email] as [String : Any]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: req) { data, _, _ in
            DispatchQueue.main.async {
                self.switchingMessage = "Đã chuyển & kiểm tra thành công!"
                if self.claudeAccounts.contains(where: { $0.email == email }) {
                    self.claudeEmail = email
                }
                self.routingOrder = [email] + self.routingOrder.filter { $0 != email }
                self.fetchData()
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.switchingMessage = ""
                }
            }
        }.resume()
    }
    
    func setBackup(enabled: Bool?, model: String?, onError: @escaping (String) -> Void) {
        guard let url = URL(string: "\(self.baseUrl)/v1/set-backup") else { return }
        var body: [String: Any] = [:]
        if let enabled = enabled { body["enabled"] = enabled }
        if let model = model { body["model"] = model }
        self.switchingMessage = "Đang cập nhật dự phòng..."
        var req = authedRequest(url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: req) { data, response, error in
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let json = data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
            DispatchQueue.main.async {
                if status == 200 {
                    self.switchingMessage = enabled == true ? "Đã bật dự phòng Aperture" : (enabled == false ? "Đã tắt dự phòng Aperture" : "Đã chọn model dự phòng")
                } else {
                    self.switchingMessage = ""
                    onError(json?["error"] as? String ?? error?.localizedDescription ?? "HTTP \(status)")
                }
                self.fetchData()
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.switchingMessage = ""
                }
            }
        }.resume()
    }

    func setEnabled(email: String, enabled: Bool, onError: @escaping (String) -> Void) {
        guard let url = URL(string: "\(self.baseUrl)/v1/set-enabled") else { return }
        self.switchingMessage = enabled ? "Đang bật \(email)..." : "Đang tắt \(email)..."
        var req = authedRequest(url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["email": email, "enabled": enabled])
        URLSession.shared.dataTask(with: req) { data, response, error in
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let body = data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
            DispatchQueue.main.async {
                if status == 200 {
                    self.switchingMessage = enabled ? "Đã bật \(email)" : "Đã tắt \(email)"
                } else {
                    self.switchingMessage = ""
                    onError(body?["error"] as? String ?? error?.localizedDescription ?? "HTTP \(status)")
                }
                self.fetchData()
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.switchingMessage = ""
                }
            }
        }.resume()
    }

    func fetchData() {
        if let url = URL(string: "\(self.baseUrl)/v1/keeper-telemetry") {
            URLSession.shared.dataTask(with: authedRequest(url)) { data, _, _ in
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
                DispatchQueue.main.async {
                    if let timer = json["timer"] as? [String: Any] {
                        self.lastRefresh = timer["last_run"] as? String ?? self.lastRefresh
                        self.nextRefresh = timer["next_run"] as? String ?? self.nextRefresh
                        let status = timer["status"] as? String ?? "active"
                        self.keeperStatus = status == "active" ? "Hoạt động" : status
                        self.keeperSchedule = timer["schedule"] as? String ?? self.keeperSchedule
                        if let cp = timer["cycle_percent"] as? Double {
                            self.keeperCyclePercent = cp
                        } else if let cp = timer["cycle_percent"] as? Int {
                            self.keeperCyclePercent = Double(cp)
                        }
                    }
                    if let bCount = json["backup_count"] as? Int {
                        self.keeperBackupCount = bCount
                    }
                    if let logsList = json["logs"] as? [String] {
                        self.keeperLogs = logsList
                    }
                    self.onUpdate?()
                }
            }.resume()
        }
        
        if let agyUrl = URL(string: "\(self.baseUrl)/v1/antigravity-quota") {
            URLSession.shared.dataTask(with: authedRequest(agyUrl)) { data, _, _ in
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
                DispatchQueue.main.async {
                    self.agyEmail = json["email"] as? String ?? self.agyEmail
                    self.agyProject = json["project_id"] as? String ?? self.agyProject
                    self.agyTier = json["tier"] as? String ?? "Pro"
                    
                    if let gem = json["gemini"] as? [String: Any] {
                        self.agyGemini5hRemaining = gem["five_hour_remaining"] as? Int ?? self.agyGemini5hRemaining
                        self.agyGemini5hRefresh = gem["five_hour_refresh"] as? String ?? self.agyGemini5hRefresh
                        self.agyGeminiWeeklyRemaining = gem["weekly_remaining"] as? Int ?? self.agyGeminiWeeklyRemaining
                        self.agyGeminiWeeklyRefresh = gem["weekly_refresh"] as? String ?? self.agyGeminiWeeklyRefresh
                        self.geminiUsed = 100 - self.agyGemini5hRemaining
                        self.geminiReset = self.agyGemini5hRefresh
                    }
                    
                    if let cg = json["claude_gpt"] as? [String: Any] {
                        self.agyClaudeGpt5hText = cg["five_hour_text"] as? String ?? self.agyClaudeGpt5hText
                        self.agyClaudeGpt5hRemaining = cg["five_hour_remaining"] as? Int ?? self.agyClaudeGpt5hRemaining
                        self.agyClaudeGpt5hRefresh = cg["five_hour_refresh"] as? String ?? self.agyClaudeGpt5hRefresh
                        self.agyClaudeGptWeeklyRemaining = cg["weekly_remaining"] as? Int ?? self.agyClaudeGptWeeklyRemaining
                        self.agyClaudeGptWeeklyRefresh = cg["weekly_refresh"] as? String ?? self.agyClaudeGptWeeklyRefresh
                        self.agyClaudeUsed = 100 - self.agyClaudeGptWeeklyRemaining
                        self.agyClaudeReset = self.agyClaudeGptWeeklyRefresh
                        self.agyGptUsed = self.agyClaudeUsed
                    }
                    self.updateAgoText()
                    self.onUpdate?()
                }
            }.resume()
        }
        
        if let poolUrl = URL(string: "\(self.baseUrl)/v1/pool-status") {
            URLSession.shared.dataTask(with: authedRequest(poolUrl)) { data, _, _ in
                guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let accs = json["accounts"] as? [[String: Any]] else { return }
                DispatchQueue.main.async {
                    var parsedList: [PoolAccountItem] = []
                    for a in accs {
                        let em = a["email"] as? String ?? ""
                        let nm = a["name"] as? String ?? em
                        let isAvail = a["is_available"] as? Bool ?? false
                        let isProbeErr = a["is_probe_error"] as? Bool ?? false
                        let errHint = a["error_hint"] as? String ?? ""
                        let rem5h = a["remaining_5h"] as? Int ?? 0
                        let u5h = a["used_5h"] as? Int ?? (100 - rem5h)
                        let r5h = a["reset_5h"] as? String ?? ""
                        let remWk = a["remaining_weekly"] as? Int ?? 0
                        let uWk = a["used_weekly"] as? Int ?? (100 - remWk)
                        let rWk = a["reset_weekly"] as? String ?? ""
                        let pln = a["plan"] as? String ?? "Max"
                        let disabled = a["is_disabled"] as? Bool ?? false
                        let paused = a["is_paused"] as? Bool ?? false
                        let scopedList: [ScopedQuota] = (a["scoped_weekly"] as? [[String: Any]] ?? []).compactMap { w in
                            guard let model = w["model"] as? String, let used = w["used"] as? Double else { return nil }
                            return ScopedQuota(model: model, used: Int(used.rounded()), resetText: w["reset_text"] as? String ?? "")
                        }

                        parsedList.append(PoolAccountItem(
                            email: em,
                            name: nm,
                            plan: pln,
                            isAvailable: isAvail,
                            isProbeError: isProbeErr,
                            errorHint: errHint,
                            remaining5h: rem5h,
                            used5h: u5h,
                            reset5h: r5h,
                            remainingWeekly: remWk,
                            usedWeekly: uWk,
                            resetWeekly: rWk,
                            isDisabled: disabled,
                            isPaused: paused,
                            scoped: scopedList
                        ))
                    }
                    self.claudeAccounts = parsedList

                    let targetAccount = Self.currentAccount(in: parsedList)
                    
                    if let current = targetAccount {
                        self.claudeEmail = current.email
                        self.claudePlan = current.plan
                        self.claude5h = current.used5h
                        self.claude7d = current.usedWeekly
                        if current.isProbeError {
                            self.claude5hReset = "Tạm nghẽn 429"
                            self.claude7dReset = "Tạm nghẽn 429"
                        } else {
                            self.claude5hReset = current.reset5h.isEmpty ? "Đầy đủ" : current.reset5h
                            self.claude7dReset = current.resetWeekly
                        }
                        self.claudePaceReserve = current.remaining5h
                        self.claudeScoped = current.scoped
                    }
                    
                    if let cs = json["console"] as? [String: Any] {
                        self.consoleKeys = (cs["keys"] as? [[String: Any]] ?? []).map {
                            ConsoleKeyItem(id: $0["id"] as? String ?? "", org: $0["org"] as? String ?? "", state: $0["state"] as? String ?? "", enabled: $0["enabled"] as? Bool ?? true)
                        }
                    } else {
                        self.consoleKeys = []
                    }
                    self.routingOrder = json["order"] as? [String] ?? []
                    if let bk = json["backup"] as? [String: Any] {
                        let fb = bk["fallback"] as? [String: Any] ?? [:]
                        self.backup = BackupInfo(
                            online: bk["online"] as? Bool ?? false,
                            latencyMs: bk["latency_ms"] as? Int ?? 0,
                            enabled: fb["enabled"] as? Bool ?? false,
                            models: (bk["models"] as? [[String: Any]] ?? []).map {
                                BackupModelItem(key: $0["key"] as? String ?? "", label: $0["label"] as? String ?? "", usable: $0["usable"] as? Bool ?? false, selected: $0["selected"] as? Bool ?? false)
                            }
                        )
                    } else {
                        self.backup = nil
                    }

                    // Parse Gateway Telemetry
                    if let gw = json["gateway"] as? [String: Any] {
                        self.gwEnabled = gw["enabled"] as? Bool ?? true
                        self.gwProviderName = gw["provider_name"] as? String ?? self.gwProviderName
                        self.gwBaseUrl = gw["base_url"] as? String ?? self.gwBaseUrl
                        self.gwKeyAlias = gw["key_alias"] as? String ?? self.gwKeyAlias
                        self.gwSpendFormatted = gw["spend_formatted"] as? String ?? self.gwSpendFormatted
                        self.gwMaxBudgetFormatted = gw["max_budget_formatted"] as? String ?? self.gwMaxBudgetFormatted
                        if let sp = gw["spend_percent"] as? Double {
                            self.gwSpendPercent = sp
                        } else if let sp = gw["spend_percent"] as? Int {
                            self.gwSpendPercent = Double(sp)
                        }
                        self.gwIsActiveNow = gw["is_active_now"] as? Bool ?? false
                        self.gwLastActiveHuman = gw["last_active_human"] as? String ?? self.gwLastActiveHuman
                        self.gwLastActiveTime = gw["last_active_time"] as? String ?? self.gwLastActiveTime
                        
                        if let cmds = gw["quick_commands"] as? [[String: Any]] {
                            var parsedCmds: [GatewayCommandItem] = []
                            for c in cmds {
                                let t = c["title"] as? String ?? ""
                                let d = c["description"] as? String ?? ""
                                let cmd = c["command"] as? String ?? ""
                                parsedCmds.append(GatewayCommandItem(title: t, description: d, command: cmd))
                            }
                            self.gwQuickCommands = parsedCmds
                        }
                    }
                    
                    self.lastQuotaFetchDate = Date()
                    self.updateAgoText()
                    self.onUpdate?()
                }
            }.resume()
        }
        
        self.fetchSystemData()
    }
    
    func fetchSystemData() {
        guard let url = URL(string: "\(self.baseUrl)/v1/system-telemetry") else { return }
        URLSession.shared.dataTask(with: authedRequest(url)) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            DispatchQueue.main.async {
                // 1. Metrics
                if let m = json["metrics"] as? [String: Any] {
                    var h = HostMetricInfo()
                    h.cpuPercent = m["cpu_percent"] as? Double ?? 0.0
                    h.cpuCount = m["cpu_count"] as? Int ?? 0
                    if let la = m["load_avg"] as? [Double] { h.loadAvg = la }
                    h.ramTotalGb = m["ram_total_gb"] as? Double ?? 0.0
                    h.ramUsedGb = m["ram_used_gb"] as? Double ?? 0.0
                    h.ramPercent = m["ram_percent"] as? Double ?? 0.0
                    h.diskTotalGb = m["disk_total_gb"] as? Double ?? 0.0
                    h.diskUsedGb = m["disk_used_gb"] as? Double ?? 0.0
                    h.diskFreeGb = m["disk_free_gb"] as? Double ?? 0.0
                    h.diskPercent = m["disk_percent"] as? Double ?? 0.0
                    h.diskFreePercent = m["disk_free_percent"] as? Double ?? 0.0
                    h.uptime = m["uptime"] as? String ?? "-"
                    self.sysMetrics = h
                }
                
                // 2. Ports
                if let rawPorts = json["ports"] as? [[String: Any]] {
                    var pList: [PortInfo] = []
                    for p in rawPorts {
                        let pt = p["port"] as? Int ?? 0
                        let h = p["host"] as? String ?? ""
                        let pid = p["pid"] as? Int
                        let proc = p["process"] as? String ?? ""
                        let cmd = p["command"] as? String ?? ""
                        let cwd = p["cwd"] as? String ?? ""
                        let u = p["user"] as? String ?? ""
                        let isD = p["is_docker"] as? Bool ?? false
                        let proj = p["project"] as? String ?? ""
                        let isInt = p["is_internal"] as? Bool ?? false
                        pList.append(PortInfo(port: pt, host: h, pid: pid, process: proc, command: cmd, cwd: cwd, user: u, isDocker: isD, project: proj, isInternal: isInt))
                    }
                    self.sysPorts = pList
                }
                
                // 3. Services
                if let rawSvcs = json["services"] as? [[String: Any]] {
                    var sList: [ServiceInfo] = []
                    for s in rawSvcs {
                        let nm = s["name"] as? String ?? ""
                        let un = s["unit"] as? String ?? ""
                        let act = s["active"] as? Bool ?? false
                        let ver = s["version"] as? String ?? ""
                        let pt = s["port"] as? Int
                        let canR = s["can_restart"] as? Bool ?? false
                        let canU = s["can_update"] as? Bool ?? false
                        sList.append(ServiceInfo(name: nm, unit: un, active: act, version: ver, port: pt, canRestart: canR, canUpdate: canU))
                    }
                    self.sysServices = sList
                }
                
                // 4. Docker
                if let rawD = json["docker"] as? [[String: Any]] {
                    var dList: [DockerContainerInfo] = []
                    for d in rawD {
                        let cid = d["id"] as? String ?? ""
                        let nm = d["name"] as? String ?? ""
                        let st = d["status"] as? String ?? ""
                        let img = d["image"] as? String ?? ""
                        let pts = d["ports"] as? String ?? ""
                        dList.append(DockerContainerInfo(id: cid, name: nm, status: st, image: img, ports: pts))
                    }
                    self.sysDocker = dList
                }
                
                // 5. Tunnels
                if let rawT = json["tunnels"] as? [[String: Any]] {
                    var tList: [TunnelInfo] = []
                    for t in rawT {
                        let tid = t["id"] as? String ?? ""
                        let typ = t["type"] as? String ?? ""
                        let tgt = t["target"] as? String ?? ""
                        let u = t["url"] as? String ?? ""
                        let act = t["is_active"] as? Bool ?? false
                        let isQ = t["is_quick"] as? Bool ?? false
                        let pt = t["port"] as? Int
                        let stAt = t["started_at"] as? String
                        tList.append(TunnelInfo(id: tid, type: typ, target: tgt, url: u, isActive: act, isQuick: isQ, port: pt, startedAt: stAt))
                    }
                    self.sysTunnels = tList
                }
                
                self.onUpdate?()
            }
        }.resume()
    }
    
    func killPort(port: Int, pid: Int?) {
        guard let url = URL(string: "\(self.baseUrl)/v1/kill-port") else { return }
        self.sysActionMessage = "Đang dừng port \(port)..."
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(Self.bridgeSecret)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = ["port": port]
        if let p = pid { body["pid"] = p }
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: req) { data, _, _ in
            DispatchQueue.main.async {
                self.sysActionMessage = "Đã tắt tiến trình port \(port)!"
                self.fetchSystemData()
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { self.sysActionMessage = "" }
            }
        }.resume()
    }
    
    func startQuickTunnel(port: Int) {
        guard let url = URL(string: "\(self.baseUrl)/v1/tunnel-start") else { return }
        self.isStartingTunnel = true
        self.sysActionMessage = "Đang tạo Cloudflare Tunnel cho port \(port)..."
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(Self.bridgeSecret)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["port": port]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: req) { data, _, _ in
            DispatchQueue.main.async {
                self.isStartingTunnel = false
                guard let data = data,
                      let res = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let ok = res["ok"] as? Bool, ok else {
                    self.sysActionMessage = "Tạo Tunnel thất bại!"
                    return
                }
                self.sysActionMessage = "Tunnel tạo thành công!"
                self.fetchSystemData()
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { self.sysActionMessage = "" }
            }
        }.resume()
    }
    
    func stopQuickTunnel(tunnelId: String) {
        guard let url = URL(string: "\(self.baseUrl)/v1/tunnel-stop") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(Self.bridgeSecret)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["tunnel_id": tunnelId]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: req) { _, _, _ in
            DispatchQueue.main.async {
                self.sysActionMessage = "Đã đóng tunnel!"
                self.fetchSystemData()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.sysActionMessage = "" }
            }
        }.resume()
    }
    
    func restartManagedService(name: String) {
        guard let url = URL(string: "\(self.baseUrl)/v1/restart-service") else { return }
        self.sysActionMessage = "Đang khởi động lại \(name)..."
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(Self.bridgeSecret)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["service": name]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: req) { _, _, _ in
            DispatchQueue.main.async {
                self.sysActionMessage = "Đã restart \(name)!"
                self.fetchSystemData()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { self.sysActionMessage = "" }
            }
        }.resume()
    }
    
    func updateHerdrCLI() {
        guard let url = URL(string: "\(self.baseUrl)/v1/update-herdr") else { return }
        self.sysActionMessage = "Đang kiểm tra & cập nhật Herdr..."
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(Self.bridgeSecret)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: req) { data, _, _ in
            DispatchQueue.main.async {
                self.sysActionMessage = "Hoàn tất kiểm tra Herdr!"
                self.fetchSystemData()
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { self.sysActionMessage = "" }
            }
        }.resume()
    }
}

let ICON_CLAUDE_B64 = "iVBORw0KGgoAAAANSUhEUgAAACQAAAAkCAYAAADhAJiYAAAAAXNSR0IArs4c6QAAADhlWElmTU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAAqACAAQAAAABAAAAJKADAAQAAAABAAAAJAAAAAAJxsHGAAAD3klEQVRYCe2XW2iPYRzH95+Z04hGQuSUY84XWivEWDnkAheKckHRLpDCxS52JadyulDChuSGlaQcyiE0zFkjIYxtFCbMYcbr8333PNuz17t5/3+a0n71eX/H5/c8e97/+7zvkpJa5H/eAc/zZsEUiP3zv5NFLAYrq8IWRDIL7kJmWP6vxpjkCFgpxUgJTkDshik4FMxF9ZOjFlJ3zqntjT3X8ZNYiG7jCBN75OZkk+8FfYLxhH2apcJ9sFLsNiOYbhPoBYHcfGLV8BmGuLk/smk2FVyZZBsSHOokRjnxmcS/Oblcm4usGdwBiuE1LHUH4h8FK+dtjsBEE/yKbq04ehxUmbhUDYy0YyJrBnXXaEcOYLc3kwzA/uLkskxct0Vy3fjdsJ/5kfrL2siLCBbSY299H9+6w3WQmWyzkysysTUmthudAmeNb1VhcI64fTothPe2I/oDLIAu8AasTMfYbpwc9AabMPohulPcCwgbQKOBcMk0tqoAI9c66DNw0Pi70D+MLaXf1Niw3gnHaJgMK+ETWCm3BlpP0T3Hd80VYRNTEINfDtew2kZjNNBuXYCocovCVtAOMmE57IGr8BEqoOlziQL/kW1sVeS1W6tAh9zv5CYFep2455A75hVOF3euBm9tkpNJnobP8BYqHf0OW1RAOaTDFoj6+qmh9h7oWNApfwFKYrGYh66T4IJSyeyEodAR9GR0MLRFxyP6o3QkaGJxmcmr0E1KgwU1VcnuqbaNg3bzUBNjqslpJ1/BR9BOfIM3htfofBZZhk5cWFhPyIfvIHEf8dpI7VU/6Dw4C+7TiVsnOsv6JbQaBur9pgnsu+kt9jqohMYWtYOcHm99KWTAajgGGit5DmPiXhCDFkEZWNHH2mB4YALbjHbfcSbkH5gNnlwSWuQw0E8gujBAt+cEWHmJMUcd0IUmuA+9xNjL0DqZJafgom953kl0WvSZQyppMBzs1qpvAfhnBlrnkEQ7lAab5CAas963ai9zUPuNfwWtoyIxYfAE0IF2H7JtF+yJoLhuz2jF0XYXu2JrgU9BotusF3GeHKQEetpecWsGt3IH4fcC3TZJjs1h60OuGvxjBD0NrBSoDmc2aMefQA87NmFNEz0pRSA5bBth9/MjnvfCxqSJ7TVxqRkm1hf7PIx3axOyabIVJJfA/3o0k8zzo553zW1MrCM8Dsu5dQnbNNb5cxs6u03wN4LkuBuXTSwDauBxMNeYH8/3iN5vlRz1HwLN7Pa/DMSTqNUt7k88OCZYWudHfVOreWnIYtTI/lP4sK6rY5hx+mpoHmEH2kA2xLPbzbO4llmaYwd+AqWYtWtPxbPfAAAAAElFTkSuQmCC"

let ICON_AGY_B64 = "iVBORw0KGgoAAAANSUhEUgAAACQAAAAkCAYAAADhAJiYAAAAAXNSR0IArs4c6QAAADhlWElmTU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAAqACAAQAAAABAAAAJKADAAQAAAABAAAAJAAAAAAJxsHGAAACaUlEQVRYCe2XwUtVQRTGfSphQmBqIRhtkmgjESL4SjCIQMKIai2Em6BlC2lfEQiiixYtIvoHWuXahS7ColVGkVAthAjUTSqo4Os3oL7HuWdmzni5DwQHPt6dc77vO+fOXObe19BwPI7YCpTy9lupVAbwuAKawBcwXyqVdvmt76CRHvAZyPGdgGuwfoOCl8CK7KRmvs51uS4dUagFfK0p7rtcJtFeeFMUGfd1oMSnCm2Igq1gTSnsC22R6EppqjGFDHcUnE7QnID7MIGfRuVuF3xLEYj/Jpf7eMl0iumFQNFY6mrG0BNI2bJ7Hg9L+L6F5DgpDd22mio8s9a0t+xHG0VWgHs9HHZc5JWyFBNbV+gmRnmacX0Mx5pxeWtDJrNIQZOHdcuWKdYdKRhLb0JoZ9u2QsToCvH89GKQtxnXQysYchehEW0I8YjHwH3zvAXXwRnQCdx58xLsAG34vDSuHmOFPiin3gYx7zNBbgCsKrqfehVjFMNzYFcxvhuzQDMIdhRtX0zrzWP2WDF84xWIBNrnin5C0OxTzBaF4V/m5rc9XPcx90N4/GHebO9ij4nomjBy07FUIzS3FB/zu+2gHibvhdFH5qZz68CkenMzwuuT5ATniPuFwTbzy0FRIIn2PPgnPG0vXERNQP69eRqoZ0rh+Ug09Iu5OyzDA9IzIZxjnv4QKmXweSe8Xyu0agjyAyH4xryjysh3hZf7kyAP2ieqK8QyqD3I3LadVck5gnieArNgf7iDN3vqE5zeYzjCK3AyR92gFO9m8ALsL8BkRkCyDdwBPZlkQQFqdYMboLCbL6j1Y9vqCvwHoDyc53bTRvcAAAAASUVORK5CYII="

// Official DeepSeek Whale Brand Icon from steipete/CodexBar (Template Monochrome PNG)
let ICON_DEEPSEEK_B64 = "iVBORw0KGgoAAAANSUhEUgAAADAAAAAwCAYAAABXAvmHAAAABmJLR0QA/wD/AP+gvaeTAAAEoElEQVRoge2ZfWhWVRzHv8e5Tc23lqyyciILXRkJWuFLf2wVagUVYqJE1CoINYioYIRl2QtBBQVJBEVBhRJlRv3RexQRYYIWZFAxs7ZWviwdNd30+fTHuQ+d3Z1777n3eSYU+8JgnPt7+X7Pc875/c690ihG8d8GMAtoKupvqkmmDGCMpHmSmiT1S/rYGDOQYPu6pH5jzI0jwSUXgOnAw0AP/6IErEqwrwf6gN+AsUVyBjlFM7pEUqukOZKmSjpF0oCkHyV1Slog6RpJtTH3DmPM1oTQF0uaGP2tk/R0Tv6ZxA3QDvxEMRwEalLir3RsjwMPAeMCeN0EbMsymgZ8VJB4Gb9k5LjN4/MNcGaKzzLgGNAtJSwh4CxJn0pqzpqNDJwNXG6M+TDhea9n7AJJr8kuVwHnSlou6TRJLZKuk+XtnxzsxtpV4cy72A8sSci1OMVvHvAodmn58EqSgKeqSL6Mo8ByT64p2OXgw56MmHf4yLdij72RQD/Q6sn5foFYJewyHxLIADurydiDQ8DsWN7rC8QZvqeAq6vLNRHfA1NiE/d5Dv9BYIFPwDsjwTYB27HFsZy7GegO9L3TR74Bq+xk4oEYh7nYJZaEY8DaYeQj59UnhfJQlIBbYjze9NjtBTYDM33cy4VsoTPWK2mnpB5JkyXNlTTLq7wyGEnPA7XGmOcAI2lRzOZZY8z6zEjAZ47iGZ7nM4C7gZ9H6NfYDqzyjG8KmooYsfEpdvXAeqArB7kSsAG4AXgvp7AHQwW41fCcAPupwFuBJPYRdaTYI/PxHAJuDiFfE3OaHyjaAPeS3Ku4+B14IcplgDcCBcT3hJfIWIa2DytDBDj+7WS3H+uwt64rI5/pwJEAAQ1Z+ccYY45LOuyMXZhHgDHmRUl3ZZidIalO0oTIp1tS1gbtMsYcCiIB/OCofjfIaXiMJwJmdIVjPwk4nGKbdA0dgnI5P+CMXQrUFdDQIemrDJul5X+MMX2StqTYfhGcGdgSU98W7Dw0TgvJ/T3ACWAtdiM3Ap+k2J6XJ/F9MefCbweATSmkyviT9NPru7xJL4sFOADUFxQwkfDOMgkb8yYdj70xuVhdREAU79YKyA8SUEx9Sd+OBdqF07PnjFUDfFtQQNDp40u6xhNsTaFgNt4VBcgPAi1FE47DlnwXncCkCkSEtgxlbC6aq5zwfk/Ql1LsG4AvgXuA+DtRAU3AX4Hku3DuykUFTAb+8ARvT7A/3bH5Gv9dYkMA+RKwrCLyTkLfCTIIXJtgv9ux6wEWx57XATsyBDxTFfJRQgN84ElyFM+mxnaaLv4GrorZNAO9KQJup+D3gSQR0/C/Ui8BjwETHNtFHrsBYnUEaIvGk7AX+9q80NHtE3E+yd3iQeBl4MkosQ8nsPdo48RcQXqvBLb+DNtLRUUsZXiFzovdQAf2F5hPWK+U61KVJaKN9L49L45g34c+gq3W7i+yH3gVZ4lWS8RsircGLn4FLorFrgVOpdIaECCiHthIeGGKYyvQOKIkA4U0Yj/GdQaQ7sVelhZmRy6Gwh+6safLHEmXSJopqVH2o3afpH2S9kjaEb00GMX/Fv8AkgohsjDF8bwAAAAASUVORK5CYII="

func loadTemplateIcon(name: String) -> NSImage? {
    if let img = NSImage(contentsOfFile: "/tmp/icon-\(name).png") {
        img.isTemplate = true
        img.size = NSSize(width: 16, height: 16)
        return img
    }
    let b64: String
    if name.contains("deepseek") {
        b64 = ICON_DEEPSEEK_B64
    } else if name.contains("claude") {
        b64 = ICON_CLAUDE_B64
    } else {
        b64 = ICON_AGY_B64
    }
    if let data = Data(base64Encoded: b64), let img = NSImage(data: data) {
        img.isTemplate = true
        img.size = NSSize(width: 16, height: 16)
        return img
    }
    return nil
}

// MARK: - Token Keeper Detail Window View
struct TokenKeeperDetailView: View {
    @ObservedObject var state: QuotaState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 32))
                    .foregroundStyle(Color(red: 52/255, green: 199/255, blue: 89/255))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Token Keeper Proactive")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Hệ thống bảo vệ phiên & tự động refresh token ngầm")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                
                Button(action: {
                    self.state.fetchData()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text("Làm mới")
                    }
                    .font(.caption)
                }
            }
            
            Divider()
            
            // Status Grid
            VStack(alignment: .leading, spacing: 8) {
                Text("Trạng thái vận hành")
                    .font(.headline)
                
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                    GridRow {
                        Text("Dịch vụ:")
                            .foregroundStyle(.secondary)
                        Text("claude-token-keeper.service")
                            .font(.system(.body, design: .monospaced))
                    }
                    GridRow {
                        Text("Trạng thái Timer:")
                            .foregroundStyle(.secondary)
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color(red: 52/255, green: 199/255, blue: 89/255))
                                .frame(width: 8, height: 8)
                            Text(self.state.keeperStatus)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color(red: 52/255, green: 199/255, blue: 89/255))
                        }
                    }
                    GridRow {
                        Text("Chu kỳ làm mới:")
                            .foregroundStyle(.secondary)
                        Text(self.state.keeperSchedule)
                    }
                    GridRow {
                        Text("Lần chạy gần nhất:")
                            .foregroundStyle(.secondary)
                        Text(self.state.lastRefresh)
                            .font(.system(.body, design: .monospaced))
                    }
                    GridRow {
                        Text("Lần chạy tiếp theo:")
                            .foregroundStyle(.secondary)
                        Text(self.state.nextRefresh)
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.semibold)
                    }
                    GridRow {
                        Text("Vault Sao lưu:")
                            .foregroundStyle(.secondary)
                        Text("\(self.state.keeperBackupCount) bản sao lưu an toàn (~/.cliproxy/backups/auth-vault)")
                    }
                }
            }
            
            Divider()
            
            // Logs Section
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Nhật ký hoạt động gần đây (Logs):")
                        .font(.headline)
                    Spacer()
                    Text("Tự động cuộn")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        if self.state.keeperLogs.isEmpty {
                            Text("Đang tải nhật ký...")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(self.state.keeperLogs, id: \.self) { logLine in
                                Text(logLine)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(logLine.contains("successfully") ? Color(red: 52/255, green: 199/255, blue: 89/255) : Color.primary)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color(white: 0.12))
                .cornerRadius(6)
                .frame(height: 160)
            }
            
            Spacer()
            
            HStack {
                Spacer()
                Button("Đóng") {
                    AppDelegate.shared?.keeperWindow?.close()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .frame(width: 520, height: 490)
    }
}

// MARK: - External Gateway & DeepSeek Detail Window View
struct GatewayDetailView: View {
    @ObservedObject var state: QuotaState
    @State private var copiedCommand: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 12) {
                if let dsImg = loadTemplateIcon(name: "deepseek") {
                    Image(nsImage: dsImg)
                        .resizable()
                        .renderingMode(.template)
                        .foregroundStyle(Color.primary)
                        .frame(width: 30, height: 30)
                } else {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.primary)
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(self.state.gwProviderName)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        if self.state.gwIsActiveNow {
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(Color(red: 52/255, green: 199/255, blue: 89/255))
                                    .frame(width: 6, height: 6)
                                Text("Đang sử dụng")
                                    .font(.caption2.bold())
                                    .foregroundStyle(Color(red: 52/255, green: 199/255, blue: 89/255))
                            }
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Color(red: 52/255, green: 199/255, blue: 89/255).opacity(0.12))
                            .cornerRadius(4)
                        }
                    }
                    Text("Giám sát API Usage Spend & Quản lý lệnh chạy mô hình DeepSeek")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                
                Button(action: {
                    self.state.fetchData()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text("Làm mới")
                    }
                    .font(.caption)
                }
            }
            
            Divider()
            
            // Spend Metrics Card
            VStack(alignment: .leading, spacing: 8) {
                Text("Thông số Chi phí & Ngân sách")
                    .font(.headline)
                
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Đã tiêu thụ:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(self.state.gwSpendFormatted)
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.primary)
                    }
                    .frame(minWidth: 110, alignment: .leading)
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Hạn mức tối đa:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(self.state.gwMaxBudgetFormatted)
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundStyle(.primary)
                    }
                    .frame(minWidth: 110, alignment: .leading)
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Hoạt động gần nhất:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 4) {
                            Text(self.state.gwLastActiveHuman)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(self.state.gwIsActiveNow ? Color(red: 52/255, green: 199/255, blue: 89/255) : Color.primary)
                        }
                    }
                    Spacer()
                }
                .padding(10)
                .background(Color(white: 0.14))
                .cornerRadius(6)
                
                // Progress Bar
                VStack(alignment: .leading, spacing: 4) {
                    UsageProgressBar(
                        percent: max(0.5, self.state.gwSpendPercent),
                        tint: Color(red: 90/255, green: 130/255, blue: 255/255)
                    )
                    HStack {
                        Text("Đã dùng \(String(format: "%.3f", self.state.gwSpendPercent))% ngân sách tháng")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("Key Alias: \(self.state.gwKeyAlias) · \(self.state.gwBaseUrl)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            
            Divider()
            
            // Quick Commands Section (1-Click Copy)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Lệnh chạy sẵn (1-Click Sao chép vào Terminal):")
                        .font(.headline)
                    Spacer()
                    if let copied = copiedCommand {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color(red: 52/255, green: 199/255, blue: 89/255))
                            Text("Đã sao chép: \(copied)")
                                .font(.caption2.bold())
                                .foregroundStyle(Color(red: 52/255, green: 199/255, blue: 89/255))
                        }
                    }
                }
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(self.state.gwQuickCommands) { cmdItem in
                            HStack(alignment: .center, spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cmdItem.title)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.primary)
                                    Text(cmdItem.description)
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                    Text(cmdItem.command)
                                        .font(.system(size: 10.5, design: .monospaced))
                                        .foregroundStyle(Color(white: 0.85))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 2)
                                        .background(Color.black.opacity(0.35))
                                        .cornerRadius(3)
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(cmdItem.command, forType: .string)
                                    self.copiedCommand = cmdItem.title
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                        if self.copiedCommand == cmdItem.title {
                                            self.copiedCommand = nil
                                        }
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: self.copiedCommand == cmdItem.title ? "checkmark" : "doc.on.doc")
                                        Text(self.copiedCommand == cmdItem.title ? "Đã chép" : "Sao chép")
                                    }
                                    .font(.system(size: 11, weight: .medium))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(self.copiedCommand == cmdItem.title ? Color(red: 52/255, green: 199/255, blue: 89/255) : Color.accentColor)
                            }
                            .padding(8)
                            .background(Color(white: 0.12))
                            .cornerRadius(6)
                        }
                    }
                    .padding(2)
                }
                .frame(height: 190)
            }
            
            Spacer()
            
            HStack {
                Spacer()
                Button("Đóng") {
                    AppDelegate.shared?.gatewayWindow?.close()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .frame(width: 580, height: 530)
    }
}

// MARK: - Ubuntu Host & Dev Hub Window View
struct SystemManagerView: View {
    @ObservedObject var state: QuotaState
    @State private var selectedTab: Int = 0
    @State private var newTunnelPortText: String = ""
    @State private var portSearchText: String = ""
    @State private var portFilterUserOnly: Bool = true
    
    var filteredPorts: [PortInfo] {
        var list = state.sysPorts
        if portFilterUserOnly {
            // Focus on common dev ports or user processes
            list = list.filter { p in
                return p.port >= 3000 && p.port != 41641
            }
        }
        if !portSearchText.isEmpty {
            let q = portSearchText.lowercased()
            list = list.filter {
                String($0.port).contains(q) ||
                $0.process.lowercased().contains(q) ||
                $0.command.lowercased().contains(q) ||
                $0.cwd.lowercased().contains(q)
            }
        }
        return list
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "server.rack")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.accentColor)
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text("Ubuntu Server Manager & Dev Hub")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(state.bridgeHost)
                            .font(.system(size: 10, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(4)
                    }
                    Text("Giám sát CPU/RAM/Ổ cứng · Tắt port bị chiếm · Quản lý Services & Cloudflare Tunnel")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    state.fetchSystemData()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text("Làm mới")
                    }
                    .font(.caption)
                }
            }
            
            // Action Feedback Notification Banner
            if !state.sysActionMessage.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.accentColor)
                    Text(state.sysActionMessage)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.primary)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.accentColor.opacity(0.14))
                .cornerRadius(6)
            }
            
            // Tab Picker
            Picker("", selection: $selectedTab) {
                Text("Cổng mạng (Ports & Kill)").tag(0)
                Text("Tài nguyên (CPU / RAM / Disk)").tag(1)
                Text("Tunnels (Cloudflared)").tag(2)
                Text("Dịch vụ (Herdr & CLIProxy)").tag(3)
            }
            .pickerStyle(.segmented)
            
            Divider()
            
            // TAB 0: Listening Ports & Kill Actions
            if selectedTab == 0 {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Tìm theo port (vd: 8000, 30071), tên tiến trình, thư mục...", text: $portSearchText)
                            .textFieldStyle(.roundedBorder)
                        
                        Toggle("Chỉ hiện Port Dev (≥3000)", isOn: $portFilterUserOnly)
                            .font(.caption)
                    }
                    
                    Text("Nhấn 'Dừng Port' để giải phóng ngay lập tức cổng mạng bị chiếm dụng:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    ScrollView {
                        VStack(spacing: 6) {
                            if filteredPorts.isEmpty {
                                Text("Không tìm thấy port nào phù hợp.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .padding(20)
                            } else {
                                ForEach(filteredPorts) { p in
                                    HStack(alignment: .center, spacing: 12) {
                                        // Port Badge
                                        Text(":\(p.displayPort)")
                                            .font(.system(size: 13.5, weight: .bold, design: .monospaced))
                                            .foregroundStyle(Color.accentColor)
                                            .frame(width: 68, alignment: .leading)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack(spacing: 6) {
                                                Text(p.process)
                                                    .font(.system(size: 12.5, weight: .semibold))
                                                Text("(\(p.host))")
                                                    .font(.system(size: 10))
                                                    .foregroundStyle(.tertiary)
                                            }
                                            
                                            // Clear path/workspace display
                                            Text(!p.project.isEmpty ? p.project : (!p.cwd.isEmpty ? p.cwd : p.command))
                                                .font(.system(size: 10, design: .monospaced))
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                        }
                                        
                                        Spacer()
                                        
                                        // Tunnel button for this port
                                        Button(action: {
                                            state.startQuickTunnel(port: p.port)
                                        }) {
                                            HStack(spacing: 3) {
                                                Image(systemName: "link.badge.plus")
                                                Text("Bật Tunnel")
                                            }
                                            .font(.system(size: 10.5))
                                        }
                                        .buttonStyle(.bordered)
                                        
                                        // Kill button
                                        Button(action: {
                                            state.killPort(port: p.port, pid: p.pid)
                                        }) {
                                            HStack(spacing: 3) {
                                                Image(systemName: "xmark.circle.fill")
                                                Text("Dừng Port")
                                            }
                                            .font(.system(size: 10.5, weight: .semibold))
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(Color.red.opacity(0.85))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color(white: 0.12))
                                    .cornerRadius(6)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .frame(height: 310)
                }
            }
            
            // TAB 1: System Hardware Metrics (CPU, RAM, Disk)
            else if selectedTab == 1 {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 16) {
                        // CPU Card
                        VStack(alignment: .leading, spacing: 6) {
                            Text("CPU (\(state.sysMetrics.cpuCount) Cores)")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Text("\(String(format: "%.1f", state.sysMetrics.cpuPercent))%")
                                .font(.system(size: 24, weight: .bold, design: .monospaced))
                                .foregroundStyle(state.sysMetrics.cpuPercent > 80 ? Color.red : Color.primary)
                            UsageProgressBar(percent: state.sysMetrics.cpuPercent, tint: Color.accentColor)
                            Text("Load: \(state.sysMetrics.loadAvg.map { String(format: "%.2f", $0) }.joined(separator: " "))")
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background(Color(white: 0.13))
                        .cornerRadius(8)
                        
                        // RAM Card
                        VStack(alignment: .leading, spacing: 6) {
                            Text("BỘ NHỚ RAM")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Text("\(String(format: "%.1f", state.sysMetrics.ramPercent))%")
                                .font(.system(size: 24, weight: .bold, design: .monospaced))
                                .foregroundStyle(state.sysMetrics.ramPercent > 85 ? Color.orange : Color.primary)
                            UsageProgressBar(percent: state.sysMetrics.ramPercent, tint: Color(red: 52/255, green: 199/255, blue: 89/255))
                            Text("\(String(format: "%.1f", state.sysMetrics.ramUsedGb)) GB / \(String(format: "%.1f", state.sysMetrics.ramTotalGb)) GB")
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background(Color(white: 0.13))
                        .cornerRadius(8)
                        
                        // Disk Card (btop 1:1 format)
                        let dUsedPct = state.sysMetrics.diskPercent
                        let dFreePct = state.sysMetrics.diskFreePercent
                        let isUsed = state.quotaDisplayMode == "used"
                        VStack(alignment: .leading, spacing: 6) {
                            Text(isUsed ? "Ổ CỨNG (/) · ĐÃ DÙNG" : "Ổ CỨNG (/) · CÒN TRỐNG")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Text("\(String(format: "%.1f", isUsed ? dUsedPct : dFreePct))%")
                                .font(.system(size: 24, weight: .bold, design: .monospaced))
                                .foregroundStyle(dUsedPct > 90 ? Color.red : Color.primary)
                            UsageProgressBar(percent: isUsed ? dUsedPct : dFreePct, tint: Color.purple)
                            Text("Trống: \(String(format: "%.0f", state.sysMetrics.diskFreeGb)) GiB · \(String(format: "%.0f", state.sysMetrics.diskUsedGb)) / \(String(format: "%.0f", state.sysMetrics.diskTotalGb)) GiB")
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background(Color(white: 0.13))
                        .cornerRadius(8)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Thông tin hệ thống host:")
                            .font(.headline)
                        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                            GridRow {
                                Text("Thời gian hoạt động (Uptime):").foregroundStyle(.secondary)
                                Text(state.sysMetrics.uptime).font(.system(.body, design: .monospaced))
                            }
                            GridRow {
                                Text("Địa chỉ IP máy chủ:").foregroundStyle(.secondary)
                                Text("100.127.1.234 (Tailscale)").font(.system(.body, design: .monospaced))
                            }
                            GridRow {
                                Text("Tổng số cổng TCP đang mở:").foregroundStyle(.secondary)
                                Text("\(state.sysPorts.count) cổng mạng đang lắng nghe").font(.system(.body, design: .monospaced))
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(white: 0.12))
                    .cornerRadius(8)
                    
                    Spacer()
                }
                .frame(height: 330)
            }
            
            // TAB 2: Cloudflare Tunnels (Active & Quick on-demand)
            else if selectedTab == 2 {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Text("Tạo Tunnel Public mới qua Cloudflared:")
                            .font(.subheadline.bold())
                        Spacer()
                    }
                    
                    HStack(spacing: 10) {
                        TextField("Nhập Port cần Public (vd: 8000 hoặc 30071)", text: $newTunnelPortText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 280)
                        
                        Button(action: {
                            if let p = Int(newTunnelPortText.trimmingCharacters(in: .whitespaces)) {
                                state.startQuickTunnel(port: p)
                                newTunnelPortText = ""
                            }
                        }) {
                            HStack(spacing: 4) {
                                if state.isStartingTunnel {
                                    ProgressView().scaleEffect(0.6).frame(width: 14, height: 14)
                                } else {
                                    Image(systemName: "bolt.fill")
                                }
                                Text("Bật Tunnel Ngay")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(newTunnelPortText.isEmpty || state.isStartingTunnel)
                    }
                    
                    Divider().padding(.vertical, 4)
                    
                    Text("Danh sách Tunnel đang hoạt động:")
                        .font(.headline)
                    
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(state.sysTunnels, id: \.id) { tun in
                                HStack(alignment: .center, spacing: 10) {
                                    Circle()
                                        .fill(Color(red: 52/255, green: 199/255, blue: 89/255))
                                        .frame(width: 8, height: 8)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Text(tun.type)
                                                .font(.system(size: 12, weight: .semibold))
                                            Text("→ \(tun.target)")
                                                .font(.system(size: 11, design: .monospaced))
                                                .foregroundStyle(.secondary)
                                        }
                                        Text(tun.url)
                                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                                            .foregroundStyle(Color.accentColor)
                                    }
                                    
                                    Spacer()
                                    
                                    if tun.url.hasPrefix("http") {
                                        Button(action: {
                                            if let u = URL(string: tun.url) { NSWorkspace.shared.open(u) }
                                        }) {
                                            Text("Mở Web")
                                                .font(.system(size: 11))
                                        }
                                        
                                        Button(action: {
                                            NSPasteboard.general.clearContents()
                                            NSPasteboard.general.setString(tun.url, forType: .string)
                                            state.sysActionMessage = "Đã sao chép link Tunnel!"
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { state.sysActionMessage = "" }
                                        }) {
                                            Image(systemName: "doc.on.doc")
                                                .font(.system(size: 11))
                                        }
                                    }
                                    
                                    if tun.isQuick {
                                        Button(action: {
                                            state.stopQuickTunnel(tunnelId: tun.id)
                                        }) {
                                            Text("Tắt Tunnel")
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundStyle(Color.red)
                                        }
                                    }
                                }
                                .padding(10)
                                .background(Color(white: 0.12))
                                .cornerRadius(6)
                            }
                        }
                    }
                    .frame(height: 250)
                }
            }
            
            // TAB 3: Managed Services (Herdr & CLIProxy)
            else if selectedTab == 3 {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quản lý và cập nhật các dịch vụ nền tảng:")
                        .font(.headline)
                    
                    VStack(spacing: 10) {
                        ForEach(state.sysServices) { svc in
                            HStack(alignment: .center, spacing: 12) {
                                Circle()
                                    .fill(svc.active ? Color(red: 52/255, green: 199/255, blue: 89/255) : Color.red)
                                    .frame(width: 10, height: 10)
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 8) {
                                        Text(svc.name)
                                            .font(.system(size: 13, weight: .bold))
                                        Text("v\(svc.version)")
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                        if let pt = svc.port {
                                            Text("Port: :\(pt)")
                                                .font(.system(size: 10, design: .monospaced))
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 1)
                                                .background(Color.white.opacity(0.08))
                                                .cornerRadius(3)
                                        }
                                    }
                                    Text(svc.unit)
                                        .font(.system(size: 10.5, design: .monospaced))
                                        .foregroundStyle(.tertiary)
                                }
                                
                                Spacer()
                                
                                if svc.canRestart {
                                    Button(action: {
                                        state.restartManagedService(name: svc.unit)
                                    }) {
                                        HStack(spacing: 3) {
                                            Image(systemName: "arrow.clockwise")
                                            Text("Khởi động lại")
                                        }
                                        .font(.system(size: 11))
                                    }
                                }
                                
                                if svc.canUpdate {
                                    Button(action: {
                                        state.updateHerdrCLI()
                                    }) {
                                        HStack(spacing: 3) {
                                            Image(systemName: "arrow.triangle.2.circlepath")
                                            Text("Cập nhật (herdr update)")
                                        }
                                        .font(.system(size: 11, weight: .semibold))
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                            }
                            .padding(12)
                            .background(Color(white: 0.12))
                            .cornerRadius(8)
                        }
                    }
                    
                    Spacer()
                }
                .frame(height: 330)
            }
            

            
            Spacer()
            
            HStack {
                Spacer()
                Button("Đóng") {
                    AppDelegate.shared?.systemManagerWindow?.close()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 680, idealWidth: 700, minHeight: 560, idealHeight: 580)
    }
}

// MARK: - Dedicated Ubuntu Server Quick Menu View (Exact 1:1 CodexBar Pattern)
struct UbuntuServerQuickMenuView: View {
    @ObservedObject var state: QuotaState
    @State private var searchText: String = ""
    
    var activeDevPorts: [PortInfo] {
        // Priority to actual user dev servers (non-internal, dev ports)
        let primary = state.sysPorts.filter { !$0.isInternal && $0.port != 8317 && $0.port != 8318 }
        let base = !primary.isEmpty ? primary : state.sysPorts.filter { !$0.isInternal }
        
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if q.isEmpty {
            return base
        }
        return base.filter { p in
            String(p.port).contains(q) ||
            p.process.lowercased().contains(q) ||
            p.project.lowercased().contains(q) ||
            p.cwd.lowercased().contains(q)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            // 1. Header (Ubuntu Host Identity & Status)
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Ubuntu Host")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                    Text("100.127.1.234")
                        .font(.subheadline.monospaced())
                        .foregroundStyle(.secondary)
                }
                HStack(alignment: .firstTextBaseline) {
                    Text("Uptime: \(self.state.sysMetrics.uptime)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(red: 52/255, green: 199/255, blue: 89/255))
                            .frame(width: 6, height: 6)
                        Text("Online")
                            .font(.subheadline)
                            .foregroundStyle(Color(red: 52/255, green: 199/255, blue: 89/255))
                    }
                }
            }
            
            Divider()
            
            // 2. Hardware Resource Metrics (Exact CodexBar MetricRow pattern with progress bar)
            VStack(alignment: .leading, spacing: 10) {
                let cpuVal = self.state.sysMetrics.cpuPercent
                let cpuStr = cpuVal < 10.0 ? String(format: "%.1f", cpuVal) : "\(Int(cpuVal))"
                MetricRow(
                    title: "CPU: \(cpuStr)% · \(self.state.sysMetrics.cpuCount) Cores",
                    percent: self.state.sysMetrics.cpuPercent,
                    resetText: "Load: \(self.state.sysMetrics.loadAvg.map { String(format: "%.2f", $0) }.joined(separator: " "))",
                    tint: self.state.sysMetrics.cpuPercent > 80 ? Color.red : Color(red: 52/255, green: 199/255, blue: 89/255)
                )
                
                MetricRow(
                    title: "RAM: \(Int(self.state.sysMetrics.ramPercent))% đã dùng",
                    percent: self.state.sysMetrics.ramPercent,
                    resetText: "\(String(format: "%.1f", self.state.sysMetrics.ramUsedGb)) / \(String(format: "%.1f", self.state.sysMetrics.ramTotalGb)) GB",
                    tint: self.state.sysMetrics.ramPercent > 85 ? Color.orange : Color(red: 0/255, green: 195/255, blue: 137/255)
                )
                
                let dUsedPct = Int(self.state.sysMetrics.diskPercent)
                let dFreePct = Int(self.state.sysMetrics.diskFreePercent)
                let isUsedMode = self.state.quotaDisplayMode == "used"
                let dTitle = isUsedMode ? "Ổ cứng (/): \(dUsedPct)% đã dùng" : "Ổ cứng (/): \(dFreePct)% còn trống"
                let dSub = "Trống \(String(format: "%.0f", self.state.sysMetrics.diskFreeGb)) GiB · \(String(format: "%.0f", self.state.sysMetrics.diskUsedGb)) / \(String(format: "%.0f", self.state.sysMetrics.diskTotalGb)) GiB"
                
                MetricRow(
                    title: dTitle,
                    percent: isUsedMode ? self.state.sysMetrics.diskPercent : self.state.sysMetrics.diskFreePercent,
                    resetText: dSub,
                    tint: Color(red: 175/255, green: 82/255, blue: 222/255)
                )
            }
            
            Divider()
            
            // 3. Quick Dev Ports & Search (Minimalist Apple Design)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center) {
                    Text("Cổng Dev Đang Mở")
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(self.activeDevPorts.count) cổng")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                
                // Minimalist Apple-Design Search Bar
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
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.primary.opacity(0.035))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                )
                
                if self.activeDevPorts.isEmpty {
                    Text(searchText.isEmpty ? "Không có tiến trình dev nào đang chiếm cổng." : "Không tìm thấy port nào khớp với từ khóa.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 6)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(self.activeDevPorts.prefix(8).enumerated()), id: \.element.id) { idx, p in
                            if idx > 0 {
                                Divider()
                                    .opacity(0.2)
                                    .padding(.vertical, 2)
                            }
                            
                            HStack(alignment: .center, spacing: 8) {
                                Text(":\(p.displayPort)")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Color.accentColor)
                                    .frame(width: 58, alignment: .leading)
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(p.process)
                                        .font(.system(size: 11.5, weight: .medium))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    
                                    Text(!p.project.isEmpty ? p.project : (!p.cwd.isEmpty ? p.cwd : "-"))
                                        .font(.system(size: 9.5, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                
                                Spacer(minLength: 6)
                                
                                Button(action: {
                                    self.state.killPort(port: p.port, pid: p.pid)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 12.5))
                                        .foregroundStyle(Color.red.opacity(0.8))
                                }
                                .buttonStyle(.plain)
                                .help("Dừng tiến trình trên cổng :\(p.displayPort)")
                            }
                            .padding(.vertical, 3)
                            .padding(.horizontal, 4)
                            .contentShape(Rectangle())
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 6)
        .frame(width: 365, alignment: .topLeading)
    }
}


class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    static var shared: AppDelegate?
    
    var claudeItem: NSStatusItem!
    var agyItem: NSStatusItem!
    var ubuntuItem: NSStatusItem!
    
    let state = QuotaState()
    var timer: Timer?
    var telemetryTimer: Timer?
    var settingsWindow: NSWindow?
    var keeperWindow: NSWindow?
    var gatewayWindow: NSWindow?
    var systemManagerWindow: NSWindow?
    
    func menuWillOpen(_ menu: NSMenu) {
        state.updateAgoText()
        self.adjustMenuHostingHeights()
        // Always refresh host telemetry immediately on click for true real-time responsiveness
        state.fetchSystemData()
        if state.refreshOnOpen {
            state.fetchData()
        }
    }
    
    var claudeHostingView: NSView?
    var agyHostingView: NSView?
    var ubuntuHostingView: NSView?
    
    func adjustMenuHostingHeights() {
        if let ch = claudeHostingView {
            let h = ch.fittingSize.height
            if h > 50 {
                ch.frame = NSRect(x: 0, y: 0, width: 365, height: h)
            }
        }
        if let ah = agyHostingView {
            let h = ah.fittingSize.height
            if h > 50 {
                ah.frame = NSRect(x: 0, y: 0, width: 365, height: h)
            }
        }
        if let uh = ubuntuHostingView {
            let h = uh.fittingSize.height
            if h > 50 {
                uh.frame = NSRect(x: 0, y: 0, width: 365, height: h)
            }
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        
        // 1. Antigravity Item & Native NSMenu
        agyItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let btn = agyItem.button {
            if let ic = loadTemplateIcon(name: "antigravity") {
                btn.image = ic
                btn.imagePosition = .imageLeading
            }
            let isUsed = state.quotaDisplayMode == "used"
            let gem5h = isUsed ? (100 - state.agyGemini5hRemaining) : state.agyGemini5hRemaining
            let gemWk = isUsed ? (100 - state.agyGeminiWeeklyRemaining) : state.agyGeminiWeeklyRemaining
            let cg5h = isUsed ? (100 - state.agyClaudeGpt5hRemaining) : state.agyClaudeGpt5hRemaining
            let cgWk = isUsed ? (100 - state.agyClaudeGptWeeklyRemaining) : state.agyClaudeGptWeeklyRemaining
            let disp5h = gem5h
            let dispWk = gemWk
            btn.title = " 5h \(disp5h)% · W \(dispWk)%"
            btn.toolTip = "Antigravity Quota (\(isUsed ? "Đã dùng" : "Còn lại")):\n• Gemini: 5h \(gem5h)% · Tuần \(gemWk)%\n• Claude/GPT: 5h \(cg5h)% · Tuần \(cgWk)%"
        }
        let agyMenu = NSMenu()
        let agyMenuItem = NSMenuItem()
        let agyHosting = MenuHostingView(rootView: AntigravityFullCardView(state: state))
        self.agyHostingView = agyHosting
        let agyHeight = agyHosting.fittingSize.height
        let finalAgyH = (agyHeight > 100 && agyHeight < 900) ? agyHeight : 430
        agyHosting.frame = NSRect(x: 0, y: 0, width: 365, height: finalAgyH)
        agyMenuItem.view = agyHosting
        agyMenu.addItem(agyMenuItem)
        agyMenu.addItem(NSMenuItem.separator())
        
        let agyRefreshItem = NSMenuItem(title: "Làm mới", action: #selector(self.refreshClicked), keyEquivalent: "r")
        if let img = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: nil) {
            agyRefreshItem.image = img
        }
        agyMenu.addItem(agyRefreshItem)
        
        let agySettings = NSMenuItem(title: "Cài đặt", action: #selector(self.settingsClicked), keyEquivalent: ",")
        if let img = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil) {
            agySettings.image = img
        }
        agyMenu.addItem(agySettings)
        
        let agyQuitItem = NSMenuItem(title: "Thoát", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        if let img = NSImage(systemSymbolName: "xmark.square", accessibilityDescription: nil) {
            agyQuitItem.image = img
        }
        agyMenu.addItem(agyQuitItem)
        agyMenu.delegate = self
        agyItem.menu = agyMenu
        
        // 2. Claude Item & Native NSMenu
        claudeItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let btn = claudeItem.button {
            if let ic = loadTemplateIcon(name: "claude") {
                btn.image = ic
                btn.imagePosition = .imageLeading
            }
            let isUsed = state.quotaDisplayMode == "used"
            let c5h = isUsed ? state.claude5h : max(0, 100 - state.claude5h)
            let c7d = isUsed ? state.claude7d : max(0, 100 - state.claude7d)
            btn.title = " 5h \(c5h)% · W \(c7d)%"
            btn.toolTip = "Claude Quota (5h: \(c5h)% · W: \(c7d)%)"
        }
        let claudeMenu = NSMenu()
        let claudeMenuItem = NSMenuItem()
        let claudeHosting = MenuHostingView(rootView: ClaudeFullCardView(state: state))
        self.claudeHostingView = claudeHosting
        let claudeHeight = claudeHosting.fittingSize.height
        let finalClaudeH = (claudeHeight > 100 && claudeHeight < 900) ? claudeHeight : 490
        claudeHosting.frame = NSRect(x: 0, y: 0, width: 365, height: finalClaudeH)
        claudeMenuItem.view = claudeHosting
        claudeMenu.addItem(claudeMenuItem)
        claudeMenu.addItem(NSMenuItem.separator())
        
        let refreshItem = NSMenuItem(title: "Làm mới", action: #selector(self.refreshClicked), keyEquivalent: "r")
        if let img = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: nil) {
            refreshItem.image = img
        }
        claudeMenu.addItem(refreshItem)
        
        let settingsItem = NSMenuItem(title: "Cài đặt", action: #selector(self.settingsClicked), keyEquivalent: ",")
        if let img = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil) {
            settingsItem.image = img
        }
        claudeMenu.addItem(settingsItem)
        
        let quitItem = NSMenuItem(title: "Thoát", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        if let img = NSImage(systemSymbolName: "xmark.square", accessibilityDescription: nil) {
            quitItem.image = img
        }
        claudeMenu.addItem(quitItem)
        claudeMenu.delegate = self
        claudeItem.menu = claudeMenu
        
        // 3. Ubuntu Server Hub Item & Native NSMenu (Dedicated MenuBar Module)
        ubuntuItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let btn = ubuntuItem.button {
            if let img = NSImage(systemSymbolName: "cpu", accessibilityDescription: nil) {
                img.isTemplate = true
                btn.image = img
                btn.imagePosition = .imageLeading
            }
            let diskFreeInt = Int(state.sysMetrics.diskFreePercent)
            btn.title = " C \(Int(state.sysMetrics.cpuPercent))% · M \(Int(state.sysMetrics.ramPercent))% · D \(diskFreeInt)%"
        }
        let ubuntuMenu = NSMenu()
        let ubuntuMenuItem = NSMenuItem()
        let ubuntuHosting = MenuHostingView(rootView: UbuntuServerQuickMenuView(state: state))
        self.ubuntuHostingView = ubuntuHosting
        let ubuntuHeight = ubuntuHosting.fittingSize.height
        let finalUbuntuH = (ubuntuHeight > 100 && ubuntuHeight < 900) ? ubuntuHeight : 490
        ubuntuHosting.frame = NSRect(x: 0, y: 0, width: 365, height: finalUbuntuH)
        ubuntuMenuItem.view = ubuntuHosting
        ubuntuMenu.addItem(ubuntuMenuItem)
        ubuntuMenu.addItem(NSMenuItem.separator())
        
        let openHubWindowItem = NSMenuItem(title: "Mở Hub Quản lý Toàn diện", action: #selector(self.openHubWindowClicked), keyEquivalent: "u")
        if let img = NSImage(systemSymbolName: "macwindow.on.rectangle", accessibilityDescription: nil) {
            openHubWindowItem.image = img
        }
        ubuntuMenu.addItem(openHubWindowItem)
        
        let ubuntuRefreshItem = NSMenuItem(title: "Làm mới", action: #selector(self.refreshClicked), keyEquivalent: "r")
        if let img = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: nil) {
            ubuntuRefreshItem.image = img
        }
        ubuntuMenu.addItem(ubuntuRefreshItem)
        
        let ubuntuQuitItem = NSMenuItem(title: "Thoát", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        if let img = NSImage(systemSymbolName: "xmark.square", accessibilityDescription: nil) {
            ubuntuQuitItem.image = img
        }
        ubuntuMenu.addItem(ubuntuQuitItem)
        ubuntuMenu.delegate = self
        ubuntuItem.menu = ubuntuMenu
        
        state.onUpdate = { [weak self] in
            guard let self = self else { return }
            if let btn = self.claudeItem.button {
                if btn.image == nil {
                    btn.image = loadTemplateIcon(name: "claude")
                    btn.imagePosition = .imageLeading
                }
                let isUsed = self.state.quotaDisplayMode == "used"
                let c5h = isUsed ? self.state.claude5h : max(0, 100 - self.state.claude5h)
                let c7d = isUsed ? self.state.claude7d : max(0, 100 - self.state.claude7d)
                btn.title = " 5h \(c5h)% · W \(c7d)%"
                btn.toolTip = "Claude Quota (5h: \(c5h)% · W: \(c7d)%)"
            }
            if let agyBtn = self.agyItem.button {
                if agyBtn.image == nil {
                    agyBtn.image = loadTemplateIcon(name: "antigravity")
                    agyBtn.imagePosition = .imageLeading
                }
                let isUsed = self.state.quotaDisplayMode == "used"
                let gem5h = isUsed ? (100 - self.state.agyGemini5hRemaining) : self.state.agyGemini5hRemaining
                let gemWk = isUsed ? (100 - self.state.agyGeminiWeeklyRemaining) : self.state.agyGeminiWeeklyRemaining
                let cg5h = isUsed ? (100 - self.state.agyClaudeGpt5hRemaining) : self.state.agyClaudeGpt5hRemaining
                let cgWk = isUsed ? (100 - self.state.agyClaudeGptWeeklyRemaining) : self.state.agyClaudeGptWeeklyRemaining
                let disp5h = gem5h
                let dispWk = gemWk
                agyBtn.title = " 5h \(disp5h)% · W \(dispWk)%"
                agyBtn.toolTip = "Antigravity Quota (\(isUsed ? "Đã dùng" : "Còn lại")):\n• Gemini: 5h \(gem5h)% · Tuần \(gemWk)%\n• Claude/GPT: 5h \(cg5h)% · Tuần \(cgWk)%"
            }
            if let uBtn = self.ubuntuItem.button {
                if uBtn.image == nil {
                    if let img = NSImage(systemSymbolName: "cpu", accessibilityDescription: nil) {
                        img.isTemplate = true
                        uBtn.image = img
                        uBtn.imagePosition = .imageLeading
                    }
                }
                let diskFreeInt = Int(self.state.sysMetrics.diskFreePercent)
                uBtn.title = " C \(Int(self.state.sysMetrics.cpuPercent))% · M \(Int(self.state.sysMetrics.ramPercent))% · D \(diskFreeInt)%"
                uBtn.toolTip = "Ubuntu Server Hub"
            }
            self.adjustMenuHostingHeights()
        }
        
        state.fetchData()
        updateTimer()
    }
    
    @objc func openHubWindowClicked() {
        openSystemManagerWindow()
    }
    
    func updateTimer() {
        // 1. Quota timer
        timer?.invalidate()
        let interval = Double(state.refreshInterval)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.state.fetchData()
        }
        
        // 2. Continuous Telemetry Timer (for Menubar C % · M % · P real-time updates)
        telemetryTimer?.invalidate()
        let tInterval = max(0.1, min(86400.0, state.telemetryIntervalMs / 1000.0))
        telemetryTimer = Timer.scheduledTimer(withTimeInterval: tInterval, repeats: true) { [weak self] _ in
            self?.state.fetchSystemData()
        }
    }
    
    @objc func refreshClicked() { state.fetchData() }
    
    @objc func settingsClicked() {
        openSettingsWindow()
    }
    
    func showBackupError(_ message: String) {
        let err = NSAlert()
        err.messageText = "Không đổi được dự phòng"
        err.informativeText = message
        err.alertStyle = .critical
        NSApp.activate(ignoringOtherApps: true)
        err.runModal()
    }

    func confirmBackupToggle(enable: Bool) {
        if !enable {
            state.setBackup(enabled: false, model: nil, onError: showBackupError)
            return
        }
        let label = state.backup?.selected?.label ?? "model dự phòng"
        let alert = NSAlert()
        alert.messageText = "Bật dự phòng Aperture?"
        alert.informativeText = "Khi mọi account Claude và capi đều hết quota, request Claude sẽ tự chuyển sang \(label).\n\nLưu ý: mọi ứng dụng dùng chung proxy này (kể cả production) cũng sẽ nhận câu trả lời từ model dự phòng thay vì lỗi 429. Chất lượng có thể thấp hơn Claude."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Bật dự phòng")
        alert.addButton(withTitle: "Hủy bỏ")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        state.setBackup(enabled: true, model: nil, onError: showBackupError)
    }

    func confirmToggleEnabled(email: String, enable: Bool) {
        let alert = NSAlert()
        alert.messageText = enable ? "Bật lại account?" : "Tắt account?"
        alert.informativeText = enable
            ? "\(email)\n\nCLIProxy sẽ dùng lại account này theo thứ tự ưu tiên."
            : "\(email)\n\nCLIProxy sẽ không dùng account này cho tới khi bật lại."
        alert.alertStyle = enable ? .informational : .warning
        alert.addButton(withTitle: enable ? "Bật" : "Tắt")
        alert.addButton(withTitle: "Hủy bỏ")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        state.setEnabled(email: email, enabled: enable) { message in
            let err = NSAlert()
            err.messageText = enable ? "Không bật được account" : "Không tắt được account"
            err.informativeText = message
            err.alertStyle = .critical
            NSApp.activate(ignoringOtherApps: true)
            err.runModal()
        }
    }

    func confirmSwitch(to email: String) {
        if state.routeRows.first?.id == email { return }
        if state.routeRows.first(where: { $0.id == email })?.isDisabled == true {
            let alert = NSAlert()
            alert.messageText = "Account đang tắt"
            alert.informativeText = "\(email)\n\nBật account trước rồi mới đặt làm #1."
            alert.alertStyle = .informational
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
            return
        }
        let alert = NSAlert()
        alert.messageText = "Xác nhận chuyển đổi tài khoản đang dùng"
        alert.informativeText = "Bạn có chắc chắn muốn chuyển tài khoản ưu tiên số 1 sang:\n\n\(email)\n\nThao tác này sẽ thiết lập tài khoản này lên đầu chuỗi điều phối (selector drain order) của CLIProxy."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Chuyển tài khoản")
        alert.addButton(withTitle: "Hủy bỏ")
        
        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            state.switchPriority(to: email)
        }
    }

    func openKeeperWindow() {
        if let win = keeperWindow {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let hosting = NSHostingView(rootView: TokenKeeperDetailView(state: state))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 490),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Token Keeper Proactive - Chi tiết & Nhật ký"
        window.contentView = hosting
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.keeperWindow = window
    }

    func openGatewayWindow() {
        if let win = gatewayWindow {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let hosting = NSHostingView(rootView: GatewayDetailView(state: state))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 530),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "External Gateway & DeepSeek - Chi phí & Lệnh chạy"
        window.contentView = hosting
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.gatewayWindow = window
    }

    func openSystemManagerWindow() {
        if let win = systemManagerWindow {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let hosting = NSHostingView(rootView: SystemManagerView(state: state))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 580),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.minSize = NSSize(width: 660, height: 540)
        window.center()
        window.title = "Ubuntu Server Hub & Ports Manager"
        window.contentView = hosting
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.systemManagerWindow = window
    }

    func openSettingsWindow() {
        if let win = settingsWindow {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let hosting = NSHostingView(rootView: SettingsView(state: state, onSave: { [weak self] in
            self?.state.saveInterval()
        }))
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.minSize = NSSize(width: 480, height: 480)
        window.center()
        window.title = "Cài đặt Orbiter Menubar"
        window.contentView = hosting
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.settingsWindow = window
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
