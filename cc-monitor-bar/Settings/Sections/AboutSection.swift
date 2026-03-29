import SwiftUI

/// 关于分区 — 版本信息
struct AboutSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingLG) {
            // 应用图标和名称
            HStack(spacing: DesignTokens.spacingMD) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)

                VStack(alignment: .leading, spacing: 4) {
                    Text("cc-monitor-bar")
                        .font(.title3.bold())
                    Text("Claude Code 本地监控工具")
                        .font(.caption)
                        .foregroundColor(Color(nsColor: .secondaryLabelColor))
                }
            }

            Divider()

            // 版本信息
            VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                infoRow("版本", value: appVersion)
                infoRow("构建号", value: buildVersion)
                infoRow("运行时", value: "macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")
            }

            Divider()

            // 数据来源说明
            VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                Text("数据来源")
                    .font(.headline)

                Text("本应用仅读取 ~/.claude/ 目录下的本地文件，不调用任何远程 API。")
                    .font(.caption)
                    .foregroundColor(Color(nsColor: .secondaryLabelColor))
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var buildVersion: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundColor(Color(nsColor: .secondaryLabelColor))
            Spacer()
            Text(value)
                .font(.body)
        }
    }
}
