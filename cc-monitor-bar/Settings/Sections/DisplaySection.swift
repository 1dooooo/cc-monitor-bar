import SwiftUI

/// 显示设置分区 — 默认视图、Token 单位、时间格式
struct DisplaySection: View {
    @ObservedObject var preferences: AppPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingLG) {
            // 默认视图
            VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                Text("默认视图")
                    .font(.headline)
                Text("打开菜单栏弹窗时显示的视图")
                    .font(.caption)
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))

                Picker("默认视图", selection: Binding(
                    get: { preferences.defaultView },
                    set: { preferences.defaultView = $0; preferences.save() }
                )) {
                    ForEach(DefaultView.allCases, id: \.self) { view in
                        Text(view.displayName).tag(view)
                    }
                }
                .pickerStyle(.segmented)
            }

            Divider()

            // TODO: popover width preset — popoverWidthPreset 属性尚不存在，待后续实现

            Divider()

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
