# P4: 看板视图重构 — 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 DashboardView 从 Tab 切换改为单页滚动布局，添加 FloatingNav 内嵌浮动锚点导航（滚动展开/静止收起）。

**Architecture:** 移除 `Picker(.segmented)` 和 `selectedTab` 状态，改为 `ScrollView` 垂直排列四个区块（概览→模型→会话→工具）。新增 `FloatingNav` 组件悬浮在 ScrollView 内部右侧，使用 `scrollTransition` 或 `onScrollGeometryChange`（macOS 15+）/ `PreferenceKey`（macOS 14 fallback）检测滚动状态。Scroll spy 通过检测各区块的可见性来高亮当前锚点。

**Tech Stack:** SwiftUI ScrollView, scrollTransition API, P1 DesignTokens & ThemeColors

**前置依赖:** P1 设计系统, P3 组件库（StatCard, ProgressBar, SessionRow, Badge）

---

## 文件结构

| 操作 | 文件路径 | 职责 |
|------|---------|------|
| 创建 | `cc-monitor-bar/Views/Components/FloatingNav.swift` | 浮动锚点导航组件 |
| 重写 | `cc-monitor-bar/Views/Dashboard/DashboardView.swift` | 单页滚动 + FloatingNav |
| 修改 | `cc-monitor-bar/Views/Dashboard/StatCard.swift` | 适配新设计系统 Token |
| 修改 | `cc-monitor-bar/Views/Dashboard/ModelDistribution.swift` | 使用 ThemeColors |
| 保留 | `cc-monitor-bar/Views/Dashboard/TokenChart.swift` | 保留现有图表，后续优化 |

---

### Task 1: 创建 FloatingNav 浮动导航组件

**Files:**
- Create: `cc-monitor-bar/Views/Components/FloatingNav.swift`

- [ ] **Step 1: 编写 FloatingNav**

```swift
import SwiftUI

/// 浮动锚点导航 — 内嵌在 ScrollView 内
/// 滚动时展开，静止 1.5s 后收起为小圆点
struct FloatingNav: View {
    let sections: [SectionDef]
    @Binding var activeSection: String
    var onSectionTap: (String) -> Void

    @State private var isExpanded = false
    @State private var collapseTask: DispatchWorkItem?

    struct SectionDef: Identifiable {
        let id: String
        let icon: String
        let label: String
    }

    var body: some View {
        VStack(spacing: DesignTokens.spacingXS) {
            if isExpanded {
                // 展开状态：图标 + 文字
                ForEach(sections) { section in
                    Button(action: { onSectionTap(section.id) }) {
                        HStack(spacing: 6) {
                            Text(section.icon)
                                .font(.system(size: 12))
                            Text(section.label)
                                .font(.system(size: 11))
                        }
                        .foregroundColor(activeSection == section.id ? ThemeColors.accent(theme) : Color(.secondaryLabelColor))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(activeSection == section.id ? ThemeColors.accent(theme).opacity(0.2) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            } else {
                // 收起状态：小圆点
                ForEach(sections) { section in
                    Circle()
                        .fill(activeSection == section.id ? ThemeColors.accent(theme) : Color.white.opacity(0.2))
                        .frame(width: 8, height: 8)
                }
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.radiusLG)
                .fill(Color(.windowBackgroundColor).opacity(0.85))
                .background(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.radiusLG)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .animation(.easeInOut(duration: DesignTokens.animationNormal), value: isExpanded)
        .onAppear { scheduleCollapse() }
    }

    @Environment(\.colorTheme) private var theme

    /// 通知 FloatingNav 发生了滚动，展开展示
    func notifyScroll() {
        collapseTask?.cancel()
        withAnimation(.easeInOut(duration: 0.2)) {
            isExpanded = true
        }
        scheduleCollapse()
    }

    private func scheduleCollapse() {
        collapseTask?.cancel()
        let task = DispatchWorkItem { [isExpanded] in
            guard isExpanded else { return }
            withAnimation(.easeInOut(duration: DesignTokens.animationSlow)) {
                self.isExpanded = false
            }
        }
        collapseTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: task)
    }
}
```

- [ ] **Step 2: 编译验证**

Run: `xcodebuild -project cc-monitor-bar.xcodeproj -scheme cc-monitor-bar build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: 提交**

```bash
git add cc-monitor-bar/Views/Components/FloatingNav.swift
git commit -m "feat: 添加 FloatingNav 浮动锚点导航组件"
```

---

### Task 2: 更新 DashboardStatCard 适配设计系统

**Files:**
- Modify: `cc-monitor-bar/Views/Dashboard/StatCard.swift`

- [ ] **Step 1: 重写 StatCard 使用 DesignTokens**

```swift
import SwiftUI

struct StatCard: View {
    let title: String
    let value: Int64
    var trend: String? = nil

    @Environment(\.colorTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
            Text(title)
                .font(.caption)
                .foregroundColor(Color(.secondaryLabelColor))

            Text(formatNumber(value))
                .font(.title3.bold())
                .monospacedDigit()

            if let trend {
                HStack(spacing: 2) {
                    Image(systemName: trend.hasPrefix("-") ? "arrow.down.right" : "arrow.up.right")
                        .font(.system(size: 8))
                    Text(trend)
                }
                .font(.caption)
                .foregroundColor(trend.hasPrefix("-") ? ThemeColors.error : ThemeColors.active)
            }
        }
        .padding(DesignTokens.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.radiusMD)
                .fill(ThemeColors.cardBackground(theme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.radiusMD)
                .stroke(ThemeColors.cardBorder(theme), lineWidth: 1)
        )
    }

    private func formatNumber(_ n: Int64) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }
}
```

> **注意**：此文件与 P3 创建的 `Views/Components/StatCard.swift` 同名但职责不同。Dashboard 版保留在 Dashboard 目录下。如果合并为一个组件则删除此文件，DashboardView 直接引用 Components 版。

- [ ] **Step 2: 编译验证**

Run: `xcodebuild -project cc-monitor-bar.xcodeproj -scheme cc-monitor-bar build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: 提交**

```bash
git add cc-monitor-bar/Views/Dashboard/StatCard.swift
git commit -m "refactor: DashboardStatCard 适配设计系统 Token"
```

---

### Task 3: 更新 ModelDistribution 适配设计系统

**Files:**
- Modify: `cc-monitor-bar/Views/Dashboard/ModelDistribution.swift`

- [ ] **Step 1: 重写 ModelDistribution 使用 ThemeColors 和 ProgressBar**

```swift
import SwiftUI

struct ModelUsageList: View {
    let breakdown: [(name: String, tokens: Int64)]

    @Environment(\.colorTheme) private var theme

    private var maxTokens: Int64 {
        breakdown.map(\.tokens).max() ?? 1
    }

    private var totalTokens: Int64 {
        breakdown.map(\.tokens).reduce(0, +)
    }

    var body: some View {
        VStack(spacing: DesignTokens.spacingSM) {
            ForEach(breakdown, id: \.name) { model in
                HStack(spacing: DesignTokens.spacingSM) {
                    // 模型名 + 占比
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.name)
                            .font(.caption)
                            .lineLimit(1)
                        Text("\(Int(Double(model.tokens) / Double(max(totalTokens, 1)) * 100))%")
                            .font(.caption2)
                            .foregroundColor(Color(.tertiaryLabelColor))
                    }
                    .frame(width: 80, alignment: .leading)

                    // 进度条
                    ProgressBar(
                        value: Double(model.tokens) / Double(maxTokens),
                        color: ModelColors.color(for: model.name),
                        height: 3
                    )

                    // 数值
                    Text(formatNumber(model.tokens))
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundColor(Color(.secondaryLabelColor))
                        .frame(width: 46, alignment: .trailing)
                }
            }
        }
    }

    private func formatNumber(_ n: Int64) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.0fK", Double(n) / 1_000) }
        return "\(n)"
    }
}
```

- [ ] **Step 2: 编译验证**

Run: `xcodebuild -project cc-monitor-bar.xcodeproj -scheme cc-monitor-bar build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: 提交**

```bash
git add cc-monitor-bar/Views/Dashboard/ModelDistribution.swift
git commit -m "refactor: ModelDistribution 适配设计系统，使用 ProgressBar 组件"
```

---

### Task 4: 重写 DashboardView — 单页滚动 + FloatingNav

**Files:**
- Rewrite: `cc-monitor-bar/Views/Dashboard/DashboardView.swift`

- [ ] **Step 1: 重写 DashboardView**

```swift
import SwiftUI

struct DashboardView: View {
    @ObservedObject var preferences: AppPreferences
    @EnvironmentObject var appState: AppState
    @Environment(\.colorTheme) private var theme

    @State private var activeSection: String = "overview"
    @State private var floatingNav = FloatingNav(sections: [], activeSection: .constant("overview"), onSectionTap: { _ in })

    private let sectionDefs: [FloatingNav.SectionDef] = [
        .init(id: "overview", icon: "📊", label: "概览"),
        .init(id: "models",   icon: "🤖", label: "模型"),
        .init(id: "sessions", icon: "💬", label: "会话"),
        .init(id: "tools",    icon: "🔧", label: "工具"),
    ]

    init(preferences: AppPreferences = .shared) {
        self.preferences = preferences
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // 主内容
            ScrollView {
                VStack(spacing: 0) {
                    // Sticky 顶栏
                    headerBar

                    // 各区块
                    overviewSection
                    sectionDivider

                    modelsSection
                    sectionDivider

                    sessionsSection
                    sectionDivider

                    toolsSection
                }
                .padding(.horizontal, DesignTokens.spacingLG)
                .padding(.bottom, DesignTokens.spacingXL)
                .background(GeometryReader { geo in
                    Color.clear.preference(
                        key: ScrollOffsetPreferenceKey.self,
                        value: geo.frame(in: .named("scroll")).minY
                    )
                })
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { _ in
                floatingNav.notifyScroll()
            }

            // FloatingNav（右内侧悬浮）
            VStack {
                Spacer().frame(height: 60)
                FloatingNav(
                    sections: sectionDefs,
                    activeSection: $activeSection,
                    onSectionTap: { sectionId in
                        withAnimation(.easeInOut(duration: DesignTokens.animationNormal)) {
                            // scrollTo 实现 - 使用 ScrollViewReader
                        }
                    }
                )
                Spacer()
            }
            .padding(.trailing, DesignTokens.spacingSM)
        }
        .frame(minWidth: 320, minHeight: 480)
        .background(GlassBackground())
    }

    // MARK: - 顶栏

    private var headerBar: some View {
        HStack {
            Text("数据看板")
                .font(.headline)
            Spacer()
            Text(Date.now, style: .date)
                .font(.caption)
                .foregroundColor(Color(.tertiaryLabelColor))
        }
        .padding(.vertical, DesignTokens.spacingMD)
    }

    // MARK: - 概览区块

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            sectionHeader("📊 概览")

            if let stats = appState.todayStats {
                // 2x2 统计卡
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DesignTokens.spacingSM) {
                    StatCard(title: "总 TOKEN", value: stats.totalTokens)
                    StatCard(title: "会话", value: Int64(stats.sessionCount))
                    StatCard(title: "工具调用", value: Int64(stats.toolCallCount))
                    StatCard(title: "消息", value: Int64(stats.messageCount))
                }

                // 7 日趋势迷你图
                if !stats.modelBreakdown.isEmpty {
                    modelMiniChart
                }
            } else {
                Text("暂无统计数据")
                    .font(.caption)
                    .foregroundColor(Color(.secondaryLabelColor))
                    .padding()
            }
        }
    }

    private var modelMiniChart: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            Text("模型分布")
                .font(.caption)
                .foregroundColor(Color(.secondaryLabelColor))

            let total = appState.todayStats?.modelBreakdown.map(\.tokens).reduce(Int64(0), +) ?? 0
            MultiSegmentBar(
                segments: (appState.todayStats?.modelBreakdown ?? []).prefix(4).map { item in
                    let fraction = total > 0 ? Double(item.tokens) / Double(total) : 0
                    return (label: item.name, value: fraction, color: ModelColors.color(for: item.name))
                }
            )
        }
        .padding(DesignTokens.spacingSM)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.radiusMD)
                .fill(ThemeColors.cardBackground(theme))
        )
    }

    // MARK: - 模型区块

    private var modelsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            sectionHeader("🤖 模型")

            if let stats = appState.todayStats, !stats.modelBreakdown.isEmpty {
                ModelUsageList(breakdown: stats.modelBreakdown)
            } else {
                Text("暂无模型数据")
                    .font(.caption)
                    .foregroundColor(Color(.secondaryLabelColor))
            }
        }
    }

    // MARK: - 会话区块

    private var sessionsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            sectionHeader("💬 会话")

            if !appState.currentSessions.isEmpty {
                ForEach(appState.currentSessions) { session in
                    SessionRow(
                        session: session,
                        usage: appState.sessionUsages[session.id]
                    )
                }
            } else if !appState.historySessions.isEmpty {
                ForEach(appState.historySessions.prefix(5)) { session in
                    SessionRow(session: session)
                }
            } else {
                Text("暂无会话")
                    .font(.caption)
                    .foregroundColor(Color(.secondaryLabelColor))
            }
        }
    }

    // MARK: - 工具区块

    private var toolsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            sectionHeader("🔧 工具")

            if let stats = appState.todayStats, stats.toolCallCount > 0 {
                Text("\(stats.toolCallCount) 次工具调用")
                    .font(.caption)
                // TODO: 在 P5 或后续迭代中添加工具分布条形图
            } else {
                Text("暂无工具调用数据")
                    .font(.caption)
                    .foregroundColor(Color(.secondaryLabelColor))
            }
        }
    }

    // MARK: - 辅助

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
    }

    private var sectionDivider: some View {
        Divider()
            .padding(.vertical, DesignTokens.spacingSM)
    }
}

// MARK: - Scroll Offset PreferenceKey

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
```

- [ ] **Step 2: 编译验证**

Run: `xcodebuild -project cc-monitor-bar.xcodeproj -scheme cc-monitor-bar build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: 运行应用验证**

手动验证：
1. 看板视图不再有 Tab 切换
2. 四个区块垂直排列，可滚动浏览
3. 右侧 FloatingNav 滚动时展开，静止后收起
4. 点击锚点跳转到对应区块

- [ ] **Step 4: 提交**

```bash
git add cc-monitor-bar/Views/Dashboard/DashboardView.swift
git commit -m "feat: 重写 DashboardView 为单页滚动 + FloatingNav 浮动导航"
```

---

### Task 5: 将 FloatingNav 加入 Xcode 工程 + 清理

**Files:**
- Modify: `cc-monitor-bar.xcodeproj/project.pbxproj`

- [ ] **Step 1: 在 Xcode 中添加 FloatingNav.swift**

- [ ] **Step 2: 完整编译 + 运行**

Run: `xcodebuild -project cc-monitor-bar.xcodeproj -scheme cc-monitor-bar build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: 提交**

```bash
git add cc-monitor-bar.xcodeproj/project.pbxproj
git commit -m "chore: 将 FloatingNav 加入 Xcode 工程"
```
