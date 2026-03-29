import SwiftUI
#if canImport(Charts)
import Charts
#endif

struct TokenChart: View {
    let data: [DailyStats]

    var body: some View {
        if #available(macOS 14.0, *) {
            chartsContent
        } else {
            fallbackContent
        }
    }

    @available(macOS 14.0, *)
    private var chartsContent: some View {
        Chart(data) { stat in
            BarMark(
                x: .value("日期", stat.formattedDate),
                y: .value("Token", stat.totalTokens)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .frame(height: 120)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                if let tokenCount = value.as(Int64.self) {
                    AxisGridLine()
                    AxisValueLabel {
                        Text(formatTokenCount(tokenCount))
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: 1)) { _ in
                AxisValueLabel()
                    .font(.system(size: 9))
            }
        }
    }

    private var fallbackContent: some View {
        VStack(spacing: 3) {
            ForEach(data) { stat in
                HStack(spacing: 4) {
                    Text(stat.formattedDate)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .frame(width: 32, alignment: .leading)

                    GeometryReader { geo in
                        let maxValue = data.map(\.totalTokens).max() ?? 1
                        let width = geo.size.width * CGFloat(stat.totalTokens) / CGFloat(maxValue)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(2, width), height: 14)
                    }
                    .frame(height: 14)

                    Text(formatTokenCount(stat.totalTokens))
                        .font(.system(size: 9))
                        .monospacedDigit()
                        .frame(width: 40, alignment: .trailing)
                }
            }
        }
        .frame(height: 120)
    }

    private func formatTokenCount(_ count: Int64) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.0fK", Double(count) / 1_000)
        } else {
            return "\(count)"
        }
    }
}
