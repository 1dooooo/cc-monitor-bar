# P5: 时间线视图重构 — 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 适配时间线视图到 P1 设计系统，统一组件样式，使用 ThemeColors 和 DesignTokens。

**Architecture:** 更新 TimelineView、TimelineEventRow 使用新设计系统 Token。移除硬编码颜色，使用 ThemeColors 状态色映射。TimelineEvent 模型保持不变。

**Tech Stack:** SwiftUI, P1 DesignTokens & ThemeColors

**前置依赖:** P1 设计系统, P3 组件库（SessionRow, Badge）

---

## 文件结构

| 操作 | 文件路径 | 职责 |
|------|---------|------|
| 修改 | `cc-monitor-bar/Views/Timeline/TimelineView.swift` | 适配设计系统 |
| 修改 | `cc-monitor-bar/Views/Timeline/TimelineEvent.swift` | 使用 ThemeColors 状态色 |
| 修改 | `cc-monitor-bar/Views/Timeline/SnapshotDetail.swift` | 适配设计系统 |

---

### Task 1: 更新 TimelineEvent 使用 ThemeColors

**Files:**
- Modify: `cc-monitor-bar/Views/Timeline/TimelineEvent.swift`

- [ ] **Step 1: 更新事件类型的颜色映射**

将 `TimelineEvent` 中硬编码的颜色改为 ThemeColors：

```swift
// 原来的（示例）:
// sessionStart -> Color.green
// sessionEnd   -> Color.red
// toolPeak     -> Color.orange

// 改为:
extension TimelineEvent.EventType {
    var color: Color {
        switch self {
        case .sessionStart: return ThemeColors.active   // systemGreen
        case .sessionEnd:   return ThemeColors.muted    // systemGray
        case .toolPeak:     return ThemeColors.info     // systemBlue
        case .message:      return ThemeColors.info
        }
    }

    var icon: String {
        switch self {
        case .sessionStart: return "play.circle.fill"
        case .sessionEnd:   return "stop.circle"
        case .toolPeak:     return "wrench.and.screwdriver.fill"
        case .message:      return "bubble.left.fill"
        }
    }
}
```

更新 `TimelineEventRow` 使用 DesignTokens：

- 圆点尺寸：`DesignTokens.statusDotSize`
- 连接线颜色：`ThemeColors.divider(theme)` 或 `Color(.separator).opacity(0.3)`
- 间距：`DesignTokens.spacingMD`
- 字体层次：标题 `.subheadline`，副标题 `.caption2`，时间 `.caption2`
- 悬浮背景：`ThemeColors.cardBackground(theme)`

- [ ] **Step 2: 编译验证**

Run: `xcodebuild -project cc-monitor-bar.xcodeproj -scheme cc-monitor-bar build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: 提交**

```bash
git add cc-monitor-bar/Views/Timeline/TimelineEvent.swift
git commit -m "refactor: TimelineEvent 使用 ThemeColors 状态色映射"
```

---

### Task 2: 更新 TimelineView 使用设计系统 Token

**Files:**
- Modify: `cc-monitor-bar/Views/Timeline/TimelineView.swift`

- [ ] **Step 1: 更新 TimelineView 布局和样式**

主要变更点：
- 顶部日期导航：使用 `DesignTokens.spacingMD` 间距
- 日/周/月 Segmented：使用 `.pickerStyle(.segmented)`
- 事件列表区域：使用 `DesignTokens.spacingMD` 事件间距
- 空状态：使用 `DesignTokens.spacingXL` padding
- 整体背景：`GlassBackground()`
- frame：从硬编码改为 `minWidth: 320, minHeight: 480`
- 移除硬编码的 `Color.green`、`Color.orange` 等，使用 `event.type.color`

- [ ] **Step 2: 编译验证**

Run: `xcodebuild -project cc-monitor-bar.xcodeproj -scheme cc-monitor-bar build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: 提交**

```bash
git add cc-monitor-bar/Views/Timeline/TimelineView.swift
git commit -m "refactor: TimelineView 适配设计系统 Token"
```

---

### Task 3: 更新 SnapshotDetail 使用设计系统

**Files:**
- Modify: `cc-monitor-bar/Views/Timeline/SnapshotDetail.swift`

- [ ] **Step 1: 更新 SnapshotDetail 样式**

主要变更点：
- 标题栏关闭按钮使用 `.buttonStyle(.plain)`
- 详情行（DetailRow）使用 `DesignTokens.spacingSM` 间距
- 移除硬编码 `"glm-5.1"` 模型名（从实际数据获取）
- Token 统计卡片使用 `StatCard` 组件
- 背景使用 `GlassBackground()`

- [ ] **Step 2: 编译验证**

Run: `xcodebuild -project cc-monitor-bar.xcodeproj -scheme cc-monitor-bar build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: 运行验证 + 提交**

手动验证时间线视图显示正常，事件颜色正确，详情弹窗正常。

```bash
git add cc-monitor-bar/Views/Timeline/SnapshotDetail.swift
git commit -m "refactor: SnapshotDetail 适配设计系统"
```
