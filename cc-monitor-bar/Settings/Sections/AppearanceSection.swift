import SwiftUI

/// 外观设置分区 — 主题/毛玻璃/菜单栏图标/显示模式
struct AppearanceSection: View {
    @ObservedObject var preferences: AppPreferences
    @Environment(\.colorTheme) private var currentTheme

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingLG) {
            // 1. 配色主题三选一
            themePicker

            Divider()

            // 2. 外观模式（深色/浅色/跟随系统）
            appearancePicker

            Divider()

            // 3. 毛玻璃效果
            glassToggle

            Divider()

            // 4. 菜单栏图标
            iconStylePicker

            Divider()

            // 5. 菜单栏显示模式
            // TODO: displayModePicker — 待 AppPreferences 添加 showMenuBarLabel 属性后启用
        }
    }

    // MARK: - 配色主题

    private var themePicker: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            Text("配色主题")
                .font(.headline)
            Text("切换后菜单栏弹窗即时预览")
                .font(.caption)
                .foregroundColor(Color(nsColor: .tertiaryLabelColor))

            HStack(spacing: DesignTokens.spacingMD) {
                ForEach(ColorTheme.allCases) { theme in
                    themeCard(theme)
                }
            }
        }
    }

    private func themeCard(_ theme: ColorTheme) -> some View {
        let isSelected = preferences.colorTheme == theme
        return Button(action: {
            preferences.colorTheme = theme
            preferences.save()
        }) {
            VStack(spacing: 8) {
                // 色彩预览条
                HStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(ThemeColors.cardBackground(theme))
                        .frame(height: 28)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(ThemeColors.accent(theme).opacity(0.3))
                        .frame(width: 40, height: 28)
                }

                Text(theme.displayName)
                    .font(.caption)
                    .foregroundColor(isSelected ? ThemeColors.accent(currentTheme) : Color(nsColor: .secondaryLabelColor))
            }
            .padding(DesignTokens.spacingSM)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.radiusMD)
                    .fill(isSelected ? ThemeColors.accent(currentTheme).opacity(0.1) : Color(nsColor: .controlBackgroundColor).opacity(0.3))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.radiusMD)
                    .stroke(isSelected ? ThemeColors.accent(currentTheme) : Color(nsColor: .separatorColor), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 外观模式

    private var appearancePicker: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            Text("外观模式")
                .font(.headline)

            Picker("外观", selection: $preferences.appearanceMode) {
                ForEach(AppearanceMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: preferences.appearanceMode) { _ in
                preferences.save()
            }
        }
    }

    // MARK: - 毛玻璃效果

    private var glassToggle: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            Text("毛玻璃效果")
                .font(.headline)

            HStack {
                Text("启用毛玻璃背景")
                    .font(.body)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { preferences.colorTheme == .frosted },
                    set: { isOn in
                        preferences.colorTheme = isOn ? .frosted : .native
                        preferences.save()
                    }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
            }

            Text("浅色模式下自动关闭毛玻璃效果")
                .font(.caption)
                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
        }
    }

    // MARK: - 菜单栏图标

    private var iconStylePicker: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            Text("菜单栏图标")
                .font(.headline)

            HStack(spacing: DesignTokens.spacingMD) {
                ForEach(IconStyle.allCases) { style in
                    iconButton(style)
                }
            }
        }
    }

    private func iconButton(_ style: IconStyle) -> some View {
        let isSelected = preferences.iconStyle == style
        return Button(action: {
            preferences.iconStyle = style
            preferences.save()
        }) {
            VStack(spacing: 4) {
                Image(systemName: style.systemSymbol)
                    .font(.system(size: 16))
                    .frame(width: 36, height: 36)
            }
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.radiusMD)
                    .fill(isSelected ? ThemeColors.accent(currentTheme).opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.radiusMD)
                    .stroke(isSelected ? ThemeColors.accent(currentTheme) : Color(nsColor: .separatorColor), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .help(style.displayName)
    }
}
