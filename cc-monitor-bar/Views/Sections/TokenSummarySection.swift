import SwiftUI

/// 今日 Token 摘要卡片
struct TokenSummarySection: View {
    let stats: TodayStats?
    let qualityStatus: DataQualityStatus?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            HStack {
                Text("今日 Token")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if let stats = stats {
                    Text(stats.totalTokens.formattedTokens)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.blue)
                } else {
                    Text("--")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                }
            }

            HStack(spacing: DesignTokens.spacingLG) {
                TokenDetailRow(label: "↑ 输入", value: stats?.inputTokens ?? 0, color: .blue)
                TokenDetailRow(label: "↓ 输出", value: stats?.outputTokens ?? 0, color: .green)
                TokenDetailRow(label: "⟳ 缓存", value: stats?.cacheTokens ?? 0, color: .teal)
            }

            if let qualityStatus = qualityStatus {
                QualityStatusRow(status: qualityStatus)
            }
        }
        .padding(DesignTokens.spacingMD)
        .background(GlassBackground().opacity(0.06))
        .cornerRadius(DesignTokens.radiusMD)
    }
}

/// 数据质量校验状态行 + 可展开诊断面板
struct QualityStatusRow: View {
    let status: DataQualityStatus
    @State private var isExpanded = false

    private var qualityColor: Color {
        switch status.level {
        case .healthy: return .green
        case .warning: return .orange
        case .critical: return .red
        case .unavailable: return .gray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 紧凑状态行
            HStack(spacing: 6) {
                Circle()
                    .fill(qualityColor)
                    .frame(width: 6, height: 6)
                Text("校验 \(status.level.displayText)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text(status.summary)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                if status.diffBreakdown != nil {
                    Button(action: { isExpanded.toggle() }) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            // 可展开的诊断详情
            if isExpanded, let breakdown = status.diffBreakdown {
                VStack(spacing: 4) {
                    ForEach(breakdown.items, id: \.dimension) { item in
                        DiffItemRow(item: item)
                    }
                }
                .padding(.top, 4)
            }
        }
    }
}

/// 单个维度差异对比行
struct DiffItemRow: View {
    let item: DataQualityDiffItem

    private var diffColor: Color {
        if item.diffRatio <= 0.15 { return .green }
        if item.diffRatio <= 0.35 { return .orange }
        return .red
    }

    private var formattedValue: (Int64) -> String {
        { $0.formattedTokens }
    }

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Text(item.dimension)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
                HStack(spacing: 6) {
                    HStack(spacing: 2) {
                        Text("JSONL")
                            .font(.system(size: 7))
                            .foregroundColor(.secondary)
                        Text(formattedValue(item.jsonlValue))
                            .font(.system(size: 8, design: .monospaced))
                    }
                    Text("vs")
                        .font(.system(size: 7))
                        .foregroundColor(.secondary)
                    HStack(spacing: 2) {
                        Text("Cache")
                            .font(.system(size: 7))
                            .foregroundColor(.secondary)
                        Text(formattedValue(item.cacheValue))
                            .font(.system(size: 8, design: .monospaced))
                    }
                }
                Text(String(format: "%.0f%%", item.diffRatio * 100))
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .foregroundColor(diffColor)
            }
            if item.diffRatio > 0.15 {
                HStack(spacing: 4) {
                    Text("原因: \(item.reason.rawValue)")
                        .font(.system(size: 7))
                        .foregroundColor(.orange)
                    Spacer()
                    Text(item.suggestion)
                        .font(.system(size: 7))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(Color.secondary.opacity(0.04))
        .cornerRadius(DesignTokens.radiusSM)
    }
}

struct TokenDetailRow: View {
    let label: String
    let value: Int64
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(color)
            Text(value.formattedTokens)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(color)
        }
    }
}

#Preview {
    TokenSummarySection(stats: TodayStats(
        messageCount: 100,
        sessionCount: 5,
        toolCallCount: 500,
        totalTokens: 1_234_567,
        inputTokens: 600_000,
        outputTokens: 400_000,
        cacheTokens: 234_567,
        modelBreakdown: [],
        toolCounts: [:]
    ), qualityStatus: DataQualityStatus(
        level: .healthy,
        summary: "实时 JSONL 与 cache 校验一致",
        sourceDate: "2026-04-25",
        isCacheStale: false,
        tokenDiffRatio: 0.03,
        messageDiffRatio: 0.02,
        sessionDiffRatio: 0.01,
        toolDiffRatio: 0.04,
        diffBreakdown: DataQualityDiffBreakdown(items: [
            DataQualityDiffItem(dimension: "Token", jsonlValue: 1_234_567, cacheValue: 1_200_000, diffRatio: 0.03, reason: .normal, suggestion: ""),
            DataQualityDiffItem(dimension: "Message", jsonlValue: 100, cacheValue: 98, diffRatio: 0.02, reason: .normal, suggestion: ""),
            DataQualityDiffItem(dimension: "Session", jsonlValue: 5, cacheValue: 5, diffRatio: 0.01, reason: .normal, suggestion: ""),
            DataQualityDiffItem(dimension: "Tool", jsonlValue: 500, cacheValue: 480, diffRatio: 0.04, reason: .normal, suggestion: ""),
        ])
    ))
    .frame(width: 300)
    .padding()
}
