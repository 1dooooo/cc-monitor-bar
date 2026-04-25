import SwiftUI

/// 会话统计摘要 — 展示来自 SQLite 的真实数据
struct SessionReplayView: View {
    let session: SessionRecord

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignTokens.spacingSM) {
                    SessionDetailInfo(session: session)
                }
                .padding()
            }
            .navigationTitle(session.projectPath.isEmpty ? "会话详情" : session.projectPath)
        }
    }
}

/// 会话详情信息
struct SessionDetailInfo: View {
    let session: SessionRecord

    var body: some View {
        VStack(spacing: DesignTokens.spacingSM) {
            InfoRow(label: "ID", value: String(session.id.prefix(8)))
            InfoRow(label: "项目", value: session.projectPath)
            InfoRow(label: "运行时间", value: session.durationFormatted())
            InfoRow(label: "消息数", value: "\(session.messageCount)")
            InfoRow(label: "工具调用", value: "\(session.toolCallCount)")
            InfoRow(label: "总 Token", value: session.totalTokens.formattedTokens)
            InfoRow(label: "Context", value: session.contextTokens.formattedTokens)
        }
    }
}

#Preview {
    SessionReplayView(
        session: SessionRecord(
            id: "abc123", pid: 12345, projectPath: "/Users/ido/project",
            projectId: "my-project", startedAt: Date().addingTimeInterval(-3600),
            endedAt: Date(), durationMs: 3600000,
            messageCount: 23, toolCallCount: 142, entrypoint: "cli",
            inputTokens: 120_000, outputTokens: 45_000,
            cacheReadTokens: 30_000, cacheCreationTokens: 5_000, contextTokens: 142_000
        )
    )
}
