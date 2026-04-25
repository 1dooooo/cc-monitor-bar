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
                HStack(spacing: 6) {
                    Circle()
                        .fill(qualityColor(for: qualityStatus.level))
                        .frame(width: 6, height: 6)
                    Text("校验 \(qualityStatus.level.displayText)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(qualityStatus.summary)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(DesignTokens.spacingMD)
        .background(GlassBackground().opacity(0.06))
        .cornerRadius(DesignTokens.radiusMD)
    }

    private func qualityColor(for level: DataQualityLevel) -> Color {
        switch level {
        case .healthy:
            return .green
        case .warning:
            return .orange
        case .critical:
            return .red
        case .unavailable:
            return .gray
        }
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
        toolDiffRatio: 0.04
    ))
    .frame(width: 300)
    .padding()
}
