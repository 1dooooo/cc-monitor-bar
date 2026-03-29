# P3: 极简视图重构 — 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 重构 MinimalView，新增会话钻取详情交互（点击活跃会话→查看该会话专属数据→ESC/✕返回），所有组件使用 P1 设计系统 Token。

**Architecture:** MinimalView 新增 `@State private var selectedSession: Session?` 管理钻取状态。默认状态显示"今日总览"；点击活跃会话后切换为"会话详情"面板，标题栏变为会话名+模型Badge+✕。通过 `.onKeyPress(.escape)` 监听键盘退出。抽取 `StatCard`、`Badge`、`ProgressBar`、`ToolTagList` 为独立可复用组件。

**Tech Stack:** SwiftUI, P1 DesignTokens & ThemeColors

**前置依赖:** P1 设计系统基础

---

## 文件结构

| 操作 | 文件路径 | 职责 |
|------|---------|------|
| 创建 | `cc-monitor-bar/Views/Components/StatCard.swift` | 统计卡片（数值型/图标型/进度型） |
| 创建 | `cc-monitor-bar/Views/Components/Badge.swift` | 徽章/标签组件 |
| 创建 | `cc-monitor-bar/Views/Components/ProgressBar.swift` | 进度条（标准/紧凑/多段） |
| 创建 | `cc-monitor-bar/Views/Components/ToolTagList.swift` | 工具调用标签列表 |
| 创建 | `cc-monitor-bar/Views/Components/SessionRow.swift` | 会话行组件（活跃/历史/选中态） |
| 重写 | `cc-monitor-bar/Views/Minimal/MinimalView.swift` | 极简视图主入口，包含钻取逻辑 |
| 删除 | `cc-monitor-bar/Views/Minimal/CurrentSessionCard.swift` | 功能合并到 SessionRow |
| 删除 | `cc-monitor-bar/Views/Minimal/HistoryList.swift` | 功能合并到 SessionRow |

---

### Task 1: 创建 StatCard 组件

**Files:**
- Create: `cc-monitor-bar/Views/Components/StatCard.swift`

- [ ] **Step 1: 编写 StatCard**

```swift
import SwiftUI

/// 统计卡片 — 三种变体
struct StatCard: View {
    let label: String
    let value: String
    var subtitle: String? = nil
    var trend: String? = nil
    var trendColor: Color = ThemeColors.active
    var icon: String? = nil
    var progress: Double? = nil  // 0.0 - 1.0
    var progressColor: Color = ThemeColors.info

    @Environment(\.colorTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            // 顶部：标签 + 可选图标/状态点
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundColor(Color(.secondaryLabelColor))
                Spacer()
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                        .foregroundColor(Color(.tertiaryLabelColor))
                }
            }

            // 数值
            Text(value)
                .font(.title3.bold)
                .monospacedDigit()
                .lineLimit(1)

            // 底部：趋势 or 副标题 or 进度条
            if let trend {
                HStack(spacing: 2) {
                    Text(trend)
                        .font(.caption)
                        .foregroundColor(trendColor)
                }
            } else if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(Color(.tertiaryLabelColor))
            }

            if let progress {
                ProgressBar(value: progress, color: progressColor)
            }
        }
        .padding(DesignTokens.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.radiusMD)
                .fill(ThemeColors.cardBackground(theme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.radiusMD)
                .stroke(ThemeColors.cardBorder(theme), lineWidth: 1)
        )
    }
}
```

- [ ] **Step 2: 编译验证**

Run: `xcodebuild -project cc-monitor-bar.xcodeproj -scheme cc-monitor-bar build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED（此时 ProgressBar 尚未创建，先创建一个临时桩）

> **注意**：此步骤会因 ProgressBar 未创建而失败。应先创建 ProgressBar（Task 3），或在此处先注释掉 `progress` 相关代码。建议按 Task 3 → Task 1 的顺序执行。

- [ ] **Step 3: 提交**

```bash
git add cc-monitor-bar/Views/Components/StatCard.swift
git commit -m "feat: 添加 StatCard 统计卡片组件"
```

---

### Task 2: 创建 Badge 组件

**Files:**
- Create: `cc-monitor-bar/Views/Components/Badge.swift`

- [ ] **Step 1: 编写 Badge**

```swift
import SwiftUI

/// 徽章/标签 — 用于模型标识、状态标记、数据分类
struct Badge: View {
    let text: String
    var color: Color = Color(.systemBlue)

    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(color)
            .padding(.vertical, DesignTokens.badgePaddingV)
            .padding(.horizontal, DesignTokens.badgePaddingH)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.radiusSM)
                    .fill(color.opacity(0.15))
            )
    }
}
```

- [ ] **Step 2: 编译验证**

Run: `xcodebuild -project cc-monitor-bar.xcodeproj -scheme cc-monitor-bar build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: 提交**

```bash
git add cc-monitor-bar/Views/Components/Badge.swift
git commit -m "feat: 添加 Badge 徽章组件"
```

---

### Task 3: 创建 ProgressBar 组件

**Files:**
- Create: `cc-monitor-bar/Views/Components/ProgressBar.swift`

- [ ] **Step 1: 编写 ProgressBar**

```swift
import SwiftUI

/// 进度条 — 三种变体
struct ProgressBar: View {
    var value: Double = 0.0         // 0.0 - 1.0
    var color: Color = Color(.systemBlue)
    var height: CGFloat = 4
    var showLabel: Bool = false
    var label: String? = nil

    @Environment(\.colorTheme) private var theme

    var body: some View {
        VStack(spacing: 4) {
            if showLabel, let label {
                HStack {
                    Text(label)
                        .font(.caption)
                        .foregroundColor(Color(.secondaryLabelColor))
                    Spacer()
                    Text("\(Int(value * 100))%")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundColor(Color(.secondaryLabelColor))
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // 轨道
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(Color(.separator).opacity(0.5))

                    // 填充
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(color)
                        .frame(width: max(0, geo.size.width * CGFloat(value)))
                }
            }
            .frame(height: height)
        }
    }
}

/// 多段进度条 — 多类别对比
struct MultiSegmentBar: View {
    let segments: [(label: String, value: Double, color: Color)]
    var height: CGFloat = 6

    @Environment(\.colorTheme) private var theme

    private var total: Double {
        segments.map(\.value).reduce(0, +)
    }

    var body: some View {
        VStack(spacing: 4) {
            // 进度条
            GeometryReader { geo in
                HStack(spacing: 0) {
                    ForEach(segments.indices, id: \.self) { i in
                        let seg = segments[i]
                        let width = total > 0 ? geo.size.width * CGFloat(seg.value / total) : 0
                        RoundedRectangle(cornerRadius: i == 0 || i == segments.count - 1 ? height / 2 : 0)
                            .fill(seg.color)
                            .frame(width: max(0, width))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: height / 2))
            }
            .frame(height: height)

            // 图例
            HStack(spacing: DesignTokens.spacingMD) {
                ForEach(segments.indices, id: \.self) { i in
                    let seg = segments[i]
                    HStack(spacing: 4) {
                        Circle()
                            .fill(seg.color)
                            .frame(width: 6, height: 6)
                        Text(seg.label)
                            .font(.caption2)
                            .foregroundColor(Color(.tertiaryLabelColor))
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 2: 编译验证**

Run: `xcodebuild -project cc-monitor-bar.xcodeproj -scheme cc-monitor-bar build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: 提交**

```bash
git add cc-monitor-bar/Views/Components/ProgressBar.swift
git commit -m "feat: 添加 ProgressBar 和 MultiSegmentBar 组件"
```

---

### Task 4: 创建 ToolTagList 和 SessionRow 组件

**Files:**
- Create: `cc-monitor-bar/Views/Components/ToolTagList.swift`
- Create: `cc-monitor-bar/Views/Components/SessionRow.swift`

- [ ] **Step 1: 编写 ToolTagList**

```swift
import SwiftUI

/// 工具调用标签列表
struct ToolTagList: View {
    let tools: [(name: String, count: Int)]

    @Environment(\.colorTheme) private var theme

    var body: some View {
        FlexWrapLayout(spacing: DesignTokens.spacingXS) {
            ForEach(tools.indices, id: \.self) { i in
                let tool = tools[i]
                HStack(spacing: 3) {
                    Text(tool.name)
                        .font(.caption2)
                    Text("×\(tool.count)")
                        .font(.caption2)
                        .foregroundColor(Color(.tertiaryLabelColor))
                }
                .padding(.vertical, 2)
                .padding(.horizontal, DesignTokens.spacingSM)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.radiusSM)
                        .fill(Color(.separator).opacity(0.3))
                )
            }
        }
    }
}

/// 简易 Flex Wrap 布局
struct FlexWrapLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            rowHeight = max(rowHeight, size.height)
            currentX += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: currentY + rowHeight), positions)
    }
}
```

- [ ] **Step 2: 编写 SessionRow**

```swift
import SwiftUI

/// 会话行 — 三种状态
struct SessionRow: View {
    let session: Session
    var usage: SessionUsage?
    var isSelected: Bool = false
    var onTap: (() -> Void)? = nil

    @Environment(\.colorTheme) private var theme

    private var statusColor: Color {
        session.isRunning ? ThemeColors.active : ThemeColors.muted
    }

    var body: some View {
        HStack(spacing: DesignTokens.spacingSM) {
            // 状态指示点
            Circle()
                .fill(statusColor)
                .frame(width: DesignTokens.statusDotSize, height: DesignTokens.statusDotSize)

            // 信息区
            VStack(alignment: .leading, spacing: 2) {
                Text(session.projectPath.lastPathComponent)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    if let model = usage?.models.sorted(by: { $0.value > $1.value }).first?.key {
                        Text(model)
                            .font(.caption2)
                    }
                    Text("·")
                        .font(.caption2)
                        .foregroundColor(Color(.tertiaryLabelColor))
                    Text(session.isRunning ? "进行中 · \(session.durationFormatted)" : "已结束")
                        .font(.caption2)
                }
                .foregroundColor(Color(.tertiaryLabelColor))
            }

            Spacer()

            // 数值区
            if let usage, usage.totalTokens > 0 {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(formatTokens(usage.totalTokens))
                        .font(.subheadline.bold())
                        .foregroundColor(session.isRunning ? ThemeColors.accent(theme) : Color(.secondaryLabelColor))
                    Text("tokens")
                        .font(.caption2)
                        .foregroundColor(Color(.tertiaryLabelColor))
                }
            }
        }
        .padding(.horizontal, DesignTokens.spacingMD)
        .padding(.vertical, DesignTokens.spacingSM)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.radiusMD)
                .fill(isSelected ? ThemeColors.accent(theme).opacity(0.1) : (session.isRunning ? Color(.controlBackgroundColor).opacity(0.5) : Color(.controlBackgroundColor).opacity(0.25)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.radiusMD)
                .stroke(isSelected ? ThemeColors.accent(theme).opacity(0.4) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
    }

    private func formatTokens(_ n: Int64) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }
}
```

- [ ] **Step 3: 编译验证**

Run: `xcodebuild -project cc-monitor-bar.xcodeproj -scheme cc-monitor-bar build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED（SessionUsage 类型需要在 AppState 或 Models 中可见）

- [ ] **Step 4: 提交**

```bash
git add cc-monitor-bar/Views/Components/ToolTagList.swift cc-monitor-bar/Views/Components/SessionRow.swift
git commit -m "feat: 添加 ToolTagList 和 SessionRow 可复用组件"
```

---

### Task 5: 重写 MinimalView — 双态布局

**Files:**
- Rewrite: `cc-monitor-bar/Views/Minimal/MinimalView.swift`

- [ ] **Step 1: 重写 MinimalView**

```swift
import SwiftUI

struct MinimalView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorTheme) private var theme

    /// 钻取状态：nil = 今日总览，非 nil = 会话详情
    @State private var selectedSession: Session?

    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.spacingMD) {
                if let session = selectedSession {
                    sessionDetailView(session)
                } else {
                    todayOverview
                }
            }
            .padding(DesignTokens.spacingLG)
        }
        .frame(minWidth: 320, minHeight: 480)
        .background(GlassBackground())
        .onKeyPress(.escape) {
            if selectedSession != nil {
                selectedSession = nil
                return .handled
            }
            return .ignored
        }
    }

    // MARK: - 今日总览

    private var todayOverview: some View {
        Group {
            // 顶栏
            HStack {
                Text("今日总览")
                    .font(.headline)
                Spacer()
                Text(Date.now, style: .time)
                    .font(.caption)
                    .foregroundColor(Color(.tertiaryLabelColor))
            }

            // 统计卡片 2x1
            if let stats = appState.todayStats {
                HStack(spacing: DesignTokens.spacingSM) {
                    StatCard(label: "TOKEN", value: formatNumber(stats.totalTokens))
                    StatCard(label: "会话", value: "\(stats.sessionCount)")
                }
            }

            // 模型分布
            if let stats = appState.todayStats, !stats.modelBreakdown.isEmpty {
                VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                    Text("模型分布")
                        .font(.caption)
                        .foregroundColor(Color(.secondaryLabelColor))

                    let total = stats.modelBreakdown.map(\.tokens).reduce(Int64(0), +)
                    MultiSegmentBar(
                        segments: stats.modelBreakdown.prefix(4).map { item in
                            let fraction = total > 0 ? Double(item.tokens) / Double(total) : 0
                            return (label: item.name, value: fraction, color: ModelColors.color(for: item.name))
                        }
                    )
                }
            }

            // 分割
            Divider()

            // 活跃会话
            if !appState.currentSessions.isEmpty {
                VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                    HStack {
                        Text("活跃会话")
                            .font(.caption)
                            .foregroundColor(Color(.secondaryLabelColor))
                        Text("（点击查看详情）")
                            .font(.caption2)
                            .foregroundColor(Color(.tertiaryLabelColor))
                    }

                    ForEach(appState.currentSessions) { session in
                        SessionRow(
                            session: session,
                            usage: appState.sessionUsages[session.id],
                            isSelected: selectedSession?.id == session.id,
                            onTap: { toggleSession(session) }
                        )
                    }
                }
            } else if !appState.isLoading {
                emptyState
            }

            // 工具调用标签
            if let stats = appState.todayStats, stats.toolCallCount > 0 {
                Divider()
                VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                    Text("工具调用")
                        .font(.caption)
                        .foregroundColor(Color(.secondaryLabelColor))
                    // 简化显示，使用总计数
                    HStack(spacing: DesignTokens.spacingXS) {
                        Image(systemName: "wrench.fill")
                            .font(.caption2)
                            .foregroundColor(ThemeColors.warning)
                        Text("\(stats.toolCallCount) 次")
                            .font(.caption)
                    }
                }
            }

            if appState.isLoading {
                ProgressView()
                    .padding()
            }
        }
    }

    // MARK: - 会话详情

    private func sessionDetailView(_ session: Session) -> some View {
        Group {
            // 标题栏：会话名 + 模型Badge + ✕
            HStack(spacing: DesignTokens.spacingSM) {
                Circle()
                    .fill(ThemeColors.active)
                    .frame(width: DesignTokens.statusDotSize, height: DesignTokens.statusDotSize)

                Text(session.projectPath.lastPathComponent)
                    .font(.headline)

                if let model = appState.sessionUsages[session.id]?.models.sorted(by: { $0.value > $1.value }).first?.key {
                    Badge(text: model, color: ModelColors.color(for: model))
                }

                Spacer()

                Button(action: { selectedSession = nil }) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(Color(.tertiaryLabelColor))
                }
                .buttonStyle(.plain)
            }

            let usage = appState.sessionUsages[session.id]

            // 统计卡片
            HStack(spacing: DesignTokens.spacingSM) {
                StatCard(label: "TOKEN", value: usage.map { formatNumber($0.totalTokens) } ?? "—")
                StatCard(label: "持续", value: session.durationFormatted)
            }

            // 工具调用
            if let usage, usage.toolCallCount > 0 {
                VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                    Text("工具调用")
                        .font(.caption)
                        .foregroundColor(Color(.secondaryLabelColor))

                    HStack(spacing: DesignTokens.spacingXS) {
                        Image(systemName: "wrench.fill")
                            .font(.caption2)
                            .foregroundColor(ThemeColors.warning)
                        Text("\(usage.toolCallCount) 次")
                            .font(.caption)
                    }
                }
            }

            // 消息分布
            if let usage {
                Divider()
                Text("消息分布")
                    .font(.caption)
                    .foregroundColor(Color(.secondaryLabelColor))

                HStack(spacing: DesignTokens.spacingSM) {
                    StatCard(label: "用户", value: "\(usage.messageCount)")
                    StatCard(label: "助手", value: "\(usage.toolCallCount)")
                }
            }

            // 返回提示
            HStack {
                Spacer()
                Text("按 ⎋ Esc 或点击 ✕ 返回")
                    .font(.caption2)
                    .foregroundColor(Color(.tertiaryLabelColor))
                Spacer()
            }
            .padding(.top, DesignTokens.spacingXS)
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: DesignTokens.animationNormal), value: selectedSession?.id)
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: DesignTokens.spacingSM) {
            Image(systemName: "moon.zzz")
                .font(.system(size: 32))
                .foregroundColor(Color(.tertiaryLabelColor))
            Text("无活跃会话")
                .font(.subheadline)
                .foregroundColor(Color(.secondaryLabelColor))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignTokens.spacingXL)
    }

    // MARK: - Actions

    private func toggleSession(_ session: Session) {
        withAnimation(.easeInOut(duration: DesignTokens.animationNormal)) {
            if selectedSession?.id == session.id {
                selectedSession = nil
            } else {
                selectedSession = session
            }
        }
    }

    private func formatNumber(_ n: Int64) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }
}
```

- [ ] **Step 2: 编译验证**

Run: `xcodebuild -project cc-monitor-bar.xcodeproj -scheme cc-monitor-bar build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: 运行应用验证**

Run: `open cc-monitor-bar.xcodeproj`
手动验证：
1. 极简视图显示"今日总览"
2. 点击活跃会话，切换到"会话详情"
3. 按 ESC 键返回"今日总览"
4. 点击 ✕ 按钮返回
5. 再次点击同一会话（toggle）返回

- [ ] **Step 4: 提交**

```bash
git add cc-monitor-bar/Views/Minimal/MinimalView.swift
git commit -m "feat: 重写 MinimalView，支持会话钻取详情和 ESC 返回"
```

---

### Task 6: 清理旧组件文件

**Files:**
- Delete: `cc-monitor-bar/Views/Minimal/CurrentSessionCard.swift`
- Delete: `cc-monitor-bar/Views/Minimal/HistoryList.swift`

- [ ] **Step 1: 删除旧文件**

确认 `CurrentSessionCard` 和 `HistorySessionRow` 的功能已完全由 `SessionRow` 和新的 `MinimalView` 替代后：

```bash
rm cc-monitor-bar/Views/Minimal/CurrentSessionCard.swift
rm cc-monitor-bar/Views/Minimal/HistoryList.swift
```

同时在 Xcode 中移除这两个文件的引用（从 project navigator 中 Delete → Move to Trash）。

- [ ] **Step 2: 编译验证**

Run: `xcodebuild -project cc-monitor-bar.xcodeproj -scheme cc-monitor-bar build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED（无未解析引用）

- [ ] **Step 3: 提交**

```bash
git add -A cc-monitor-bar/Views/Minimal/
git commit -m "chore: 删除已合并的 CurrentSessionCard 和 HistoryList"
```

---

### Task 7: 将新组件文件加入 Xcode 工程

**Files:**
- Modify: `cc-monitor-bar.xcodeproj/project.pbxproj`

- [ ] **Step 1: 在 Xcode 中添加新文件引用**

在 Xcode 中：
1. 右键 `Views/Components` 组 → "Add Files to cc-monitor-bar"
2. 选择 `StatCard.swift`、`Badge.swift`、`ProgressBar.swift`、`ToolTagList.swift`、`SessionRow.swift`
3. 确保目标为 cc-monitor-bar target

- [ ] **Step 2: 完整编译 + 运行验证**

Run: `xcodebuild -project cc-monitor-bar.xcodeproj -scheme cc-monitor-bar build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: 提交工程变更**

```bash
git add cc-monitor-bar.xcodeproj/project.pbxproj
git commit -m "chore: 将新组件文件加入 Xcode 工程"
```
