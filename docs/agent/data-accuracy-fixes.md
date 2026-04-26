# 数据准确性全面修复计划

> 生成时间: 2026-04-26
> 目标: 彻底修复所有假数据、误导性数据、缺失数据问题

---

## 问题清单

### P0 — 严重（显示假数据/误导性数据）

#### 1. SessionReplayView — 伪造时间线事件

**文件**: `cc-monitor-bar/Views/Sections/SessionReplayView.swift:11-19`

**问题**:
```swift
private var timelineEvents: [TimelineEvent] {
    [
        TimelineEvent(type: .user, content: "用户消息", timestamp: session.startedAt),
        TimelineEvent(type: .assistant, content: "AI 回复", timestamp: session.startedAt.addingTimeInterval(30)),
        ...
    ]
}
```
- 5 个事件全是占位符，不是真实对话内容
- 时间戳是 `startedAt + 30s/45s/60s/90s`，假的
- 用户看到"回放"功能会误以为是真实对话回放

**修复方案**: 移除时间线回放功能。删除 `timelineEvents`、`TimelineEvent`、`PlaybackControls`、`TimelineEventRow`。替换为简洁的**统计摘要视图**，直接展示来自 SQLite 的真实数据（ID、项目、运行时间、消息数、工具调用、Token 总量、Context Window 使用量）。保留底部的 `SessionDetailInfo`，移除上部播放区域。

---

#### 2. RecentSessionSection — 历史会话用量显示 `--`

**文件**: `cc-monitor-bar/Views/Sections/RecentSessionSection.swift:15`

**问题**:
```swift
ForEach(sessions.prefix(5), id: \.id) { session in
    SessionRow(session: session, usage: usages[session.id])  // usages 只有活跃会话！
}
```

- `usages` 来自 `AppState.sessionUsages`，只包含**活跃会话**的用量
- 历史会话 ID 与 `sessionUsages` 的 key 不匹配，永远命中 `nil`
- 所以历史会话的 Token 用量永远显示 `--`

**修复方案**:
- 在 `loadHistory()` 中读取完历史会话后，把每个会话的 usage 也加载进来
- 在 `AppState` 中增加一个属性 `historyUsages: [String: SessionUsage]`
- `RecentSessionSection` 改用 `historyUsages[session.id]` 获取用量

具体改动：
1. `AppState.swift` 新增 `@Published var historyUsages: [String: SessionUsage] = [:]`
2. `loadHistory()` 循环中收集 usage，赋值到 `historyUsages`
3. `MonitorView` 传参改为 `usages: historyUsages` 给 `RecentSessionSection`

---

### P1 — 重要（数据不准确）

#### 3. TrendChartSection — 过去 6 天使用 modelRatios 拆分不精确

**文件**: `cc-monitor-bar/App/AppState.swift:664-677` + `TrendChartSection.swift`

**问题**:
- 过去 6 天的 input/output/cache 来自 `stats-cache.json` 的 `dailyModelTokens`
- 用全局 `modelRatios`（基于所有天的 modelUsage 计算）去拆分每天的 total_tokens
- 如果某一天的实际 input/output 比例与全局平均不同，拆分结果偏差可能很大

**修复方案**: 这是 stats-cache 的设计限制，无法精确获取过去每一天的 input/output/cache 拆分。
- 趋势图只显示 **每日 totalTokens**（来自 stats-cache 的 `total_tokens` 字段，这是准确的）
- 移除 input/output/cache 三色的堆叠柱状图，改为**单一颜色的柱状图**
- 图例只保留 "Token 总量"
- 今天的柱子依然使用 JSONL 实时数据（可以三色拆分）

具体改动：
1. `TrendChartSection` 简化为单色柱状图
2. 过去 6 天：显示 `inputTokens + outputTokens + cacheTokens` 总和（来自 DailyActivity.totalTokens）
3. 今天：显示 `todayStats.totalTokens`
4. 如果某天数据为 0 或不可用，显示空占位而非 0 高度柱状图

---

#### 4. ContextProgressBar — 硬编码 200K context limit

**文件**: `cc-monitor-bar/Views/Sections/ActiveSessionSection.swift:120`

**问题**:
```swift
private let contextLimit: Int64 = 200_000  // 默认 Claude 200K context
```
- Claude Opus 4: 200K context window
- Claude Sonnet 4: 200K context window
- 但如果未来模型有更大 context（如 1M），百分比会严重偏差
- 另外 `contextTokens` 是累计值（多次消息的 input 累加），不是当前上下文窗口大小，百分比意义不明确

**修复方案**: 
- 将 Context 进度条改为显示原始数值，不显示百分比
- 移除 `contextLimit` 和百分比计算
- 显示 `contextTokens` 绝对值 + 注释 "累计 Context 大小"

---

### P2 — 建议优化

#### 5. ModelConsumptionSection — 模型名称显示不完整

**文件**: `cc-monitor-bar/Views/Sections/ModelConsumptionSection.swift:111-116`

**问题**: `modelNameDisplay` 只处理 sonnet/opus/haiku 关键字匹配，无法处理其他模型变体。

**修复**: 保持现有逻辑不变，增加 fallback 显示完整模型名而非截断。

---

## 实施顺序

1. 先修 P0（严重问题）：#1 SessionReplayView、#2 历史会话用量
2. 再修 P1（重要问题）：#3 趋势图简化、#4 Context 显示
3. P2 可选：#5 模型名称

---

## 注意事项

- 所有修改后 build 验证
- 每修完一个问题 commit 一次，commit message: `fix: <问题编号> <简短描述>`
- 推送前确认无 error、无 crash
