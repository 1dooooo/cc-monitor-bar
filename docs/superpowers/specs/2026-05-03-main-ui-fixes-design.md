# 主界面功能修复设计

## 概述

修复 cc-monitor-bar 主界面（MonitorView）中缺失或不正确的功能，确保所有已实现的组件和设置项都能正常工作。

## 修复清单

### 1. 成本估算显示

**问题**: `PricingTable.swift` 存在定价数据和计算逻辑，但 UI 未显示 USD 费用。

**方案**:
- 在 `TokenSummarySection` 的总 Token 数下方添加 USD 费用显示
- 使用 `PricingTable.estimateTotalCost(modelBreakdown)` 计算
- 受 `preferences.showCostEstimate` 设置控制，默认隐藏

**实现**:
- 修改 `TokenSummarySection.swift`，添加 `@EnvironmentObject var preferences: AppPreferences`
- 在总 Token 行下方添加条件显示的费用行
- 格式: `≈ $12.34` (灰色小字)

### 2. 预算告警 UI

**问题**: 有 `enableBudgetWarning` 和 `budgetAmount` 设置，但无对应 UI。

**方案**:
- 新建 `BudgetSection.swift`，显示预算使用进度
- 颜色编码: 绿色 (<50%) / 黄色 (50-80%) / 红色 (>80%)
- 受 `preferences.enableBudgetWarning` 控制

**实现**:
- 新建 `Views/Sections/BudgetSection.swift`
- 显示: 预算进度条 + 已用金额 + 预算总额
- 已用金额从 `PricingTable.estimateTotalCost(todayStats.modelBreakdown)` 计算
- 进度条使用 `ProgressView`

### 3. 会话摘要区块

**问题**: `SessionBrowserView` 已实现但未集成到主界面。

**方案**:
- 新建 `SessionSummarySection.swift`，显示会话统计摘要（非完整列表）
- 显示: 总会话数、活跃会话数、今日消息总数
- 受 `preferences.defaultView` 影响（minimal 模式隐藏）

**实现**:
- 新建 `Views/Sections/SessionSummarySection.swift`
- 数据来源: `appState.currentSessions.count` + `appState.todayStats`
- 简洁的统计卡片样式

### 4. 使用量热力图集成

**问题**: `UsageHeatmapView` 已实现但未集成到主界面。

**方案**:
- 在 `MonitorView` 添加"使用量热力图"可折叠区块
- 直接使用现有 `UsageHeatmapView` 组件

**实现**:
- 修改 `MonitorView.swift`，添加 CollapsibleSection 包裹 UsageHeatmapView
- 区块 ID: `"heatmap"`

### 5. 菜单栏图标样式修复

**问题**: `iconStyle` 设置存在但不生效，`AppDelegate` 固定使用 `chart.bar.fill`。

**方案**:
- 在 `AppDelegate` 监听 `preferences.$iconStyle` 变化
- 根据 `IconStyle.systemSymbol` 更新状态栏图标

**实现**:
- 修改 `AppDelegate.swift` 的 `applicationDidFinishLaunching`
- 添加 `appState.preferences.$iconStyle` 的 sink
- 在 `updateStatusBarIcon` 中结合 `iconStyle` 和动态状态

## 文件变更

| 文件 | 操作 | 说明 |
|------|------|------|
| `Views/Sections/TokenSummarySection.swift` | 修改 | 添加 USD 费用显示 |
| `Views/Sections/BudgetSection.swift` | 新建 | 预算进度条组件 |
| `Views/Sections/SessionSummarySection.swift` | 新建 | 会话统计摘要 |
| `Views/MonitorView.swift` | 修改 | 集成新区块 |
| `App/AppDelegate.swift` | 修改 | 响应 iconStyle 变化 |

## 区块顺序

MonitorView 中的区块顺序（从上到下）:

1. Token 摘要（含费用估算）
2. Burn Rate
3. 趋势
4. 模型
5. 活跃会话
6. 项目
7. 会话摘要（新增）
8. 历史
9. 工具调用
10. 使用量热力图（新增）

## 依赖关系

- 成本估算依赖 `PricingTable`（已存在）
- 预算告警依赖成本估算计算
- 会话摘要依赖现有 `AppState` 数据
- 热力图依赖 SQLite 持久化数据（已实现）
- iconStyle 依赖现有 `IconStyle` 枚举

## 测试验证

1. 开启 `showCostEstimate` 设置，验证费用显示正确
2. 开启 `enableBudgetWarning`，设置低预算值验证进度条颜色变化
3. 验证会话摘要区块显示正确统计
4. 验证热力图区块显示 30 天数据
5. 切换不同 `iconStyle`，验证菜单栏图标更新
