import SwiftUI

struct TimelineEvent: Identifiable, Hashable {
    let id: String
    let time: Date
    let type: EventType
    let title: String
    var details: String?
    var project: String?
    var tokens: Int64?

    enum EventType: String {
        case sessionStart = "session_start"
        case sessionEnd = "session_end"
        case toolPeak = "tool_peak"
        case message = "message"

        var icon: String {
            switch self {
            case .sessionStart: return "play.circle.fill"
            case .sessionEnd:   return "stop.circle"
            case .toolPeak:     return "bolt.fill"
            case .message:      return "bubble.left.fill"
            }
        }

        var color: Color {
            switch self {
            case .sessionStart: return ThemeColors.active
            case .sessionEnd:   return ThemeColors.muted
            case .toolPeak:     return ThemeColors.info
            case .message:      return ThemeColors.warning
            }
        }
    }
}

struct TimelineEventRow: View {
    let event: TimelineEvent
    @Environment(\.colorTheme) private var theme
    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.spacingSM) {
            // 时间线连接点
            VStack(spacing: 0) {
                Circle()
                    .fill(event.type.color)
                    .frame(width: DesignTokens.statusDotSize, height: DesignTokens.statusDotSize)
                Rectangle()
                    .fill(ThemeColors.divider(theme))
                    .frame(width: 2)
            }

            // 事件内容
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(formattedTime)
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                        .frame(width: 50)

                    Text(event.title)
                        .font(.subheadline)
                        .foregroundColor(.primary)

                    Spacer()
                }

                if let project = event.project {
                    Text(project)
                        .font(.caption2)
                        .foregroundColor(Color(nsColor: .secondaryLabelColor))
                }

                if let details = event.details {
                    Text(details)
                        .font(.caption2)
                        .foregroundColor(Color(nsColor: .secondaryLabelColor))
                }

                if let tokens = event.tokens {
                    HStack(spacing: 3) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 9))
                        Text(tokens.formattedTokens)
                            .monospacedDigit()
                    }
                    .font(.caption2)
                    .foregroundColor(Color(nsColor: .secondaryLabelColor))
                }
            }
        }
        .padding(.vertical, DesignTokens.spacingXS)
        .padding(.horizontal, DesignTokens.spacingSM)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.radiusMD)
                .fill(isHovered ? ThemeColors.highlightBackground(theme) : Color.clear)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: DesignTokens.animationFast)) {
                isHovered = hovering
            }
        }
    }

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: event.time)
    }
}
