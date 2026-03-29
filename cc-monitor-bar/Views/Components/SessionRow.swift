import SwiftUI

/// 会话行 — 活跃/历史/选中三种状态
struct SessionRow: View {
    let session: Session
    let tokenUsage: SessionUsage?
    let toolCalls: [ToolCall]?
    var isSelected: Bool = false
    var onTap: () -> Void = {}

    @Environment(\.colorTheme) private var theme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignTokens.spacingSM) {
                // 状态指示点
                statusDot

                VStack(alignment: .leading, spacing: 2) {
                    // 第一行：项目名 + 时长
                    HStack {
                        Text(projectName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Spacer()
                        if session.isRunning {
                            Text(session.durationFormatted)
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundColor(ThemeColors.accent(theme))
                        } else {
                            Text(timeAgo)
                                .font(.caption)
                                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                        }
                    }

                    // 第二行：消息数 / Token / 工具
                    HStack(spacing: DesignTokens.spacingSM) {
                        if let usage = tokenUsage {
                            Label {
                                Text(usage.totalTokens.formattedTokens)
                                    .font(.caption2)
                                    .monospacedDigit()
                            } icon: {
                                Image(systemName: "circle.hexagongrid")
                                    .font(.system(size: 9))
                            }
                            .foregroundColor(Color(nsColor: .secondaryLabelColor))
                        }

                        if session.messageCount > 0 {
                            Label {
                                Text("\(session.messageCount)")
                                    .font(.caption2)
                            } icon: {
                                Image(systemName: "bubble.left")
                                    .font(.system(size: 9))
                            }
                            .foregroundColor(Color(nsColor: .secondaryLabelColor))
                        }

                        if let tools = toolCalls, !tools.isEmpty {
                            let unique = Dictionary(grouping: tools, by: \.toolName)
                                .map { (name: $0.key, count: $0.value.count) }
                                .sorted { $0.count > $1.count }
                            Text(unique.map { "\($0.name)\($0.count > 1 ? "×\($0.count)" : "")" }.joined(separator: " "))
                                .font(.caption2)
                                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                                .lineLimit(1)
                        }
                    }
                }
            }
            .padding(.horizontal, DesignTokens.spacingSM)
            .padding(.vertical, DesignTokens.spacingSM)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.radiusMD)
                    .fill(isSelected ? ThemeColors.highlightBackground(theme) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.radiusMD)
                    .stroke(isSelected ? ThemeColors.accent(theme).opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 状态指示点

    private var statusDot: some View {
        Circle()
            .fill(session.isRunning ? ThemeColors.active : ThemeColors.muted)
            .frame(width: DesignTokens.statusDotSize, height: DesignTokens.statusDotSize)
            .opacity(session.isRunning ? 1 : 0.5)
    }

    // MARK: - 辅助计算

    private var projectName: String {
        let url = URL(fileURLWithPath: session.projectPath)
        return url.lastPathComponent
    }

    private var timeAgo: String {
        guard let ended = session.endedAt else { return "" }
        let interval = Date().timeIntervalSince(ended)
        if interval < 60 { return "刚刚" }
        if interval < 3600 { return "\(Int(interval / 60))m前" }
        if interval < 86400 { return "\(Int(interval / 3600))h前" }
        return "\(Int(interval / 86400))d前"
    }
}
