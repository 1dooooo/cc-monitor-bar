# P6: 快捷键 & TipKit 首次引导 — 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 实现全局快捷键（⌘1/2/3 切换视图、⌘, 打开设置、⌘R 刷新、⎋ Esc 退出详情）和 TipKit 首次使用引导提示。

**Architecture:** 使用 `NSEvent.addGlobalMonitorForEvents` 监听全局键盘事件（应用非激活状态也能响应）。Popover 内通过 SwiftUI `.onKeyPress(.escape)` 处理 ESC 退出详情。TipKit 使用 Apple 原生框架，定义 3 个 Tip（会话钻取、主题预览、看板导航），每个最多显示 2-3 次。

**Tech Stack:** NSEvent global monitor, SwiftUI onKeyPress, Apple TipKit (macOS 14+)

**前置依赖:** P1 设计系统, P2 设置窗口, P3 极简视图, P4 看板视图

---

## 文件结构

| 操作 | 文件路径 | 职责 |
|------|---------|------|
| 创建 | `cc-monitor-bar/Services/KeyboardShortcuts.swift` | 全局快捷键监听与分发 |
| 创建 | `cc-monitor-bar/Views/Onboarding/AppTips.swift` | TipKit Tip 定义 |
| 创建 | `cc-monitor-bar/Views/Onboarding/TipModifiers.swift` | TipKit 视图修饰符 |
| 修改 | `cc-monitor-bar/App/AppDelegate.swift` | 注册快捷键监听 |
| 修改 | `cc-monitor-bar/App/AppState.swift` | 添加 currentView 切换方法 |
| 修改 | `cc-monitor-bar/Views/ContentView.swift` | 监听视图切换 |
| 修改 | `cc-monitor-bar/Settings/AppPreferences.swift` | 添加快捷键开关 |

---

### Task 1: 创建全局快捷键服务

**Files:**
- Create: `cc-monitor-bar/Services/KeyboardShortcuts.swift`

- [ ] **Step 1: 编写 KeyboardShortcuts**

```swift
import AppKit
import SwiftUI

/// 全局快捷键管理器
final class KeyboardShortcuts {
    static let shared = KeyboardShortcuts()

    private var globalMonitor: Any?
    private var localMonitor: Any?

    // 回调
    var onSwitchToMinimal: (() -> Void)?
    var onSwitchToDashboard: (() -> Void)?
    var onSwitchToTimeline: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onRefreshData: (() -> Void)?

    private init() {}

    func start() {
        // 全局监听（应用在后台时也能响应）
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }

        // 本地监听（应用在前台时）
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if let self, self.handleKeyEvent(event) {
                return nil // 已处理
            }
            return event
        }
    }

    func stop() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    @discardableResult
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let key = event.charactersIgnoringModifiers?.lowercased()

        // ⌘1 / ⌘2 / ⌘3 — 切换视图
        if flags.contains(.command), flags.subtracting(.command).isEmpty {
            switch key {
            case "1": onSwitchToMinimal?(); return true
            case "2": onSwitchToDashboard?(); return true
            case "3": onSwitchToTimeline?(); return true
            case ",": onOpenSettings?(); return true
            case "r": onRefreshData?(); return true
            default: break
            }
        }

        return false
    }
}
```

- [ ] **Step 2: 编译验证**

Run: `xcodebuild -project cc-monitor-bar.xcodeproj -scheme cc-monitor-bar build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: 提交**

```bash
git add cc-monitor-bar/Services/KeyboardShortcuts.swift
git commit -m "feat: 添加 KeyboardShortcuts 全局快捷键监听服务"
```

---

### Task 2: 在 AppDelegate 中注册快捷键

**Files:**
- Modify: `cc-monitor-bar/App/AppDelegate.swift`
- Modify: `cc-monitor-bar/App/AppState.swift`

- [ ] **Step 1: 在 AppState 中添加视图切换方法**

```swift
// 在 AppState 中添加:
func switchToView(_ view: DefaultView) {
    DispatchQueue.main.async {
        self.preferences.setCurrentView(view)
        self.preferences.save()
        // 发送通知让 ContentView 刷新
        NotificationCenter.default.post(name: .switchView, object: view)
    }
}

// 定义通知名
extension Notification.Name {
    static let switchView = Notification.Name("switchView")
}
```

- [ ] **Step 2: 在 AppDelegate 的 applicationDidFinishLaunching 中注册快捷键**

```swift
// 在 applicationDidFinishLaunching 末尾添加:
let shortcuts = KeyboardShortcuts.shared
shortcuts.onSwitchToMinimal = { [weak self] in
    self?.appState.switchToView(.minimal)
    self?.refreshPopoverContent()
}
shortcuts.onSwitchToDashboard = { [weak self] in
    self?.appState.switchToView(.dashboard)
    self?.refreshPopoverContent()
}
shortcuts.onSwitchToTimeline = { [weak self] in
    self?.appState.switchToView(.timeline)
    self?.refreshPopoverContent()
}
shortcuts.onOpenSettings = { [weak self] in
    self?.openSettingsItem()
}
shortcuts.onRefreshData = { [weak self] in
    self?.appState.refreshData()
}
shortcuts.start()
```

添加辅助方法：

```swift
private func refreshPopoverContent() {
    popover?.contentViewController = NSHostingController(
        rootView: ContentView()
            .environmentObject(appState)
    )
    // 如果 Popover 未显示，自动弹出
    if popover?.isShown == false, let button = statusItem?.button {
        popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
    }
}
```

- [ ] **Step 3: 在 ContentView 中监听视图切换通知**

```swift
// 在 ContentView 中添加:
.onReceive(NotificationCenter.default.publisher(for: .switchView)) { notification in
    if let view = notification.object as? DefaultView {
        withAnimation(.easeInOut(duration: DesignTokens.animationNormal)) {
            currentView = view
        }
    }
}
```

- [ ] **Step 4: 编译验证**

Run: `xcodebuild -project cc-monitor-bar.xcodeproj -scheme cc-monitor-bar build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: 运行验证**

手动验证：
1. 按 ⌘1 → Popover 切换到极简视图
2. 按 ⌘2 → Popover 切换到看板视图
3. 按 ⌘3 → Popover 切换到时间线视图
4. 按 ⌘R → 数据刷新
5. 按 ⌘, → 打开设置窗口

- [ ] **Step 6: 提交**

```bash
git add cc-monitor-bar/App/AppDelegate.swift cc-monitor-bar/App/AppState.swift cc-monitor-bar/Views/ContentView.swift
git commit -m "feat: 注册全局快捷键 ⌘1/2/3 切换视图、⌘, 设置、⌘R 刷新"
```

---

### Task 3: 创建 TipKit 引导

**Files:**
- Create: `cc-monitor-bar/Views/Onboarding/AppTips.swift`
- Create: `cc-monitor-bar/Views/Onboarding/TipModifiers.swift`

- [ ] **Step 1: 定义 Tip**

```swift
// AppTips.swift
import TipKit

/// 会话钻取引导
struct SessionDrillDownTip: Tip {
    var title: Text { "点击会话查看详情" }
    var message: Text? {
        Text("点击活跃会话可查看该会话的 Token、工具调用等数据。\n按 ⎋ Esc 返回今日总览。")
    }
    var options: [TipOption] { [MaxDisplayCount(3)] }
}

/// 主题切换引导
struct ThemePreviewTip: Tip {
    var title: Text { "切换主题即时预览" }
    var message: Text? {
        Text("在设置中切换配色主题，菜单栏弹窗会实时反映变化。")
    }
    var options: [TipOption] { [MaxDisplayCount(2)] }
}

/// 看板导航引导
struct DashboardNavTip: Tip {
    var title: Text { "滚动浏览所有数据" }
    var message: Text? {
        Text("看板视图支持滚动浏览概览、模型、会话、工具。滚动时右侧会出现锚点导航。")
    }
    var options: [TipOption] { [MaxDisplayCount(2)] }
}
```

- [ ] **Step 2: 创建视图修饰符**

```swift
// TipModifiers.swift
import SwiftUI
import TipKit

extension View {
    /// 首次使用 — 会话钻取提示
    func sessionDrillDownTip() -> some View {
        self.popoverTip(SessionDrillDownTip(), arrowEdge: .top)
    }

    /// 首次使用 — 看板导航提示
    func dashboardNavTip() -> some View {
        self.popoverTip(DashboardNavTip(), arrowEdge: .bottom)
    }
}
```

- [ ] **Step 3: 在 App 入口初始化 TipKit**

在 `CCMonitorBarApp.swift` 中：

```swift
import SwiftUI
import TipKit

@main
struct CCMonitorBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        // 初始化 TipKit
        if #available(macOS 14, *) {
            Tips.configure()
        }
    }

    var body: some Scene {
        Settings { EmptyView() }
    }
}
```

- [ ] **Step 4: 在视图中应用 Tip**

在 `MinimalView.swift` 的活跃会话列表区域添加 `.sessionDrillDownTip()`。

在 `DashboardView.swift` 的区块区域添加 `.dashboardNavTip()`。

- [ ] **Step 5: 编译验证**

Run: `xcodebuild -project cc-monitor-bar.xcodeproj -scheme cc-monitor-bar build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 6: 提交**

```bash
git add cc-monitor-bar/Views/Onboarding/ cc-monitor-bar/App/CCMonitorBarApp.swift cc-monitor-bar/Views/Minimal/MinimalView.swift cc-monitor-bar/Views/Dashboard/DashboardView.swift
git commit -m "feat: 添加 TipKit 首次使用引导（会话钻取、看板导航）"
```

---

### Task 4: 将新文件加入 Xcode 工程 + 最终验证

**Files:**
- Modify: `cc-monitor-bar.xcodeproj/project.pbxproj`

- [ ] **Step 1: 在 Xcode 中添加文件引用**

1. 右键项目导航器 → "Add Files to cc-monitor-bar"
2. 添加 `Services/KeyboardShortcuts.swift`
3. 添加 `Views/Onboarding/AppTips.swift` 和 `Views/Onboarding/TipModifiers.swift`

- [ ] **Step 2: 完整编译 + 运行验证**

Run: `xcodebuild -project cc-monitor-bar.xcodeproj -scheme cc-monitor-bar build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

手动最终验证清单：
- [ ] ⌘1/2/3 全局切换视图正常
- [ ] ⌘, 打开设置正常
- [ ] ⌘R 刷新数据正常
- [ ] 首次使用时 TipKit 提示正常出现
- [ ] ESC 在 Popover 内退出会话详情正常
- [ ] 所有视图的样式使用设计系统 Token

- [ ] **Step 3: 提交**

```bash
git add cc-monitor-bar.xcodeproj/project.pbxproj
git commit -m "chore: 将快捷键和 TipKit 文件加入 Xcode 工程"
```
