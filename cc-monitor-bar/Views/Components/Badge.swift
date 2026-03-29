import SwiftUI

/// 徽章/标签 — 用于模型标识、状态标记
struct Badge: View {
    let text: String
    var color: Color = Color(nsColor: .systemBlue)

    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(color)
            .padding(.vertical, DesignTokens.badgePaddingV)
            .padding(.horizontal, DesignTokens.badgePaddingH)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.radiusSM)
                    .fill(color.opacity(0.15))
            )
    }
}
