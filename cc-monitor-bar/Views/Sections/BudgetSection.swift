import SwiftUI

/// 预算进度区块
struct BudgetSection: View {
    let todayStats: TodayStats?
    @EnvironmentObject var preferences: AppPreferences

    private var spentAmount: Double {
        guard let todayStats, !todayStats.modelBreakdown.isEmpty else { return 0 }
        return PricingTable.estimateTotalCost(breakdown: todayStats.modelBreakdown)
    }

    private var budgetRatio: Double {
        guard preferences.budgetAmount > 0 else { return 0 }
        return min(spentAmount / preferences.budgetAmount, 1.0)
    }

    private var progressColor: Color {
        if budgetRatio > 0.8 { return .red }
        if budgetRatio > 0.5 { return .orange }
        return .green
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            HStack {
                Text("预算进度")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(String(format: "$%.2f / $%.0f", spentAmount, preferences.budgetAmount))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(progressColor)
            }

            ProgressView(value: budgetRatio)
                .tint(progressColor)
                .scaleEffect(y: 0.8)

            if budgetRatio > 0.8 {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                    Text("预算即将超出")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(DesignTokens.spacingMD)
        .background(GlassBackground().opacity(0.06))
        .cornerRadius(DesignTokens.radiusMD)
    }
}

#Preview {
    BudgetSection(todayStats: TodayStats(
        messageCount: 100,
        sessionCount: 5,
        toolCallCount: 500,
        totalTokens: 1_234_567,
        inputTokens: 600_000,
        outputTokens: 400_000,
        cacheTokens: 234_567,
        modelBreakdown: [
            (name: "claude-sonnet-4", tokens: 1_000_000, inputTokens: 500_000, outputTokens: 300_000, cacheTokens: 200_000),
            (name: "claude-opus-4", tokens: 234_567, inputTokens: 100_000, outputTokens: 100_000, cacheTokens: 34_567)
        ],
        toolCounts: [:]
    ))
    .environmentObject(AppPreferences())
    .frame(width: 300)
    .padding()
}
