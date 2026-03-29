import SwiftUI

/// 统计卡片 — 显示标题+数值+可选趋势/图标
struct StatCard: View {
    let title: String
    let value: String
    let trend: String?
    var icon: String? = nil

    init(title: String, value: String, trend: String? = nil, icon: String? = nil) {
        self.title = title
        self.value = value
        self.trend = trend
        self.icon = icon
    }

    @Environment(\.colorTheme) private var theme

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 3) {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 10))
                            .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                    }
                    Text(title)
                        .font(.caption2)
                        .foregroundColor(Color(nsColor: .secondaryLabelColor))
                        .lineLimit(1)
                }

                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .lineLimit(1)
            }

            Spacer()

            if let trendValue = trend {
                HStack(spacing: 2) {
                    Image(systemName: trendIcon)
                        .font(.caption2)
                    Text(trendValue)
                        .font(.caption2)
                }
                .foregroundColor(trendColor)
                .lineLimit(1)
            }
        }
        .padding(DesignTokens.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.radiusMD)
                .fill(ThemeColors.cardBackground(theme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.radiusMD)
                .stroke(ThemeColors.cardBorder(theme), lineWidth: 1)
        )
    }

    private var trendIcon: String {
        trend?.contains("+") == true ? "arrow.up.right" : "arrow.down.right"
    }

    private var trendColor: Color {
        trend?.contains("+") == true ? ThemeColors.active : ThemeColors.error
    }
}

// MARK: - Int64 便利初始化

extension StatCard {
    init(title: String, rawValue: Int64, trend: String? = nil) {
        self.title = title
        self.value = rawValue.formattedTokens
        self.trend = trend
        self.icon = nil
    }
}
