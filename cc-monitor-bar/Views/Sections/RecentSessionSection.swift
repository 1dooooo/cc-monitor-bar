import SwiftUI

/// 最近会话列表
struct RecentSessionSection: View {
    let sessions: [Session]
    let usages: [String: SessionUsage]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            Text("最近会话")
                .font(.caption)
                .foregroundColor(.secondary)

            ForEach(sessions.prefix(5), id: \.id) { session in
                SessionRow(session: session, usage: usages[session.id])
            }
        }
        .padding(DesignTokens.spacingMD)
        .background(GlassBackground().opacity(0.04))
        .cornerRadius(DesignTokens.radiusMD)
    }
}

struct SessionRow: View {
    let session: Session
    let usage: SessionUsage?

    var body: some View {
        HStack(spacing: DesignTokens.spacingSM) {
            Circle()
                .fill(.gray)
                .frame(width: 6, height: 6)
            Text(projectName(session.projectPath))
                .font(.system(size: 10))
            Spacer()
            Text(session.durationFormatted)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
            if let usage = usage {
                Text("↑ \(usage.inputTokens.formattedTokens)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.blue)
                Text("↓ \(usage.outputTokens.formattedTokens)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.green)
            }
            if let usage = usage {
                Text(usage.totalTokens.formattedTokens)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
            } else {
                Text("--")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.5))
            }
        }
        .padding(.vertical, DesignTokens.spacingSM)
    }

    private func projectName(_ path: String) -> String {
        let components = path.components(separatedBy: "/")
        return components.last ?? path
    }
}

struct SessionRowPreview: View {
    var body: some View {
        SessionRow(
            session: Session(
                id: "def456",
                pid: 0,
                projectPath: "/Users/ido/project/mac/my-webapp",
                projectId: "my-webapp",
                startedAt: Date().addingTimeInterval(-7200),
                endedAt: Date().addingTimeInterval(-3600),
                durationMs: 3600000,
                messageCount: 56,
                toolCallCount: 280,
                entrypoint: "cli"
            ),
            usage: SessionUsage(
                inputTokens: 89600,
                outputTokens: 31200,
                cacheReadTokens: 5000,
                cacheCreationTokens: 1200,
                messageCount: 56,
                toolCallCount: 280,
                models: ["claude-sonnet-4-5-20250929": 89600]
            )
        )
    }
}

#Preview {
    RecentSessionSection(
        sessions: [
            Session(
                id: "def456",
                pid: 0,
                projectPath: "/Users/ido/project/mac/my-webapp",
                projectId: "my-webapp",
                startedAt: Date().addingTimeInterval(-7200),
                endedAt: Date().addingTimeInterval(-3600),
                durationMs: 3600000,
                messageCount: 56,
                toolCallCount: 280,
                entrypoint: "cli"
            )
        ],
        usages: [
            "def456": SessionUsage(
                inputTokens: 89600,
                outputTokens: 31200,
                cacheReadTokens: 5000,
                cacheCreationTokens: 1200,
                messageCount: 56,
                toolCallCount: 280,
                models: ["claude-sonnet-4-5-20250929": 89600]
            )
        ]
    )
    .frame(width: 300)
    .padding()
}
