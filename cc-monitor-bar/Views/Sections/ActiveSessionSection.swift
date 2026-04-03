import SwiftUI

/// 活跃会话列表
struct ActiveSessionSection: View {
    let sessions: [Session]
    let usages: [String: SessionUsage]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            HStack {
                Text("活跃会话")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Circle()
                    .fill(.green)
                    .frame(width: 6, height: 6)
            }

            ForEach(sessions, id: \.id) { session in
                SessionCard(session: session, usage: usages[session.id])
            }
        }
        .padding(DesignTokens.spacingMD)
        .background(GlassBackground().opacity(0.04))
        .cornerRadius(DesignTokens.radiusMD)
    }
}

struct SessionCard: View {
    let session: Session
    let usage: SessionUsage?

    var body: some View {
        VStack(spacing: DesignTokens.spacingXS) {
            HStack(spacing: DesignTokens.spacingSM) {
                Circle()
                    .fill(.green)
                    .frame(width: 6, height: 6)
                Text(projectName(session.projectPath))
                    .font(.system(size: 10, weight: .medium))
                Spacer()
                if let usage = usage {
                    Text("\(usage.messageCount) msg")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Text(session.durationFormatted)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }

            HStack(spacing: DesignTokens.spacingMD) {
                HStack(spacing: 4) {
                    Text("↑")
                        .font(.system(size: 9))
                        .foregroundColor(.blue)
                    Text((usage?.inputTokens ?? 0).formattedTokens)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.blue)
                }
                HStack(spacing: 4) {
                    Text("↓")
                        .font(.system(size: 9))
                        .foregroundColor(.green)
                    Text((usage?.outputTokens ?? 0).formattedTokens)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.green)
                }
                Spacer()
                Text((usage?.totalTokens ?? 0).formattedTokens)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
            }
        }
        .padding(DesignTokens.spacingSM)
        .background(Color.secondary.opacity(0.04))
        .cornerRadius(DesignTokens.radiusSM)
    }

    private func projectName(_ path: String) -> String {
        let components = path.components(separatedBy: "/")
        return components.last ?? path
    }
}

#Preview {
    ActiveSessionSection(
        sessions: [
            Session(
                id: "abc123",
                pid: 12345,
                projectPath: "/Users/ido/project/mac/cc-monitor-bar",
                projectId: "cc-monitor-bar",
                startedAt: Date().addingTimeInterval(-3600),
                endedAt: nil,
                durationMs: 3600000,
                messageCount: 23,
                toolCallCount: 142,
                entrypoint: "cli"
            )
        ],
        usages: [
            "abc123": SessionUsage(
                inputTokens: 32100,
                outputTokens: 10500,
                cacheReadTokens: 2000,
                cacheCreationTokens: 600,
                messageCount: 23,
                toolCallCount: 142,
                models: ["claude-sonnet-4-5-20250929": 32100]
            )
        ]
    )
    .frame(width: 300)
    .padding()
}
