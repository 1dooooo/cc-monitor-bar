# P1: 设计系统基础 — 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立三套可切换主题的设计系统基础设施，为后续 UI 重构提供统一的颜色、间距、圆角 Token。

**Architecture:** 创建 `DesignTokens` 结构体提供间距/圆角常量，`AppTheme` 枚举管理三套配色方案，`ThemedColor` 环境键将当前主题注入 SwiftUI 视图树。当前 `Theme` 枚举（system/light/dark）是外观模式，重命名为 `AppearanceMode`；新增 `ColorTheme` 枚举（native/frosted/warm）管理配色。

**Tech Stack:** SwiftUI, AppKit NSColor 语义色, SwiftUI Material API

---

## 文件结构

| 操作 | 文件路径 | 职责 |
|------|---------|------|
| 创建 | `cc-monitor-bar/Theme/DesignTokens.swift` | 间距、圆角、字体常量 |
| 创建 | `cc-monitor-bar/Theme/ColorTheme.swift` | 三套配色方案枚举 + 颜色计算属性 |
| 创建 | `cc-monitor-bar/Theme/ThemedEnvironment.swift` | SwiftUI EnvironmentKey 注入当前主题 |
| 修改 | `cc-monitor-bar/Settings/AppPreferences.swift` | 重命名 Theme→AppearanceMode，新增 colorTheme 属性 |
| 修改 | `cc-monitor-bar/Views/Components/GlassBackground.swift` | 适配主题系统 |

---

### Task 1: 创建 DesignTokens

**Files:**
- Create: `cc-monitor-bar/Theme/DesignTokens.swift`

- [ ] **Step 1: 创建 DesignTokens 结构体**

```swift
import SwiftUI

/// 设计系统 Token — 间距、圆角、尺寸常量
enum DesignTokens {

    // MARK: - 间距

    static let spacingXS: CGFloat = 4
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 12
    static let spacingLG: CGFloat = 16
    static let spacingXL: CGFloat = 20

    // MARK: - 圆角

    static let radiusSM: CGFloat = 4
    static let radiusMD: CGFloat = 8
    static let radiusLG: CGFloat = 12
    /// 全圆角 = 50%
    static func radiusFull(height: CGFloat) -> CGFloat { height / 2 }

    // MARK: - Popover 尺寸

    static let popoverWidthStandard: CGFloat = 320
    static let popoverWidthCompact: CGFloat = 280
    static let popoverWidthWide: CGFloat = 360
    static let popoverHeight: CGFloat = 480
    static let popoverCornerRadius: CGFloat = 10

    // MARK: - 组件尺寸

    static let statusDotSize: CGFloat = 8
    static let badgePaddingV: CGFloat = 3
    static let badgePaddingH: CGFloat = 10
    static let cardPadding: CGFloat = 14
    static let sessionRowHeight: CGFloat = 44

    // MARK: - 动画

    static let animationFast: TimeInterval = 0.15
    static let animationNormal: TimeInterval = 0.25
    static let animationSlow: TimeInterval = 0.3
}
```

- [ ] **Step 2: 编译验证**

Run: `xcodebuild -project cc-monitor-bar.xcodeproj -scheme cc-monitor-bar build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: 提交**

```bash
git add cc-monitor-bar/Theme/DesignTokens.swift
git commit -m "feat: 添加 DesignTokens 设计系统常量"
```

---

### Task 2: 创建 ColorTheme 配色系统

**Files:**
- Create: `cc-monitor-bar/Theme/ColorTheme.swift`

- [ ] **Step 1: 创建 ColorTheme 枚举和颜色扩展**

```swift
import SwiftUI

// MARK: - 配色主题

/// 三套可切换的配色方案
enum ColorTheme: String, CaseIterable, Codable {
    case native = "native"
    case frosted = "frosted"
    case warm = "warm"

    var displayName: String {
        switch self {
        case .native:  return "原生自适应"
        case .frosted: return "毛玻璃通透"
        case .warm:    return "Claude 暖调"
        }
    }
}

// MARK: - 主题感知颜色

/// 根据当前 ColorTheme 返回对应的颜色
/// 用法: ThemeColors.background(appTheme)
enum ThemeColors {

    // MARK: - 背景

    static func background(_ theme: ColorTheme) -> Color {
        switch theme {
        case .native, .warm:
            return Color(.windowBackgroundColor)
        case .frosted:
            return Color.clear // 使用 Material 层
        }
    }

    static func cardBackground(_ theme: ColorTheme) -> Color {
        switch theme {
        case .native, .warm:
            return Color(.controlBackgroundColor)
        case .frosted:
            return Color.white.opacity(0.06)
        }
    }

    static func cardBorder(_ theme: ColorTheme) -> Color {
        switch theme {
        case .native, .warm:
            return Color(.separator).opacity(0.5)
        case .frosted:
            return Color.white.opacity(0.1)
        }
    }

    static func highlightBackground(_ theme: ColorTheme) -> Color {
        switch theme {
        case .native:
            return Color(.underPageBackgroundColor)
        case .frosted:
            return Color.white.opacity(0.1)
        case .warm:
            return Color.amber600.opacity(0.1)
        }
    }

    static func divider(_ theme: ColorTheme) -> Color {
        switch theme {
        case .native, .warm:
            return Color(.separator)
        case .frosted:
            return Color.white.opacity(0.08)
        }
    }

    // MARK: - 强调色

    static func accent(_ theme: ColorTheme) -> Color {
        switch theme {
        case .native:
            return Color(.systemBlue)
        case .frosted:
            return Color(.systemTeal)
        case .warm:
            return Color.amber600
        }
    }

    // MARK: - 状态色（三主题通用）

    static let active   = Color(.systemGreen)
    static let info     = Color(.systemBlue)
    static let warning  = Color(.systemOrange)
    static let error    = Color(.systemRed)
    static let muted    = Color(.systemGray)

    // MARK: - 进度条轨道

    static func progressTrack(_ theme: ColorTheme) -> Color {
        switch theme {
        case .native, .warm:
            return Color(.separator).opacity(0.5)
        case .frosted:
            return Color.white.opacity(0.08)
        }
    }

    // MARK: - 毛玻璃 Material

    static func popoverMaterial(_ theme: ColorTheme) -> Material {
        switch theme {
        case .native, .warm:
            return .hudWindow
        case .frosted:
            return .ultraThinMaterial
        }
    }

    static func cardMaterial(_ theme: ColorTheme) -> Material? {
        switch theme {
        case .native, .warm:
            return nil // 使用纯色
        case .frosted:
            return .thinMaterial
        }
    }
}

// MARK: - Claude 暖调自定义色

extension Color {
    static let amber600 = Color(red: 0.85, green: 0.47, blue: 0.02)
    static let amber500 = Color(red: 0.96, green: 0.62, blue: 0.04)
}

// MARK: - 模型颜色映射

enum ModelColors {
    static func color(for modelName: String) -> Color {
        let lower = modelName.lowercased()
        if lower.contains("sonnet") { return .systemBlue }
        if lower.contains("opus")   { return .systemTeal }
        if lower.contains("haiku")  { return .systemGreen }
        return .systemOrange
    }
}

// MARK: - 工具颜色映射

enum ToolColors {
    static func color(for toolName: String) -> Color {
        let lower = toolName.lowercased()
        if ["edit", "write", "read"].contains(where: { lower.contains($0) }) {
            return .systemBlue
        }
        if ["grep", "glob", "search"].contains(where: { lower.contains($0) }) {
            return .systemTeal
        }
        if ["bash", "shell"].contains(where: { lower.contains($0) }) {
            return .systemOrange
        }
        return .systemGray
    }
}
```

- [ ] **Step 2: 编译验证**

Run: `xcodebuild -project cc-monitor-bar.xcodeproj -scheme cc-monitor-bar build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: 提交**

```bash
git add cc-monitor-bar/Theme/ColorTheme.swift
git commit -m "feat: 添加 ColorTheme 三套配色方案和颜色映射"
```

---

### Task 3: 创建 SwiftUI 主题环境注入

**Files:**
- Create: `cc-monitor-bar/Theme/ThemedEnvironment.swift`

- [ ] **Step 1: 创建环境键和视图修饰符**

```swift
import SwiftUI

// MARK: - Environment Key

private struct ColorThemeKey: EnvironmentKey {
    static let defaultValue: ColorTheme = .native
}

extension EnvironmentValues {
    var colorTheme: ColorTheme {
        get { self[ColorThemeKey.self] }
        set { self[ColorThemeKey.self] = newValue }
    }
}

// MARK: - View Modifier

struct ApplyColorTheme: ViewModifier {
    @ObservedObject var preferences: AppPreferences
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .environment(\.colorTheme, preferences.colorTheme)
    }
}

extension View {
    /// 注入当前配色主题到视图树
    func themed(_ preferences: AppPreferences) -> some View {
        self.modifier(ApplyColorTheme(preferences: preferences))
    }
}
```

- [ ] **Step 2: 编译验证**

Run: `xcodebuild -project cc-monitor-bar.xcodeproj -scheme cc-monitor-bar build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: 提交**

```bash
git add cc-monitor-bar/Theme/ThemedEnvironment.swift
git commit -m "feat: 添加 SwiftUI 主题环境注入机制"
```

---

### Task 4: 修改 AppPreferences — 重命名 Theme 并新增 colorTheme

**Files:**
- Modify: `cc-monitor-bar/Settings/AppPreferences.swift`

- [ ] **Step 1: 将 Theme 枚举重命名为 AppearanceMode**

在 `AppPreferences.swift` 中，将现有的 `Theme` 枚举重命名为 `AppearanceMode`：

```swift
// 原来的:
enum Theme: String, CaseIterable, Codable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    ...
}

// 改为:
enum AppearanceMode: String, CaseIterable, Codable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var displayName: String {
        switch self {
        case .system: return "跟随系统"
        case .light:  return "浅色"
        case .dark:   return "深色"
        }
    }
}
```

- [ ] **Step 2: 在 AppPreferences 中新增 colorTheme 属性**

在 `AppPreferences` 类的系统设置区域添加：

```swift
// MARK: - 外观设置
@Published var appearanceMode: AppearanceMode = .system
@Published var colorTheme: ColorTheme = .native
```

在 `Keys` 枚举中添加：

```swift
static let appearanceMode = "appearanceMode"
static let colorTheme = "colorTheme"
```

在 `load()` 方法中添加：

```swift
appearanceMode = AppearanceMode(rawValue: defaults.string(forKey: Keys.appearanceMode) ?? AppearanceMode.system.rawValue) ?? .system
colorTheme = ColorTheme(rawValue: defaults.string(forKey: Keys.colorTheme) ?? ColorTheme.native.rawValue) ?? .native
```

在 `save()` 方法中添加：

```swift
defaults.set(appearanceMode.rawValue, forKey: Keys.appearanceMode)
defaults.set(colorTheme.rawValue, forKey: Keys.colorTheme)
```

将原来的 `@Published var theme: Theme = .system` 改为 `@Published var appearanceMode: AppearanceMode = .system`。

- [ ] **Step 3: 修复 SettingsView 中的 Theme 引用**

在 `SettingsView.swift` 中将所有 `Theme` 引用改为 `AppearanceMode`：

```swift
// 原来的:
Picker("主题", selection: $preferences.theme) {
    ForEach(Theme.allCases, id: \.self) { theme in
        Text(theme.displayName).tag(theme)
    }
}

// 改为:
Picker("外观", selection: $preferences.appearanceMode) {
    ForEach(AppearanceMode.allCases, id: \.self) { mode in
        Text(mode.displayName).tag(mode)
    }
}
```

- [ ] **Step 4: 编译验证**

Run: `xcodebuild -project cc-monitor-bar.xcodeproj -scheme cc-monitor-bar build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: 提交**

```bash
git add cc-monitor-bar/Settings/AppPreferences.swift cc-monitor-bar/Settings/SettingsView.swift
git commit -m "refactor: 重命名 Theme→AppearanceMode，新增 colorTheme 配色主题属性"
```

---

### Task 5: 更新 GlassBackground 适配主题系统

**Files:**
- Modify: `cc-monitor-bar/Views/Components/GlassBackground.swift`

- [ ] **Step 1: 更新 GlassBackground 使用主题感知的 Material**

```swift
import SwiftUI
import AppKit

struct GlassBackground: View {
    @Environment(\.colorTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            switch theme {
            case .native, .warm:
                VisualEffectRepresentable(material: .hudWindow)
            case .frosted:
                VisualEffectRepresentable(material: .underWindowBackground)
            }
        }
        .ignoresSafeArea()
    }
}

struct VisualEffectRepresentable: NSViewRepresentable {
    var material: NSVisualEffectView.Material

    func makeNSView(context: Context) -> NSVisualEffectView {
        let effectView = NSVisualEffectView()
        effectView.material = material
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        return effectView
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
    }
}
```

- [ ] **Step 2: 编译验证**

Run: `xcodebuild -project cc-monitor-bar.xcodeproj -scheme cc-monitor-bar build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: 提交**

```bash
git add cc-monitor-bar/Views/Components/GlassBackground.swift
git commit -m "feat: GlassBackground 适配三套配色主题"
```

---

### Task 6: 在 ContentView 和 AppDelegate 中注入主题

**Files:**
- Modify: `cc-monitor-bar/Views/ContentView.swift`
- Modify: `cc-monitor-bar/App/AppDelegate.swift`

- [ ] **Step 1: 在 ContentView 中注入主题环境**

```swift
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentView: DefaultView = .minimal

    var body: some View {
        Group {
            switch currentView {
            case .minimal:
                MinimalView()
            case .dashboard:
                DashboardView(preferences: appState.preferences)
            case .timeline:
                TimelineView(preferences: appState.preferences)
            }
        }
        .frame(width: 320, height: 480)
        .themed(appState.preferences)
        .onAppear {
            appState.preferences.load()
            currentView = appState.preferences.getCurrentView()
        }
    }
}
```

变更：frame 从 380x520 改为 320x480，添加 `.themed()` 修饰符。

- [ ] **Step 2: 在 AppDelegate 中更新 Popover 尺寸**

在 `AppDelegate.swift` 中将 popover 尺寸从 380x520 改为 320x480：

```swift
popover?.contentSize = NSSize(width: 320, height: 480)
```

同步更新 `openSettingsItem` 和 `switchView` 方法中恢复主视图时的尺寸。

- [ ] **Step 3: 编译验证**

Run: `xcodebuild -project cc-monitor-bar.xcodeproj -scheme cc-monitor-bar build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: 运行应用验证**

Run: `open cc-monitor-bar.xcodeproj`
手动验证：应用启动正常，Popover 弹出正常，尺寸变化可见。

- [ ] **Step 5: 提交**

```bash
git add cc-monitor-bar/Views/ContentView.swift cc-monitor-bar/App/AppDelegate.swift
git commit -m "feat: 注入主题系统，Popover 尺寸调整为 320×480"
```

---

### Task 7: 将 Theme 目录加入 Xcode 工程

**Files:**
- Modify: `cc-monitor-bar.xcodeproj/project.pbxproj`

- [ ] **Step 1: 在 Xcode 中添加 Theme 目录的文件引用**

由于无法通过命令行安全地修改 pbxproj，需要在 Xcode 中操作：
1. 打开 `cc-monitor-bar.xcodeproj`
2. 右键项目导航器中的 `cc-monitor-bar` 组 → "Add Files to cc-monitor-bar"
3. 选择 `Theme/` 目录下的 3 个文件
4. 勾选 "Copy items if needed"（如果提示的话），目标选 cc-monitor-bar target

- [ ] **Step 2: 完整编译验证**

Run: `xcodebuild -project cc-monitor-bar.xcodeproj -scheme cc-monitor-bar build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: 提交工程文件变更**

```bash
git add cc-monitor-bar.xcodeproj/project.pbxproj
git commit -m "chore: 将 Theme 文件加入 Xcode 工程"
```
