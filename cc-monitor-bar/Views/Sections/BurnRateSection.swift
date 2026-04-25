import SwiftUI

/// Burn Rate — 消耗速率展示卡片
///
/// 显示 tokens/min + 颜色编码（绿/黄/红）
struct BurnRateSection: View {
    let rate: Double
    let level: BurnRateTracker.RateLevel
    let isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            HStack {
                Text("Burn Rate")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(level.emoji)
                    .font(.caption)
            }

            if isActive {
                HStack(spacing: DesignTokens.spacingMD) {
                    Text("\(Int(rate))")
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(rateColor)
                    Text("tokens/min")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(level.displayText)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(rateColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(rateColor.opacity(0.12))
                        .cornerRadius(DesignTokens.radiusSM)
                }
            } else {
                HStack {
                    Text("等待数据中...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .padding(DesignTokens.spacingMD)
        .background(GlassBackground().opacity(0.04))
        .cornerRadius(DesignTokens.radiusMD)
    }

    private var rateColor: Color {
        switch level {
        case .idle: return .green
        case .active: return .orange
        case .heavy: return .red
        }
    }
}

#Preview {
    BurnRateSection(
        rate: 423,
        level: .active,
        isActive: true
    )
    .frame(width: 300)
    .padding()
}
