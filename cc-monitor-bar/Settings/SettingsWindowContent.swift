import SwiftUI

/// 设置窗口主体内容 — 左导航 + 右内容
struct SettingsWindowContent: View {
    @ObservedObject var preferences: AppPreferences

    // 选中的导航项，默认第一个
    @State private var selectedSection: SettingsSection = .appearance

    init(preferences: AppPreferences) {
        self.preferences = preferences
    }

    var body: some View {
        HStack(spacing: 0) {
            // 左侧导航栏
            VStack(alignment: .leading, spacing: 2) {
                ForEach(SettingsSection.allCases) { section in
                    Button {
                        selectedSection = section
                    } label: {
                        Label(section.title, systemImage: section.icon)
                            .font(.system(size: 12))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(
                                selectedSection == section
                                    ? Color.accentColor.opacity(0.15)
                                    : Color.clear
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(selectedSection == section ? .accentColor : .primary)
                }
                Spacer()
            }
            .padding(8)
            .frame(width: 150)
            .background(Color(nsColor: .controlBackgroundColor))

            // 分隔线
            Divider()

            // 右侧内容区
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.spacingLG) {
                    switch selectedSection {
                    case .appearance:
                        AppearanceSection(preferences: preferences)
                    case .display:
                        DisplaySection(preferences: preferences)
                    case .data:
                        DataSection(preferences: preferences)
                    case .shortcuts:
                        ShortcutsSection()
                    case .about:
                        AboutSection()
                    }
                }
                .padding(DesignTokens.spacingLG)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minWidth: 560, minHeight: 440)
    }
}

// MARK: - 设置分区枚举

enum SettingsSection: String, CaseIterable, Identifiable {
    case appearance
    case display
    case data
    case shortcuts
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appearance: return "外观"
        case .display:    return "显示"
        case .data:       return "数据"
        case .shortcuts:  return "快捷键"
        case .about:      return "关于"
        }
    }

    var icon: String {
        switch self {
        case .appearance: return "paintbrush.fill"
        case .display:    return "textframe.size"
        case .data:       return "arrow.trianglehead.2.clockwise"
        case .shortcuts:  return "keyboard"
        case .about:      return "info.circle.fill"
        }
    }
}
