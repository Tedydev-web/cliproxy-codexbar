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
        return "Đặt lại: " + cleaned
    }
    
    let target = Date().addingTimeInterval(totalSeconds)
    let calendar = Calendar.current
    let timeFormatter = DateFormatter()
    timeFormatter.dateFormat = "HH:mm:ss"
    let timeStr = timeFormatter.string(from: target)
    
    if totalSeconds < 86400 && calendar.isDateInToday(target) {
        return "Đặt lại sau " + cleaned + " · " + timeStr
    } else if calendar.isDateInTomorrow(target) {
        return "Đặt lại sau " + cleaned + " · Mai " + timeStr
    } else {
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "dd/MM HH:mm"
        return "Đặt lại sau " + cleaned + " · " + dayFormatter.string(from: target)
    }
}


// MARK: - Exact Progress Bar from CodexBar (UsageProgressBar.swift)
struct UsageProgressBar: View {
    let percent: Double
    let tint: Color
    var warningMarkerPercents: [Double] = [33.33, 66.66]
    var accentPaceMarker: Double? = nil
    
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
        .frame(height: 6)
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
struct CompactAccountRowView: View {
    let email: String
    let index: Int
    let totalCount: Int
    let subDetails: String
    let remainingPercent: Int
    let isAvailable: Bool
    let isCurrent: Bool
    var isProbeError: Bool = false
    var onMoveUp: (() -> Void)? = nil
    var onMoveDown: (() -> Void)? = nil
    let onSwitch: () -> Void
    
    @State private var isHovered: Bool = false
    
    var body: some View {
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
                        Text(self.email)
                            .font(.system(size: 11.5, weight: self.isCurrent ? .semibold : .regular))
                            .foregroundStyle(self.isCurrent ? Color.primary : (self.isAvailable ? Color.primary.opacity(0.88) : Color.secondary))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        
                        if self.isCurrent {
                            Image(systemName: "star.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(Color(nsColor: .systemYellow))
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
                            Text("Hết hạn")
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundStyle(Color(nsColor: .systemRed))
                        } else {
                            // CodexBar mini progress capsule
                            Capsule()
                                .fill(Color(white: 0.28, opacity: 0.5))
                                .frame(width: 44, height: 4)
                                .overlay(alignment: .leading) {
                                    Capsule()
                                        .fill(Color(red: 218/255, green: 119/255, blue: 86/255))
                                        .frame(width: 44 * CGFloat(max(0, min(100, self.remainingPercent))) / 100.0)
                                }
                            Text("\(self.remainingPercent)%")
                                .font(.system(size: 10, weight: .regular, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(minWidth: 26, alignment: .trailing)
                        }
                    }
                    
                    // Line 2: Details & Reset time (Clean, subtle secondary text)
                    Text(self.subDetails)
                        .font(.footnote)
                        .foregroundStyle(self.isAvailable ? Color.secondary : Color(nsColor: .systemRed).opacity(0.85))
                        .lineLimit(1)
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
    
    var subDetailsText: String {
        if isProbeError {
            return "\(plan) · Tạm nghẽn 429 API · Sẵn sàng"
        }
        if !isAvailable {
            let rTime = resetWeekly.isEmpty ? "18h" : resetWeekly
            let est = formatResetWithEst(raw: rTime)
            return "\(plan) · Hết hạn tuần · \(est)"
        }
        let rTime = reset5h.isEmpty ? resetWeekly : reset5h
        let est = formatResetWithEst(raw: rTime)
        return "\(plan) · 5h: \(used5h)% · Tuần: \(usedWeekly)% · \(est)"
    }
}

// Gateway Command Data Model
struct GatewayCommandItem: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let command: String
}

// MARK: - Claude Full Card View
struct ClaudeFullCardView: View {
    @ObservedObject var state: QuotaState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            // 1. Header (Active Account) - Exact CodexBar 1:1 Layout & Subtitle
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Claude")
                        .font(.headline)
                        .fontWeight(.semibold)
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
                MetricRow(
                    title: "Phiên 5h: \(self.state.claude5h)% đã dùng",
                    percent: Double(self.state.claude5h),
                    resetText: formatResetWithEst(raw: self.state.claude5hReset),
                    tint: Color(red: 218/255, green: 119/255, blue: 86/255),
                    paceText: "\(self.state.claudePaceReserve)% dự trữ nhịp độ",
                    paceMarker: Double(self.state.claudePaceReserve)
                )
                
                MetricRow(
                    title: "Hàng tuần: \(self.state.claude7d)% đã dùng",
                    percent: Double(self.state.claude7d),
                    resetText: formatResetWithEst(raw: self.state.claude7dReset),
                    tint: Color(red: 218/255, green: 119/255, blue: 86/255)
                )
            }
            
            Divider()
            
            // 3. Pool Account List (Minimal Card-based with Instant Reordering)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Pool Accounts")
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("▲▼ Thứ tự ưu tiên")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                
                ForEach(Array(self.state.claudeAccounts.enumerated()), id: \.element.id) { index, acc in
                    CompactAccountRowView(
                        email: acc.email,
                        index: index,
                        totalCount: self.state.claudeAccounts.count,
                        subDetails: acc.subDetailsText,
                        remainingPercent: acc.isAvailable ? acc.remainingWeekly : 0,
                        isAvailable: acc.isAvailable,
                        isCurrent: self.state.claudeEmail == acc.email,
                        isProbeError: acc.isProbeError,
                        onMoveUp: { self.state.moveAccount(fromIndex: index, toIndex: index - 1) },
                        onMoveDown: { self.state.moveAccount(fromIndex: index, toIndex: index + 1) },
                        onSwitch: { AppDelegate.shared?.confirmSwitch(to: acc.email) }
                    )
                }
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
            
            Divider()
            
            // 5. External Gateways (DeepSeek / Team Proxy) - CodexBar Provider Style
            Button(action: {
                AppDelegate.shared?.openGatewayWindow()
            }) {
                HStack(spacing: 8) {
                    // Official DeepSeek Whale Brand Icon (Monochrome/Template White style)
                    if let dsImg = loadTemplateIcon(name: "deepseek") {
                        Image(nsImage: dsImg)
                            .resizable()
                            .renderingMode(.template)
                            .foregroundStyle(Color.primary)
                            .frame(width: 14, height: 14)
                    } else {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .center, spacing: 6) {
                            Text("DeepSeek")
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundStyle(.primary)
                            
                            Text("Team Gateway")
                                .font(.system(size: 9.5))
                                .foregroundStyle(.secondary)
                            
                            Spacer(minLength: 4)
                            
                            if self.state.gwIsActiveNow {
                                HStack(spacing: 3) {
                                    Circle()
                                        .fill(Color(nsColor: .systemGreen))
                                        .frame(width: 5, height: 5)
                                    Text("Đang dùng")
                                        .font(.system(size: 8.5, weight: .medium))
                                        .foregroundStyle(Color(nsColor: .systemGreen))
                                }
                            } else {
                                Text(self.state.gwLastActiveHuman)
                                    .font(.system(size: 9))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        
                        // Line 2: Balance & Quick Spend Indicator
                        HStack(spacing: 4) {
                            Text("Đã dùng \(self.state.gwSpendFormatted)")
                                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                                .foregroundStyle(Color.primary.opacity(0.85))
                            Text("· Hạn mức: \(self.state.gwMaxBudgetFormatted)")
                                .font(.system(size: 9.5))
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
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
                Text("Đặt lại: \(self.reset.isEmpty ? "Sẵn sàng" : self.reset)")
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
                    Text("Antigravity")
                        .font(.headline)
                        .fontWeight(.semibold)
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
                // Group 1: Gemini Models
                VStack(alignment: .leading, spacing: 6) {
                    Text("GEMINI MODELS (Flash, Pro)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    
                    // Bar 1: Gemini 5-Hour Limit Remaining
                    MetricRow(
                        title: "Giới hạn 5h còn lại: \(self.state.agyGemini5hRemaining)%",
                        percent: Double(self.state.agyGemini5hRemaining),
                        resetText: formatResetWithEst(raw: self.state.agyGemini5hRefresh),
                        tint: Color(red: 0/255, green: 195/255, blue: 137/255), // Teal Green (Antigravity)
                        paceText: "Đã dùng \(100 - self.state.agyGemini5hRemaining)%",
                        paceMarker: nil
                    )
                    
                    // Bar 2: Gemini Weekly Limit Remaining
                    MetricRow(
                        title: "Giới hạn tuần còn lại: \(self.state.agyGeminiWeeklyRemaining)%",
                        percent: Double(self.state.agyGeminiWeeklyRemaining),
                        resetText: formatResetWithEst(raw: self.state.agyGeminiWeeklyRefresh),
                        tint: Color(red: 245/255, green: 197/255, blue: 66/255), // Amber Yellow (Antigravity)
                        paceText: "Đã dùng \(100 - self.state.agyGeminiWeeklyRemaining)%",
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
                    
                    // Bar 3: Claude & GPT 5-Hour Limit Remaining
                    MetricRow(
                        title: "Giới hạn 5h còn lại: \(self.state.agyClaudeGpt5hText)",
                        percent: Double(self.state.agyClaudeGpt5hRemaining),
                        resetText: formatResetWithEst(raw: self.state.agyClaudeGpt5hRefresh),
                        tint: Color(red: 0/255, green: 195/255, blue: 137/255), // Teal Green (Antigravity)
                        paceText: "100% khả dụng",
                        paceMarker: nil
                    )
                    
                    // Bar 4: Claude & GPT Weekly Limit Remaining
                    MetricRow(
                        title: "Giới hạn tuần còn lại: \(self.state.agyClaudeGptWeeklyRemaining)%",
                        percent: Double(self.state.agyClaudeGptWeeklyRemaining),
                        resetText: formatResetWithEst(raw: self.state.agyClaudeGptWeeklyRefresh),
                        tint: Color(red: 245/255, green: 197/255, blue: 66/255), // Amber Yellow (Antigravity)
                        paceText: "Đã dùng \(100 - self.state.agyClaudeGptWeeklyRemaining)%",
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
                    remainingPercent: self.state.agyGemini5hRemaining,
                    isAvailable: true,
                    isCurrent: true,
                    isProbeError: false,
                    onMoveUp: nil,
                    onMoveDown: nil,
                    onSwitch: {}
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


// MARK: - Native Settings View (CodexBarCustom Preferences)
struct SettingsView: View {
    @ObservedObject var state: QuotaState
    let onSave: () -> Void
    
    let intervals = [1, 15, 30, 60, 300]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cài đặt CodexBar Custom")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("Tùy chỉnh tần suất cập nhật Quota & Telemetry")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 14) {
                Toggle("Làm mới quota ngay khi mở Menu (Refresh on Open)", isOn: Binding(
                    get: { self.state.refreshOnOpen },
                    set: { newVal in
                        self.state.refreshOnOpen = newVal
                        UserDefaults.standard.set(newVal, forKey: "quota_refresh_on_open")
                    }
                ))
                .font(.headline)
                
                Text("Tự động gửi yêu cầu kiểm tra dữ liệu quota mới nhất mỗi khi bạn click vào biểu tượng trên Menubar.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 14) {
                Toggle("Hiển thị chi phí DeepSeek Gateway trên Menubar", isOn: Binding(
                    get: { self.state.showGatewaySpendOnMenubar },
                    set: { newVal in
                        self.state.showGatewaySpendOnMenubar = newVal
                        UserDefaults.standard.set(newVal, forKey: "show_gateway_spend_on_menubar")
                        self.state.onUpdate?()
                    }
                ))
                .font(.headline)
                
                Text("Hiển thị thông số chi phí đã tiêu thụ (vd: $0.00786) kèm theo Quota 5h và 7d trên thanh Menubar macOS.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Tần suất làm mới dữ liệu:")
                    .font(.headline)
                
                Picker("Tần suất", selection: Binding(
                    get: { self.state.refreshInterval },
                    set: { newVal in
                        self.state.refreshInterval = newVal
                        self.onSave()
                    }
                )) {
                    Text("1 giây (Cực nhanh)").tag(1)
                    Text("15 giây (Nhanh)").tag(15)
                    Text("30 giây (Chuẩn)").tag(30)
                    Text("1 phút (Mặc định)").tag(60)
                    Text("5 phút (Tiết kiệm pin)").tag(300)
                }
                .pickerStyle(.radioGroup)
                .padding(.leading, 8)
                
                Text("Gợi ý: Mặc định 1 phút (60s) là tối ưu nhất cho hiệu năng và hạn mức API.")
                    .font(.caption)
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
            }
        }
        .padding(20)
        .frame(width: 450, height: 430)
    }
}

// MARK: - State Management with Remote Priority Switching
class QuotaState: ObservableObject {
    @Published var claudeEmail = "trthuhuyen2712@gmail.com"
    @Published var claudePlan = "Max 5x"
    @Published var claude5h = 11
    @Published var claude7d = 26
    @Published var claude5hReset = "3h"
    @Published var claude7dReset = "6d 13h"
    @Published var claudePaceReserve = 89
    @Published var switchingMessage = ""
    @Published var claudeAccounts: [PoolAccountItem] = []
    
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
    
    @Published var agyClaudeGpt5hText: String = "Quota available"
    @Published var agyClaudeGpt5hRemaining: Int = 100
    @Published var agyClaudeGpt5hRefresh: String = "4h 24m"
    @Published var agyClaudeGptWeeklyRemaining: Int = 43
    @Published var agyClaudeGptWeeklyRefresh: String = "3d 19h"
    
    @Published var lastRefresh = "12:29:28"
    @Published var nextRefresh = "16:29:28"
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
    @Published var gwQuickCommands: [GatewayCommandItem] = []
    
    // Default refresh: 60s (1 phút)
    @Published var lastQuotaFetchDate: Date = Date()
    @Published var lastQuotaFetchAgoText: String = "Vừa xong"
    @Published var bridgeHost: String = UserDefaults.standard.string(forKey: "quota_bridge_host") ?? "http://100.127.1.234:8318"
    @Published var refreshOnOpen: Bool = UserDefaults.standard.bool(forKey: "quota_refresh_on_open")
    @Published var refreshInterval: Int = UserDefaults.standard.integer(forKey: "quota_refresh_interval") == 0 ? 60 : UserDefaults.standard.integer(forKey: "quota_refresh_interval")
    @Published var showGatewaySpendOnMenubar: Bool = UserDefaults.standard.object(forKey: "show_gateway_spend_on_menubar") == nil ? true : UserDefaults.standard.bool(forKey: "show_gateway_spend_on_menubar")
    
    var baseUrl: String {
        let host = bridgeHost.trimmingCharacters(in: .whitespacesAndNewlines)
        return host.hasSuffix("/") ? String(host.dropLast()) : host
    }
    
    var onUpdate: (() -> Void)?
    
    func saveInterval() {
        UserDefaults.standard.set(refreshInterval, forKey: "quota_refresh_interval")
        UserDefaults.standard.set(bridgeHost, forKey: "quota_bridge_host")
        AppDelegate.shared?.updateTimer()
    }
    
    func saveOrder() {
        let newOrder = self.claudeAccounts.map { $0.email }
        self.switchingMessage = "Đang lưu thứ tự Pool..."
        
        guard let url = URL(string: "\(self.baseUrl)/v1/set-order") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["order": newOrder]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: req) { data, _, _ in
            DispatchQueue.main.async {
                self.switchingMessage = "Đã cập nhật thứ tự selector!"
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.switchingMessage = ""
                }
            }
        }.resume()
    }

    func moveAccount(fromIndex: Int, toIndex: Int) {
        guard fromIndex >= 0, fromIndex < claudeAccounts.count,
              toIndex >= 0, toIndex < claudeAccounts.count,
              fromIndex != toIndex else { return }
        
        var accounts = claudeAccounts
        let moved = accounts.remove(at: fromIndex)
        accounts.insert(moved, at: toIndex)
        self.claudeAccounts = accounts
        self.saveOrder()
    }

    func updateAgoText() {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
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
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["email": email] as [String : Any]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: req) { data, _, _ in
            DispatchQueue.main.async {
                self.switchingMessage = "Đã chuyển & kiểm tra thành công!"
                self.claudeEmail = email
                self.fetchData()
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.switchingMessage = ""
                }
            }
        }.resume()
    }
    
    func fetchData() {
        if let url = URL(string: "\(self.baseUrl)/v1/keeper-telemetry") {
            URLSession.shared.dataTask(with: url) { data, _, _ in
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
            URLSession.shared.dataTask(with: agyUrl) { data, _, _ in
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
            URLSession.shared.dataTask(with: poolUrl) { data, _, _ in
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
                            resetWeekly: rWk
                        ))
                    }
                    self.claudeAccounts = parsedList
                    
                    if let current = parsedList.first(where: { $0.email == self.claudeEmail }) {
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
                    } else if let firstActive = parsedList.first(where: { $0.isAvailable }) {
                        self.claudeEmail = firstActive.email
                        self.claudePlan = firstActive.plan
                        self.claude5h = firstActive.used5h
                        self.claude7d = firstActive.usedWeekly
                        if firstActive.isProbeError {
                            self.claude5hReset = "Tạm nghẽn 429"
                            self.claude7dReset = "Tạm nghẽn 429"
                        } else {
                            self.claude5hReset = firstActive.reset5h.isEmpty ? "Đầy đủ" : firstActive.reset5h
                            self.claude7dReset = firstActive.resetWeekly
                        }
                        self.claudePaceReserve = firstActive.remaining5h
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
                Image(systemName: "bolt.horizontal.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Color(red: 90/255, green: 130/255, blue: 255/255))
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
                            .foregroundStyle(Color(red: 90/255, green: 130/255, blue: 255/255))
                    }
                    .frame(minWidth: 120, alignment: .leading)
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Hạn mức tối đa:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(self.state.gwMaxBudgetFormatted)
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundStyle(.primary)
                    }
                    .frame(minWidth: 120, alignment: .leading)
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Hoạt động gần nhất:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(self.state.gwLastActiveHuman)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(self.state.gwIsActiveNow ? Color(red: 52/255, green: 199/255, blue: 89/255) : Color.primary)
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


class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    static var shared: AppDelegate?
    
    var claudeItem: NSStatusItem!
    var agyItem: NSStatusItem!
    
    let state = QuotaState()
    var timer: Timer?
    var settingsWindow: NSWindow?
    var keeperWindow: NSWindow?
    var gatewayWindow: NSWindow?
    
    func menuWillOpen(_ menu: NSMenu) {
        state.updateAgoText()
        self.adjustMenuHostingHeights()
        if state.refreshOnOpen {
            state.fetchData()
        }
    }
    
    var claudeHostingView: NSView?
    var agyHostingView: NSView?
    
    func adjustMenuHostingHeights() {
        if let ch = claudeHostingView {
            let h = ch.fittingSize.height
            if h > 100 {
                ch.frame = NSRect(x: 0, y: 0, width: 365, height: h)
            }
        }
        if let ah = agyHostingView {
            let h = ah.fittingSize.height
            if h > 100 {
                ah.frame = NSRect(x: 0, y: 0, width: 365, height: h)
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
            btn.title = " 5h \(state.agyGemini5hRemaining)% · W \(state.agyGeminiWeeklyRemaining)%"
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
            var title = " 5h \(state.claude5h)% · W \(state.claude7d)%"
            if state.showGatewaySpendOnMenubar && !state.gwSpendFormatted.isEmpty {
                title += " · \(state.gwSpendFormatted)"
            }
            btn.title = title
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
        
        state.onUpdate = { [weak self] in
            guard let self = self else { return }
            if let btn = self.claudeItem.button {
                if btn.image == nil {
                    btn.image = loadTemplateIcon(name: "claude")
                    btn.imagePosition = .imageLeading
                }
                var title = " 5h \(self.state.claude5h)% · W \(self.state.claude7d)%"
                if self.state.showGatewaySpendOnMenubar && !self.state.gwSpendFormatted.isEmpty {
                    title += " · \(self.state.gwSpendFormatted)"
                }
                btn.title = title
            }
            if let agyBtn = self.agyItem.button {
                if agyBtn.image == nil {
                    agyBtn.image = loadTemplateIcon(name: "antigravity")
                    agyBtn.imagePosition = .imageLeading
                }
                agyBtn.title = " 5h \(self.state.agyGemini5hRemaining)% · W \(self.state.agyGeminiWeeklyRemaining)%"
            }
            self.adjustMenuHostingHeights()
        }
        
        state.fetchData()
        updateTimer()
    }
    
    func updateTimer() {
        timer?.invalidate()
        let interval = Double(state.refreshInterval)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.state.fetchData()
        }
    }
    
    @objc func refreshClicked() { state.fetchData() }
    
    @objc func settingsClicked() {
        openSettingsWindow()
    }
    
    func confirmSwitch(to email: String) {
        if state.claudeEmail == email { return }
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
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 430),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Cài đặt CodexBar Custom"
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
