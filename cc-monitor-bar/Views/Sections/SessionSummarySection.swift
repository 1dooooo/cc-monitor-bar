import SwiftUI

/// 会话统计摘要区块
struct SessionSummarySection: View {
    let activeSessions: [Session]
    let todayStats: TodayStats?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            HStack {
                Text("会话统计")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if let stats = todayStats {
                    Text("\(stats.sessionCount) 个会话")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            HStack(spacing: DesignTokens.spacingLG) {
                StatItem(
                    icon: "circle.fill",
                    iconColor: activeSessions.isEmpty ? .gray : .green,
                    label: "活跃",
                    value: "\(activeSessions.count)"
                )

                if let stats = todayStats {
                    StatItem(
                        icon: "bubble.left.fill",
                        iconColor: .blue,
                        label: "消息",
                        value: "\(stats.messageCount)"
                    )

                    StatItem(
                        icon: "wrench.and.screwdriver.fill",
                        iconColor: .purple,
                        label: "工具",
                        value: "\(stats.toolCallCount)"
                    )
                }
            }
        }
        .padding(DesignTokens.spacingMD)
        .background(GlassBackground().opacity(0.06))
        .cornerRadius(DesignTokens.radiusMD)
    }
}

struct StatItem: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(iconColor)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
            }
        }
    }
}

#Preview {
    SessionSummarySection(
        activeSessions: [
            Session(
                id: "1", pid: 1234, projectPath: "/test", projectId: "test",
                startedAt: Date(), endedAt: nil, durationMs: 300000,
                messageCount: 10, toolCallCount: 5, entrypoint: "cli"
            ),
            Session(
                id: "2", pid: 5678, projectPath: "/test2", projectId: "test2",
                startedAt: Date(), endedAt: nil, durationMs: 120000,
                messageCount: 5, toolCallCount: 2, entrypoint: "cli"
            )
        ],
        todayStats: TodayStats(
            messageCount: 100,
            sessionCount: 5,
            toolCallCount: 500,
            totalTokens: 1_234_567,
            inputTokens: 600_000,
            outputTokens: 400_000,
            cacheTokens: 234_567,
            modelBreakdown: [],
            toolCounts: [:]
        )
    )
    .frame(width: 300)
    .padding()
}
