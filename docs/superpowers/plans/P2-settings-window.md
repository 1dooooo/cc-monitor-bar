# P2: 设置独立窗口 — 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 将设置从 Popover 内嵌改为独立悬浮 NSWindow，左侧导航 + 右侧内容布局，支持实时预览。

**Architecture:** 创建 `SettingsWindowController` 管理 NSWindow 生命周期（显示/隐藏/位置记忆）。设置内容使用 SwiftUI 的 `NavigationSplitView` 构建左导航+右内容。通过共享 `AppPreferences` 实现修改即时反映到 Popover。

**Tech Stack:** NSWindow + NSWindowController, SwiftUI NavigationSplitView, SF Symbols

**前置依赖:** P1 设计系统基础

---

## 文件结构

| 操作 | 文件路径 | 职责 |
|------|---------|------|
| 创建 | `cc-monitor-bar/Settings/SettingsWindowController.swift` | NSWindow 生命周期管理 |
| 创建 | `cc-monitor-bar/Settings/SettingsWindowContent.swift` | SwiftUI 左导航+右内容主体 |
| 创建 | `cc-monitor-bar/Settings/Sections/AppearanceSection.swift` | 外观设置（主题/图标/毛玻璃） |
| 创建 | `cc-monitor-bar/Settings/Sections/DisplaySection.swift` | 显示设置（视图/宽度/单位） |
| 创建 | `cc-monitor-bar/Settings/Sections/DataSection.swift` | 数据设置（频率/保留/开关） |
| 创建 | `cc-monitor-bar/Settings/Sections/ShortcutsSection.swift` | 快捷键设置 |
| 创建 | `cc-monitor-bar/Settings/Sections/AboutSection.swift` | 关于页面 |
| 创建 | `cc-monitor-bar/Views/Components/SFSymbolPicker.swift` | SF Symbol 选择器 |
| 修改 | `cc-monitor-bar/App/AppDelegate.swift` | 设置入口从 Popover 改为独立窗口 |
| 修改 | `cc-monitor-bar/App/AppState.swift` | 添加 popoverWidth 计算属性 |

---

## Tasks 概要

1. **创建 SettingsWindowController** — NSWindow.floating + 位置记忆 + 显示/隐藏
2. **创建 SettingsWindowContent** — NavigationSplitView 5 分区导航
3. **创建 AppearanceSection** — 三主题卡片选择 + 毛玻璃开关 + SF Symbol 选择器
4. **创建 DisplaySection** — 默认视图/宽度/单位/时间格式
5. **创建 DataSection** — 刷新频率/保留天数/开关
6. **创建 ShortcutsSection** — 快捷键列表（P6 细化自定义功能）
7. **创建 AboutSection** — 版本/许可
8. **创建 SFSymbolPicker** — 搜索 + 模糊匹配 + 预览
9. **修改 AppDelegate** — 设置入口改用 SettingsWindowController
10. **集成验证** — 打开设置、修改主题、Popover 实时反映

> 详细代码步骤在执行时展开。
