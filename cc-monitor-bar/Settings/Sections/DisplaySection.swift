import SwiftUI

/// 显示设置分区 — Token 单位、时间格式
struct DisplaySection: View {
    @ObservedObject var preferences: AppPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingLG) {
            // Token 显示
            VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                Text("数据显示")
                    .font(.headline)

                Toggle("紧凑格式（K/M 缩写）", isOn: Binding(
                    get: { preferences.compactFormat },
                    set: { preferences.compactFormat = $0; preferences.save() }
                ))

                Toggle("显示成本估算", isOn: Binding(
                    get: { preferences.showCostEstimate },
                    set: { preferences.showCostEstimate = $0; preferences.save() }
                ))
            }
        }
    }
}
