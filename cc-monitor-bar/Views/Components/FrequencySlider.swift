import SwiftUI

struct FrequencySlider: View {
    @Binding var value: TimeInterval
    @State private var isEditing: Bool = false

    private let minInterval: TimeInterval = 3.0      // 3 秒
    private let maxInterval: TimeInterval = 1800.0   // 30 分钟

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(formatInterval(minInterval))
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()

                Text(formatInterval(maxInterval))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            HStack {
                Slider(
                    value: Binding(
                        get: { logScale(value) },
                        set: { value = exp($0) }
                    ),
                    in: logScale(minInterval)...logScale(maxInterval)
                ) { editing in
                    if !editing {
                        isEditing = false
                    } else {
                        isEditing = true
                    }
                }
                .accentColor(.blue)
            }

            Text(formatInterval(value))
                .font(.caption)
                .foregroundColor(.primary)
                .monospacedDigit()
        }
    }

    private func logScale(_ value: TimeInterval) -> Double {
        return log(value)
    }

    private func expLog(_ value: Double) -> TimeInterval {
        return exp(value)
    }

    private func formatInterval(_ interval: TimeInterval) -> String {
        if interval < 60 {
            return "\(Int(interval))秒"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)分钟"
        } else {
            let hours = Int(interval / 3600)
            let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
            if minutes > 0 {
                return "\(hours)小时\(minutes)分"
            }
            return "\(hours)小时"
        }
    }
}
