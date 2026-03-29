import SwiftUI

// MARK: - Environment Key

private struct ColorThemeKey: EnvironmentKey {
    static let defaultValue: ColorTheme = .native
}

extension EnvironmentValues {
    /// 当前配色主题，由 .themed() 修饰符注入
    var colorTheme: ColorTheme {
        get { self[ColorThemeKey.self] }
        set { self[ColorThemeKey.self] = newValue }
    }
}

// MARK: - View Modifier

struct ApplyColorTheme: ViewModifier {
    let theme: ColorTheme

    func body(content: Content) -> some View {
        content
            .environment(\.colorTheme, theme)
    }
}

extension View {
    /// 注入指定配色主题到视图树
    /// 用法: ContentView().themed(.native)
    func themed(_ theme: ColorTheme) -> some View {
        self.modifier(ApplyColorTheme(theme: theme))
    }
}
