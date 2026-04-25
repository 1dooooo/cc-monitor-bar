import SwiftUI

/// 项目级聚合 — 按项目展示今日 Token 用量和会话数
struct ProjectSummarySection: View {
    let projects: [ProjectSummary]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            HStack {
                Text("项目聚合")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(projects.count) 个项目")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if projects.isEmpty {
                Text("暂无数据")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: DesignTokens.spacingXS) {
                    ForEach(projects, id: \.name) { project in
                        ProjectSummaryRow(project: project)
                    }
                }
            }
        }
        .padding(DesignTokens.spacingMD)
        .background(GlassBackground().opacity(0.04))
        .cornerRadius(DesignTokens.radiusMD)
    }
}

struct ProjectSummaryRow: View {
    let project: ProjectSummary

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Text(projectName(project.name))
                    .font(.system(size: 10, weight: .semibold))
                Spacer()
                HStack(spacing: 6) {
                    HStack(spacing: 2) {
                        Text("↑")
                            .font(.system(size: 8))
                            .foregroundColor(.blue)
                        Text(project.inputTokens.formattedTokens)
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundColor(.blue)
                    }
                    HStack(spacing: 2) {
                        Text("↓")
                            .font(.system(size: 8))
                            .foregroundColor(.green)
                        Text(project.outputTokens.formattedTokens)
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundColor(.green)
                    }
                }
            }

            HStack(spacing: DesignTokens.spacingMD) {
                Text(project.totalTokens.formattedTokens)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                Text("·")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                Text("\(project.sessionCount) session")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
                Text("·")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                Text("\(project.messageCount) msg")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
                Spacer()
                // 工具标签
                HStack(spacing: 2) {
                    ForEach(project.toolCounts.sorted { $0.value > $1.value }.prefix(3), id: \.key) { tool, count in
                        Text(tool)
                            .font(.system(size: 7, weight: .medium))
                            .foregroundColor(ToolColors.color(for: tool))
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(ToolColors.color(for: tool).opacity(0.1))
                            .cornerRadius(2)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(Color.secondary.opacity(0.03))
        .cornerRadius(DesignTokens.radiusSM)
    }

    private func projectName(_ fullName: String) -> String {
        // 尝试提取最后一段路径
        let components = fullName.components(separatedBy: "-")
        return components.last?.capitalized ?? fullName
    }
}

#Preview {
    ProjectSummarySection(projects: [
        ProjectSummary(
            name: "-Users-ido-project-mac-cc-monitor-bar",
            messageCount: 230, sessionCount: 8, toolCallCount: 450,
            totalTokens: 1_234_567, inputTokens: 800_000, outputTokens: 300_000,
            cacheTokens: 134_567, toolCounts: ["Read": 120, "Bash": 90, "Edit": 80]
        ),
        ProjectSummary(
            name: "-Users-ido-project-mac-other-app",
            messageCount: 45, sessionCount: 2, toolCallCount: 100,
            totalTokens: 345_678, inputTokens: 200_000, outputTokens: 100_000,
            cacheTokens: 45_678, toolCounts: ["Write": 30, "Glob": 20, "Grep": 15]
        ),
    ])
    .frame(width: 300)
    .padding()
}
