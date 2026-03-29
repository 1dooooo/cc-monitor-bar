import SwiftUI

/// 模型用量列表 — 使用设计系统 ProgressBar 和 ThemeColors
struct ModelUsageList: View {
    let breakdown: [(name: String, tokens: Int64)]

    @Environment(\.colorTheme) private var theme

    private var maxTokens: Int64 {
        breakdown.map(\.tokens).max() ?? 1
    }

    private var totalTokens: Int64 {
        breakdown.map(\.tokens).reduce(0, +)
    }

    var body: some View {
        VStack(spacing: DesignTokens.spacingSM) {
            ForEach(breakdown, id: \.name) { model in
                HStack(spacing: DesignTokens.spacingSM) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.name)
                            .font(.caption)
                            .lineLimit(1)
                        if totalTokens > 0 {
                            Text("\(Int(Double(model.tokens) / Double(totalTokens) * 100))%")
                                .font(.caption2)
                                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                        }
                    }
                    .frame(width: 80, alignment: .leading)

                    ProgressBar(
                        value: Double(model.tokens) / Double(maxTokens),
                        color: ModelColors.color(for: model.name),
                        height: 3
                    )

                    Text(formatNumber(model.tokens))
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundColor(Color(nsColor: .secondaryLabelColor))
                        .frame(width: 46, alignment: .trailing)
                }
            }
        }
    }

    private func formatNumber(_ n: Int64) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.0fK", Double(n) / 1_000) }
        return "\(n)"
    }
}
