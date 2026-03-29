import SwiftUI

/// 数据设置分区 — 刷新频率、数据保留
struct DataSection: View {
    @ObservedObject var preferences: AppPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingLG) {
            // 刷新频率
            VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                Text("数据刷新")
                    .font(.headline)

                FrequencySlider(value: Binding(
                    get: { preferences.refreshInterval },
                    set: { preferences.refreshInterval = $0; preferences.save() }
                ))
            }

            Divider()

            // 数据保留
            VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                Text("数据保留")
                    .font(.headline)

                Picker("保留期限", selection: Binding(
                    get: { preferences.dataRetentionPolicy },
                    set: { preferences.dataRetentionPolicy = $0; preferences.save() }
                )) {
                    ForEach(DataRetentionPolicy.allCases, id: \.self) { policy in
                        Text(policy.displayName).tag(policy)
                    }
                }
                .pickerStyle(.segmented)
            }

            Divider()

            // 存储位置
            VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                Text("存储位置")
                    .font(.headline)

                HStack {
                    Text(preferences.sqlitePath)
                        .font(.caption)
                        .foregroundColor(Color(nsColor: .secondaryLabelColor))
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    Button("在 Finder 中显示") {
                        let url = URL(fileURLWithPath: preferences.sqlitePath)
                        NSWorkspace.shared.selectFile(url.deletingLastPathComponent().path, inFileViewerRootedAtPath: "")
                    }
                    .font(.caption)
                }
            }
        }
    }
}
