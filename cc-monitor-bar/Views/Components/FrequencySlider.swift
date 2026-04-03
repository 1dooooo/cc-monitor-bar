import SwiftUI

/// 刷新频率滑块 — 10 秒到 120 秒
struct FrequencySlider: View {
    @Binding var value: TimeInterval

    var body: some View {
        VStack(spacing: 8) {
            Slider(value: $value, in: 10...120, step: 10)

            HStack {
                Text("10 秒")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(value))秒")
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
                Text("120 秒")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    FrequencySlider(value: .constant(30))
        .frame(width: 200)
        .padding()
}
