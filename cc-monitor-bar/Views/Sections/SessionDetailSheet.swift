import SwiftUI

/// 会话详情面板 — 点击活跃会话卡片展开
/// 展示：消息时间线、工具调用、Token 消耗瀑布、Context Window
struct SessionDetailSheet: View {
    let session: Session
    let usage: SessionUsage

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
                    // 基本信息
                    InfoSection(session: session, usage: usage)

                    // Token 消耗瀑布
                    TokenWaterfallSection(usage: usage)

                    // Context Window
                    if usage.contextTokens > 0 {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Context Window")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            ContextLabel(contextTokens: usage.contextTokens)
                        }
                        .padding(DesignTokens.spacingSM)
                        .background(Color.secondary.opacity(0.04))
                        .cornerRadius(DesignTokens.radiusSM)
                    }

                    // 工具调用分布
                    if !usage.toolCounts.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("工具调用")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            ForEach(usage.toolCounts.sorted { $0.value > $1.value }, id: \.key) { tool, count in
                                HStack {
                                    Text(tool)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(ToolColors.color(for: tool))
                                    Spacer()
                                    Text("\(count)")
                                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                }
                            }
                        }
                        .padding(DesignTokens.spacingSM)
                        .background(Color.secondary.opacity(0.04))
                        .cornerRadius(DesignTokens.radiusSM)
                    }

                    // 模型分解
                    if !usage.modelBreakdowns.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("模型")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            ForEach(usage.modelBreakdowns.keys.sorted(), id: \.self) { model in
                                let breakdown = usage.modelBreakdowns[model]!
                                HStack {
                                    Text(model)
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(breakdown.totalTokens.formattedTokens)
                                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                }
                            }
                        }
                        .padding(DesignTokens.spacingSM)
                        .background(Color.secondary.opacity(0.04))
                        .cornerRadius(DesignTokens.radiusSM)
                    }
                }
                .padding(DesignTokens.spacingMD)
            }
            .navigationTitle(projectName(session.projectPath))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private func projectName(_ path: String) -> String {
        let components = path.components(separatedBy: "/")
        return components.last ?? path
    }
}

// MARK: - Sub-sections

struct InfoSection: View {
    let session: Session
    let usage: SessionUsage

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            InfoRow(label: "PID", value: "\(session.pid)")
            InfoRow(label: "路径", value: session.projectPath)
            InfoRow(label: "入口", value: session.entrypoint)
            InfoRow(label: "运行时间", value: session.durationFormatted)
            InfoRow(label: "消息数", value: "\(usage.messageCount)")
            InfoRow(label: "工具调用", value: "\(usage.toolCallCount)")
        }
        .padding(DesignTokens.spacingSM)
        .background(Color.secondary.opacity(0.04))
        .cornerRadius(DesignTokens.radiusSM)
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .leading)
            Text(value)
                .font(.system(size: 10, design: .monospaced))
                .lineLimit(1)
        }
    }
}

struct TokenWaterfallSection: View {
    let usage: SessionUsage

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Token 用量")
                .font(.caption)
                .foregroundColor(.secondary)

            WaterfallRow(label: "Input", tokens: usage.inputTokens, color: .blue)
            WaterfallRow(label: "Output", tokens: usage.outputTokens, color: .green)
            WaterfallRow(label: "Cache Read", tokens: usage.cacheReadTokens, color: .purple)
            WaterfallRow(label: "Cache Create", tokens: usage.cacheCreationTokens, color: .orange)

            Divider()
                .padding(.vertical, 2)

            HStack {
                Text("Total")
                    .font(.system(size: 11, weight: .bold))
                Spacer()
                Text(usage.totalTokens.formattedTokens)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
            }
        }
        .padding(DesignTokens.spacingSM)
        .background(Color.secondary.opacity(0.04))
        .cornerRadius(DesignTokens.radiusSM)
    }
}

struct WaterfallRow: View {
    let label: String
    let tokens: Int64
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(color)
            Spacer()
            Text(tokens.formattedTokens)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
        }
    }
}

#Preview {
    SessionDetailSheet(
        session: Session(
            id: "abc123", pid: 12345,
            projectPath: "/Users/ido/project/mac/cc-monitor-bar",
            projectId: "cc-monitor-bar",
            startedAt: Date().addingTimeInterval(-3600),
            endedAt: nil, durationMs: 3600000,
            messageCount: 23, toolCallCount: 142, entrypoint: "cli"
        ),
        usage: SessionUsage(
            inputTokens: 120_000, outputTokens: 45_000,
            cacheReadTokens: 30_000, cacheCreationTokens: 5_000,
            messageCount: 23, toolCallCount: 142,
            models: ["claude-sonnet-4-5-20250929": 200_000],
            contextTokens: 142_000
        )
    )
}
