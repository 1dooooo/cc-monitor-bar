# 单面板重构设计

> 日期：2026-04-04
> 状态：已批准

## 背景

当前 cc-monitor-bar 有三个面板（极简/看板/时间线），信息分散且需要切换。用户反馈三面板没有必要，希望合并为一个面板，同时重新思考数据呈现方式。

## 设计决策

| 决策项 | 选择 | 理由 |
|--------|------|------|
| 面板结构 | 单面板，垂直滚动信息流 | 最直观，信息按优先级排列 |
| 核心定位 | 用量分析师 | 核心场景是「Token 花在哪里」 |
| 配额追踪 | 不做 | 保持纯本地、零外部依赖 |
| 钻取深度 | 不支持 | 会话用内联信息展示详情 |
| 趋势图 | 堆叠柱状图 | 信息密度高，三维（输入/输出/缓存）一目了然 |

## 面板区块

从上到下依次排列，支持垂直滚动：

### 1. 今日 Token 摘要

- 总量（大号字体）
- 三维分解：↑输入 / ↓输出 / ⟳缓存

### 2. 趋势图

- 堆叠柱状图，每根柱子分三层：输入（蓝）/ 输出（绿）/ 缓存（青）
- 右上角 Segmented Control：周（7 天）/ 月（30 天）
- 今日柱子用圆点标记高亮
- 底部图例说明颜色含义
- 数据来源：DailyStats 模型

### 3. 模型消耗

每个模型一个卡片：
- 色块 + 模型名 + Token 总量
- ↑输入 / ↓输出 / ⟳缓存 三维数据
- 底部进度条显示该模型占总量的比例

### 4. 活跃会话

- 绿色状态点标识
- 卡片样式
- 项目名 + 消息数 + 时长
- ↑输入 / ↓输出 / 总量

### 5. 最近会话

- 灰色状态点标识
- 紧凑行样式
- 项目名 + 时长 + ↑输入 / ↓输出 / 总量

### 6. 工具调用

- Top 5 彩色标签
- 格式：`工具名 次数`

## 新增 Section（Phase 4 追加）

> 以下 Section 在单面板重构后追加，基于开源项目技术模式采纳。

### 7. Burn Rate 卡片

**来源**: 从 cctray 提取 — 实时消耗速率 + 颜色编码 + 剩余时间预估

- 展示 `当前速率: 423 tokens/min`（5 分钟 EMA 平滑）
- 颜色编码：🟢 < 300 / 🟡 300-700 / 🔴 > 700 tokens/min
- 如果 session 还在活跃：显示"预计本 session 剩余时间"
- 与菜单栏图标颜色共享数据

**涉及文件**: 新建 `Services/BurnRateTracker.swift`，新建 `Views/Sections/BurnRateSection.swift`

### 8. 数据质量诊断面板

**来源**: 从 anjor 提取 — 可解释的诊断（不只是"有错"，而是"为什么错"）

- 数据质量状态指示器（已在 TokenSummarySection 内）
- 可展开显示详细诊断：
  - JSONL vs Cache 四个维度的具体差异值
  - 差异原因分类：`cache 延迟` / `解析遗漏` / `数据源不一致`
  - 受影响会话列表
  - 建议操作："等待 stats-cache 刷新" / "手动触发全量重扫"

**涉及文件**: `AppState.swift` (buildDataQualityStatus), `TokenSummarySection.swift`

### 9. 项目聚合 Section

**来源**: 从 specter 提取 — multi-project dashboard

- 项目列表：`[项目名] 今日: 1.2M tokens | 8 sessions`
- 按 token 用量降序排列
- 点击展开项目详情（模型分布、趋势、历史会话列表）

**涉及文件**: 新建 `Views/Sections/ProjectSummarySection.swift`，修改 `Database/Schema.swift`（daily_stats 增加 project_id）

### 10. Context Window 追踪

**来源**: 从 anjor 提取 — context window observability

- 活跃会话卡片内嵌 Context Window 进度条
- 展示：`Context: 142K / 200K (71%)`
- 颜色阈值：🟢 < 60% / 🟡 60-85% / 🔴 > 85%
- Subagent 的 context 单独追踪

**涉及文件**: `ClaudeDataReader.swift`（context 追踪），`ActiveSessionSection.swift`（展示）

---

## 删除的组件

| 组件 | 原因 |
|------|------|
| 三面板切换（Minimal/Dashboard/Timeline） | 合并为单面板 |
| FloatingNav 浮动导航 | 单面板无需导航 |
| TimelineView 时间线视图 | 趋势图替代时间维度 |
| SnapshotDetail 详情视图 | 不再支持钻取 |
| ContentView 面板切换逻辑 | 改为单视图 |
| 快捷键 ⌘1/⌘2/⌘3 | 不再有多面板 |

## 保留的组件

- AppDelegate / NSPopover 架构不变
- ClaudeDataReader / DataPoller / ProjectResolver 服务层不变
- **新增**: FileWatcher / BurnRateTracker / NotificationManager
- 数据库层和模型不变（新增 processed_files / subagent_stats 表）
- 主题系统（三套配色）不变
- 设置窗口不变（移除「默认视图」选项，因为只有一个视图；新增「通知」分区）
- 全局快捷键：⌘, 打开设置、⌘R 刷新、⎋ 关闭

## 数据展示变更

- 模型消耗：从「分布百分比」改为「消耗量 + 上下行分解」
- 会话：从「只有总量」改为「↑输入 / ↓输出 / 总量」
- 趋势：从「消息数柱状图」改为「Token 堆叠柱状图（输入/输出/缓存）」
- 所有数据字段已存在于现有模型（SessionUsage、DailyStats），无需新增模型

## 新文件结构

```
Views/
├── MonitorView.swift          # 主视图（单面板，垂直滚动）
├── Sections/
│   ├── TokenSummarySection.swift    # 今日 Token 摘要 + 数据质量
│   ├── BurnRateSection.swift        # Burn Rate 卡片（Phase 4 追加）
│   ├── TrendChartSection.swift      # 趋势图（堆叠柱状图）
│   ├── ModelConsumptionSection.swift # 模型消耗
│   ├── ActiveSessionSection.swift   # 活跃会话（含 Context Window）
│   ├── ProjectSummarySection.swift  # 项目聚合（Phase 4 追加）
│   ├── TopToolsSection.swift        # 真实工具调用分布
│   └── RecentSessionSection.swift   # 最近会话
├── Components/               # 复用组件
│   ├── ProgressBar.swift
│   ├── Badge.swift
│   ├── GlassBackground.swift
│   └── TokenFormatter.swift
└── Onboarding/               # 保留
```

新增服务文件（Phase 4 追加）：

```
Services/
├── ClaudeDataReader.swift    # 核心读取 + 增量索引
├── DataPoller.swift          # 多频率轮询 + 指数退避
├── FileWatcher.swift         # 文件写入事件监听
├── BurnRateTracker.swift     # Burn Rate 计算（Phase 4 追加）
├── ProjectResolver.swift     # 项目路径解析
└── NotificationManager.swift # 通知告警（Phase 3 追加）
```

删除：
- `Views/ContentView.swift`（面板切换）
- `Views/Minimal/` 整个目录
- `Views/Dashboard/` 整个目录（StatCard、ModelDistribution、TokenChart、DashboardView）
- `Views/Timeline/` 整个目录（TimelineView、TimelineEvent、SnapshotDetail）
- `Views/Components/SessionRow.swift`（替换为 Section 内的内联布局）
- `Views/Components/FloatingNav.swift`
- `Views/Components/ToolTagList.swift`（替换为 ToolCallSection）
- `Views/Components/FrequencySlider.swift`
