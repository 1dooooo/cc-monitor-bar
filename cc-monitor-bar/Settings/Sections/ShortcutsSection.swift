import SwiftUI

/// 快捷键设置分区
struct ShortcutsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingLG) {
            Text("快捷键")
                .font(.headline)

            VStack(spacing: DesignTokens.spacingSM) {
                shortcutRow("切换极简视图", shortcut: "⌘1")
                shortcutRow("切换看板视图", shortcut: "⌘2")
                shortcutRow("切换时间线", shortcut: "⌘3")
                shortcutRow("打开设置", shortcut: "⌘,")
                shortcutRow("刷新数据", shortcut: "⌘R")
                shortcutRow("退出详情", shortcut: "⎋ Esc")
            }

            Divider()

            HStack {
                Spacer()
                Button("恢复默认快捷键") {
                    // TODO: 重置快捷键
                }
                .font(.caption)
                .foregroundColor(Color(nsColor: .secondaryLabelColor))
                Spacer()
            }
        }
    }

    private func shortcutRow(_ label: String, shortcut: String) -> some View {
        HStack {
            Text(label)
                .font(.body)
            Spacer()
            Text(shortcut)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.radiusSM)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.radiusSM)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                )
        }
        .padding(.vertical, 4)
    }
}
