import SwiftUI

/// 进度条 — 标准/紧凑变体
struct ProgressBar: View {
    var value: Double = 0.0  // 0.0 - 1.0
    var color: Color = Color(nsColor: .systemBlue)
    var height: CGFloat = 4
    var showLabel: Bool = false
    var labelLeft: String? = nil
    var labelRight: String? = nil

    @Environment(\.colorTheme) private var theme

    var body: some View {
        VStack(spacing: 4) {
            if showLabel {
                HStack {
                    if let labelLeft { Text(labelLeft).font(.caption).foregroundColor(Color(nsColor: .secondaryLabelColor)) }
                    Spacer()
                    if let labelRight { Text(labelRight).font(.caption).monospacedDigit().foregroundColor(Color(nsColor: .secondaryLabelColor)) }
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(ThemeColors.progressTrack(theme))
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(color)
                        .frame(width: max(0, geo.size.width * CGFloat(value)))
                }
            }
            .frame(height: height)
        }
    }
}

/// 多段进度条
struct MultiSegmentBar: View {
    let segments: [(label: String, value: Double, color: Color)]
    var height: CGFloat = 6

    private var total: Double { segments.map(\.value).reduce(0, +) }

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                HStack(spacing: 0) {
                    ForEach(0..<segments.count, id: \.self) { i in
                        let seg = segments[i]
                        let w = total > 0 ? geo.size.width * CGFloat(seg.value / total) : 0
                        seg.color
                            .frame(width: max(0, w))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: height / 2))
            }
            .frame(height: height)

            if !segments.isEmpty {
                HStack(spacing: DesignTokens.spacingMD) {
                    ForEach(0..<segments.count, id: \.self) { i in
                        let seg = segments[i]
                        HStack(spacing: 4) {
                            Circle().fill(seg.color).frame(width: 6, height: 6)
                            Text(seg.label).font(.caption2).foregroundColor(Color(nsColor: .tertiaryLabelColor))
                        }
                    }
                }
            }
        }
    }
}
