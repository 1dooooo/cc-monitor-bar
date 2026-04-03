import SwiftUI

/// 今日 Token 摘要卡片
struct TokenSummarySection: View {
    let stats: TodayStats?

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
                TokenDetailRow(label: "↑ 输入", value: (stats?.totalTokens ?? 0) / 3, color: .blue)
                TokenDetailRow(label: "↓ 输出", value: (stats?.totalTokens ?? 0) / 3, color: .green)
                TokenDetailRow(label: "⟳ 缓存", value: (stats?.totalTokens ?? 0) / 3, color: .teal)
            }
        }
        .padding(DesignTokens.spacingMD)
        .background(GlassBackground().opacity(0.06))
        .cornerRadius(DesignTokens.radiusMD)
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
        modelBreakdown: []
    ))
    .frame(width: 300)
    .padding()
}
