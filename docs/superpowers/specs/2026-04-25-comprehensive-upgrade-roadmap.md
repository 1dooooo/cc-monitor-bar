# cc-monitor-bar 技术升级蓝图

> 从 12 个开源项目中提取可复用的技术方案和 UI/交互模式，规划应用到 cc-monitor-bar。
> 纯客户端项目，无云端能力，无订阅计费。

## 一、当前技术债

| # | 问题 | 严重度 | 代码位置 |
|---|------|--------|---------|
| T1 | 工具调用分布是伪造数据 — `toolCallCount / 3` | 高 | `MonitorView.swift:11-18` |
| T2 | 增量索引仅内存 — 重启后全量重解析 | 中 | `ClaudeDataReader.swift:43-46` |
| T3 | SQLite 持久化层已定义但未接入主数据流 | 中 | `Database/` 目录 |
| T4 | 数据质量校验只报"有偏差"，无法解释原因 | 中 | `AppState.swift:buildDataQualityStatus` |
| T5 | 固定 30s 轮询 — 所有数据源同频率 | 低 | `DataPoller.swift` |
| T6 | 菜单栏图标无状态 — 静态图标 | 低 | `AppDelegate.swift` |
| T7 | 信息密度单一 — 不可开关模块 | 低 | `MonitorView.swift` |
| T8 | 无 hooks 支持 — 纯轮询，延迟高 | 低 | — |
| T9 | 无 burn rate — 无法感知消耗速度 | 高 | — |
| T10 | Context Window 字段存在但未使用 | 高 | `ModelUsage.contextWindow` |
| T11 | 无通知系统 — 会话卡住/异常消耗不感知 | 低 | — |
| T12 | Subagent 只合并不独立观测 | 中 | — |

---

## 二、可采纳的技术模式

### 数据层

| 模式 | 来源项目 | 解决什么问题 |
|------|---------|-------------|
| `mtime + offset` 增量扫描 + SQLite 持久化索引 | phuryn/claude-usage | T2, T3 |
| `message_id` 精确去重 + UNIQUE INDEX | ccusage, tokscale | T1 (去重不严格) |
| 双数据源对账校验 | phuryn/claude-usage, cctray | T4 |

### 实时性

| 模式 | 来源项目 | 解决什么问题 |
|------|---------|-------------|
| Claude Code hooks → 本地事件流 | observagent, anjor | T8 |
| 文件写入事件监听（比轮询快） | anjor (`--watch-transcripts`) | T5 |
| 错误时指数退避 | cctray | T5 |
| 多频率轮询（不同数据源不同间隔） | exelban/stats | T5 |

### 指标计算

| 模式 | 来源项目 | 解决什么问题 |
|------|---------|-------------|
| Burn rate（滑动窗口 EMA 平滑） | cctray | T9 |
| Context Window 用量追踪 | anjor | T10 |
| Subagent 独立统计 + 成本占比 | observagent, anjor | T12 |

### 通知

| 模式 | 来源项目 | 解决什么问题 |
|------|---------|-------------|
| 系统告警（异常消耗/会话卡住/cache 过期） | cctray, gitify | T11 |

### UI/交互

| 模式 | 来源项目 | 解决什么问题 |
|------|---------|-------------|
| 动态图标颜色（burn rate 阈值） | cctray, Claude-Tracker | T6 |
| 菜单栏轮播显示（多指标切换） | cctray | T6 |
| 模块化面板 + 可开关 | exelban/stats | T7 |
| 信息密度模式（紧凑/标准/详细） | Claude-Tracker | T7 |
| 会话时间线诊断面板 | observagent, anjor | — |
| 贡献热力图（GitHub 风格） | tokscale | — |
| 会话浏览 + 回放 | kmizzi | — |
| 成本估算（内嵌定价表） | ccusage, tokscale, cctray | — |

---

## 三、五阶段实施路线图

```
Phase 1: 数据精确 + 核心指标       ← 消除假数据，建立 burn rate 和 context window
Phase 2: 持久化 + 增量性能          ← SQLite 索引跨重启生效
Phase 3: 实时性 + 告警              ← hooks + 文件监听 + 通知系统
Phase 4: UI 模块化 + 动态图标        ← 可定制面板，状态图标
Phase 5: 深度分析                   ← 热力图、回放、成本分析
```

---

## Phase 1: 数据精确 + 核心指标

**目标**: 消除所有假数据，建立 burn rate 和 context window 这两个核心指标。

### 1.1 真实的工具调用分布

**技术模式**: 从 ccusage/tokscale — 按 `tool_use.name` 聚合统计

**当前**: `MonitorView.topTools` 把 `toolCallCount / 3` 硬编码分给 Bash/Read/Edit。

**方案**:

- `UsageAccumulator` 新增 `toolCounts: [String: Int]`
- 解析 `content[].type == "tool_use"` 时按 `block["name"]` 累加计数
- 复用现有去重逻辑（`toolUseIds` 或 `anonymousToolUseFingerprints`），但额外保留 tool name
- 新建 `TopToolsSection` 展示真实分布（Bash, Read, Edit, Grep, Write, Glob...）

**涉及文件**: `ClaudeDataReader.swift`, `SessionUsage.swift`, 新建 `Views/Sections/TopToolsSection.swift`

### 1.2 message_id 精确去重 + SQLite 持久化

**技术模式**: 从 phuryn/claude-usage — `UNIQUE INDEX ON message_id`

**当前**: 内存中按 `[String: IndexedMessageUsage]` 去重，每次重启重建。

**方案**:

- 去重键写入 SQLite `tool_calls` 表，添加 `UNIQUE INDEX ON dedup_key`
- 每次解析后统计去重命中率（`INSERT OR IGNORE` 的 affected rows）
- 去重数据用于数据质量校验（重复次数异常多说明数据源有问题）

**涉及文件**: `ClaudeDataReader.swift`, `Database/Schema.swift`, `Database/Repository.swift`

### 1.3 可解释的数据质量校验

**技术模式**: 从 anjor — 可诊断性（不只是"有错"，而是"为什么错"）

**当前**: `DataQualityStatus` 只报 healthy/warning/critical，不解释原因。

**方案**:

- 新增 `DataQualityDiagnosis` 结构：
  - `jsonlValue` / `cacheValue` — 两个数据源的具体数值
  - `diffRatio` — 相对差异百分比
  - `reason`: `.cacheNotYetUpdated / .jsonlMissingUsage / .dataSourceMismatch`
  - `affectedSessions: [String]` — 哪些会话的数据有问题
  - `suggestion: String` — 建议操作（"等待 stats-cache 刷新" / "手动触发全量重扫"）
- UI 展示为可展开的诊断面板，点击后显示每个受影响会话的详情

**涉及文件**: `AppState.swift`, `TokenSummarySection.swift`

### 1.4 Burn Rate（消耗速率）

**技术模式**: 从 cctray — 实时 burn rate + 颜色编码 + 剩余时间预估

**当前**: 无任何速率指标。用户打开菜单栏只能看到"今天用了多少"，不知道"消耗速度多快"。

**方案**:

- **`BurnRateTracker`** 服务：
  - 维护最近 5 分钟的 token 消耗时间序列
  - 使用指数移动平均（EMA）平滑波动，避免单次大请求导致 spike
  - 输出 `tokens/min`（5 分钟 EMA）
  - 输出 `messages/min`（同上）
- **`BurnRateSection`** 视图：
  - 展示为紧凑数字卡片：`当前速率: 423 tokens/min`
  - 颜色编码：🟢 < 300（空闲）/ 🟡 300-700（活跃）/ 🔴 > 700（高负载）
  - 如果 session 还在活跃：显示"预计本 session 剩余时间"
- 与 Phase 4.2 动态图标共享 burn rate 数据

**涉及文件**: 新建 `Services/BurnRateTracker.swift`，新建 `Views/Sections/BurnRateSection.swift`

**关键实现细节**:
- EMA 计算：`ema_new = α * current + (1 - α) * ema_old`，推荐 α = 0.3
- 时间窗口：5 分钟（足够平滑短期 spike，又不至于太迟钝）
- 数据来源：每次 `refreshData()` 对比上次 totalTokens 差值

### 1.5 Context Window 追踪

**技术模式**: 从 anjor — context window observability

**当前**: `ModelUsage.contextWindow` 存在于数据模型但完全未使用。

**方案**:

- 从 JSONL 解析时追踪每个活跃会话的累计 context 使用：
  - 每次 assistant 调用的 `input_tokens + output_tokens + cache_tokens` 累加
  - 对比模型的 context window 上限（如 `claude-4` = 200K）
- 展示在活跃会话卡片上：
  - `Context: 142K / 200K (71%)` — 进度条 + 百分比
  - 颜色阈值：🟢 < 60% / 🟡 60-85% / 🔴 > 85%
- Subagent 的 context 单独追踪，不混入主会话

**涉及文件**: `ClaudeDataReader.swift`（context 追踪），`ActiveSessionSection.swift`（展示）

**关键实现细节**:
- Context window 消耗 = 所有 assistant 调用的输入 token 总和（不仅仅是当前请求的 input_tokens，而是整个 conversation 的累计 context）
- JSONL 中每次 assistant 消息的 `usage.input_tokens` 实际上已经包含了完整的 context 大小（Claude API 的 input_tokens 包含 system prompt + conversation history）
- 所以直接用 `input_tokens` 的累加值即可近似

### 1.6 项目级聚合

**技术模式**: 从 specter — multi-project dashboard

**当前**: 数据聚合只有"全局"和"单会话"两个维度，无法回答"哪个项目用的最多"。

**方案**:

- 按项目（cwd）聚合 Token 和 Session 数据
- 新增 `ProjectSummarySection`：
  - 项目列表：`[项目名] 今日: 1.2M tokens | 8 sessions`
  - 按 token 用量降序排列
  - 点击展开项目详情（模型分布、趋势、历史会话列表）
- 持久化时增加 `project_id` 字段到 `daily_stats` 表

**涉及文件**: `ClaudeDataReader.swift`（按项目过滤），新建 `Views/Sections/ProjectSummarySection.swift`，修改 `Database/Schema.swift`

---

## Phase 2: 持久化 + 增量性能

**目标**: 增量索引跨重启持久化，冷启动性能提升 5-10x。

### 2.1 增量索引持久化

**技术模式**: 从 phuryn/claude-usage — `processed_files` 表

**当前**: `usageIndex` 是内存字典，重启丢失，每次全量重解析。

**方案**:

- 新增 SQLite 表：
  ```sql
  CREATE TABLE processed_files (
      path TEXT PRIMARY KEY,
      mtime REAL NOT NULL,
      file_size INTEGER NOT NULL,
      offset INTEGER NOT NULL DEFAULT 0,
      message_count INTEGER NOT NULL DEFAULT 0,
      tool_call_count INTEGER NOT NULL DEFAULT 0,
      total_tokens INTEGER NOT NULL DEFAULT 0,
      last_accessed REAL NOT NULL
  );
  CREATE INDEX idx_pf_mtime ON processed_files(mtime);
  CREATE INDEX idx_pf_last_accessed ON processed_files(last_accessed);
  ```
- `ClaudeDataReader` 初始化时从 SQLite 加载索引
- 每次 `parseJsonlUsage` 完成时 `UPSERT` 到 SQLite
- 增量策略不变（path + mtime + offset），但跨重启生效
- 超过 2000 条目时按 `last_accessed` 淘汰最旧的

**涉及文件**: `Database/Schema.swift`, `Database/Repository.swift`, `ClaudeDataReader.swift`

### 2.2 会话和每日统计持久化

**技术模式**: 从 phuryn/claude-usage — sessions/turns 表持久化

**当前**: SQLite 已有 `sessions` / `session_token_usage` / `daily_stats` / `daily_model_usage` 表，但未使用。

**方案**:

- 每次 `refreshData()` 后将结果写入 SQLite
- `sessions` 表增加 `project_id` 字段（用于 Phase 1.6 项目级查询）
- `daily_stats` 增加 `project_id` 字段
- `daily_model_usage` 记录每日 × 模型的 Token 分解

**涉及文件**: `AppState.swift`（写入）, `Database/Repository.swift`, `Database/Schema.swift`

### 2.3 多频率轮询 + 指数退避

**技术模式**: 从 exelban/stats（多频率）+ cctray（指数退避）

**当前**: 单一 30s 定时器轮询所有数据源。

**方案**:

- 拆分为独立频率：
  - 活跃会话 + 用量：10s
  - 今日统计：30s
  - 历史会话：60s
  - 周数据：60s
- 错误时启动指数退避：1s → 2s → 4s → 8s → 16s → 32s → 60s（max）
- 恢复后自动回到正常频率

**涉及文件**: `DataPoller.swift`

### 2.4 增量扫描优化

**当前**: `readTodayUsage()` 每次遍历所有项目目录的 JSONL 文件。

**方案**:

- 使用 SQLite `processed_files` 表定位"今日有变更的文件"（`mtime > today_start`）
- 只解析增量部分（从 offset 继续）
- 未变更的文件直接读取上次缓存结果

---

## Phase 3: 实时性 + 告警

**目标**: 从纯轮询升级为多通道实时感知，建立系统健康告警。

### 3.1 文件写入事件监听（主要实时通道）

**技术模式**: 从 anjor — `--watch-transcripts` 被动读取

**当前**: 只能等 10-30s 轮询才能感知 JSONL 文件变化。

**方案**:

- 使用 `DispatchSourceFileSystemObject`（macOS 原生）监控活跃会话的 JSONL 文件
- 文件写入事件到达时立即触发增量解析（不等待轮询定时器）
- 这是**最实用的实时通道**——不需要 hooks，不依赖外部配置，直接监听文件

**涉及文件**: 新建 `Services/FileWatcher.swift`，修改 `DataPoller.swift`

### 3.2 Claude Code Hooks 集成（可选增强）

**技术模式**: 从 observagent — hooks → 本地事件流

**当前**: 纯文件轮询。

**方案**:

- 可选注册 Claude Code hooks（PreToolUse / PostToolUse）
- Hook 脚本将事件写入本地 Unix socket
- 应用监听该 socket，实时接收 tool_use 事件
- 文件监听不可用时自动降级为轮询

**涉及文件**: 新建 `Services/HookServer.swift`，修改 `AppDelegate.swift`，新建 `Models/HookEvent.swift`

### 3.3 会话级时间线

**技术模式**: 从 observagent / anjor — 实时诊断面板

**方案**:

- 点击活跃会话卡片展开 `SessionDetailSheet`
- 展示：
  - 消息时间线（user → assistant → tool_use → assistant）
  - 每次调用的工具名、耗时
  - Token 消耗瀑布图
  - Context Window 使用量（Phase 1.5 的数据）
  - Subagent 折叠面板（Phase 3.5 的数据）

**涉及文件**: 新建 `Views/Sections/SessionDetailSheet.swift`，修改 `ActiveSessionSection.swift`

### 3.4 通知/告警系统

**技术模式**: 从 cctray / gitify — 本地通知

**当前**: 用户必须主动打开菜单栏才能看到信息。

**方案**:

- 新增 `NotificationManager`，基于 `UNUserNotificationCenter`：
  - **会话卡住**: 活跃会话超过 30 分钟但 token 增长为 0 → 通知"会话可能卡住"
  - **异常消耗突增**: 1 小时内 token 消耗 > 日均值的 3 倍 → 通知"今日消耗异常偏高"
  - **Cache 过期**: stats-cache 超过 2 小时未更新 → 通知"统计缓存可能过期"
  - **Context 接近极限**: 活跃会话 context window > 90% → 通知"上下文窗口即将耗尽"
- 告警规则可在 Preferences 中配置（开/关 + 阈值）
- macOS 原生通知，不依赖云端

**涉及文件**: 新建 `Services/NotificationManager.swift`，修改 `Preferences`

### 3.5 Subagent 独立观测

**技术模式**: 从 observagent — subagent observability

**当前**: Subagent 数据直接合并到父会话，无法区分成本占比。

**方案**:

- 解析时区分主会话和 subagent 数据
- 新增 `subagent_stats` 表持久化每个 subagent 的独立统计
- 会话详情页增加 subagent 折叠面板：
  - subagent 名称/ID、启动时间
  - Token 用量、工具调用数
  - 占父会话的百分比

**涉及文件**: 新建 `Database/Schema.swift`（subagent_stats 表），修改 `ClaudeDataReader.swift`，修改 `SessionDetailSheet.swift`

---

## Phase 4: UI 模块化 + 动态图标

**目标**: 面板可定制，菜单栏图标有状态。

### 4.1 动态菜单栏图标

**技术模式**: 从 cctray — 颜色编码 + 轮播显示

**当前**: 静态 NSStatusItem 图标。

**方案**:

- **颜色编码**（基于 Phase 1.4 的 burn rate）：
  - 🟢 < 300 tokens/min
  - 🟡 300-700 tokens/min
  - 🔴 > 700 tokens/min
- **轮播显示**：每 5 秒切换显示当前指标：
  - 今日 tokens → burn rate → 活跃会话数 → context 使用率
- 用户可在 Preferences 中关闭轮播

**涉及文件**: `AppDelegate.swift`，新建 `Services/MenuBarDisplayManager.swift`

### 4.2 可开关面板模块

**技术模式**: 从 exelban/stats — 模块化 + 可开关

**当前**: `MonitorView` 硬编码 6 个 Section，全部显示。

**方案**:

- 每个 Section 可独立开关（Preferences 设置）
- `ModuleID` 枚举: `.tokenSummary`, `.burnRate`, `.trendChart`, `.modelConsumption`, `.activeSessions`, `.recentSessions`, `.toolCalls`, `.projectSummary`
- 隐藏模块不加载数据，节省资源

**涉及文件**: `MonitorView.swift`, `AppState.swift`（preferences 扩展）

### 4.3 信息密度模式

**技术模式**: 从 Claude-Usage-Tracker — 多视图 + 密度切换

**方案**:

- **紧凑模式**: 只显示核心数字（今日 tokens + burn rate + 活跃会话数）
- **标准模式**: 完整 Section 列表
- **详细模式**: 展开所有 Sub-details
- 快捷键切换（Cmd+1/2/3）

**涉及文件**: `MonitorView.swift`，各 Section 的 compact/detail 变体

---

## Phase 5: 深度分析

**目标**: 从"今日监控"扩展到"历史洞察"。

### 5.1 会话浏览与搜索

**技术模式**: 从 kmizzi — 会话检索 + 筛选

**方案**:

- 基于 SQLite 持久化的会话数据，支持：
  - 按项目/日期/模型筛选
  - 按 tokens 排序
  - 关键词搜索（从 JSONL 转录中搜索）
- 点击展开会话详情（Phase 3.3 的时间线）

**涉及文件**: 新建 `Views/Sections/SessionBrowserView.swift`，`Database/Repository.swift`

### 5.2 会话回放

**技术模式**: 从 kmizzi — replay

**方案**:

- 从 JSONL 转录文件构建对话时间线
- 支持逐步回放（播放/暂停/步进）
- 每条消息展示：用户消息、AI 回复、工具调用、Token 用量、时间戳
- 高亮异常点（高消耗消息、错误、长时间停顿）

**涉及文件**: 新建 `Views/Sections/SessionReplayView.swift`

### 5.3 贡献热力图

**技术模式**: 从 tokscale — GitHub-style 热力图

**方案**:

- 展示最近 12 个月的每日 Token 使用量
- 颜色深浅 = tokens 数量
- 点击某天展开该日详情

**涉及文件**: 新建 `Views/Sections/ContributionHeatmap.swift`

### 5.4 Cost 估算

**技术模式**: 从 ccusage/tokscale/cctray — 内嵌定价表

**方案**:

- 内嵌 Anthropic 定价表（模型名 → token price 映射）
- Token → USD 转换
- 按日/周/月聚合成本
- 趋势图可切换 Token 视图 / Cost 视图

**涉及文件**: 新建 `Services/PricingTable.swift`，修改 `TrendChartSection.swift`

---

## 四、数据库 Schema 规划

### 已有但未使用的表（Phase 2 启用）

| 表 | 用途 |
|----|------|
| `sessions` | 会话元数据（pid, sessionId, cwd, startedAt, kind） |
| `session_token_usage` | 会话 Token 用量 |
| `daily_stats` | 每日聚合（增加 `project_id` 字段） |
| `daily_model_usage` | 每日 × 模型 Token |
| `tool_calls` | 工具调用计数（增加 `dedup_key UNIQUE` 索引） |

### 新增表

```sql
-- 已处理文件索引（Phase 2.1）
CREATE TABLE IF NOT EXISTS processed_files (
    path TEXT PRIMARY KEY,
    mtime REAL NOT NULL,
    file_size INTEGER NOT NULL,
    offset INTEGER NOT NULL DEFAULT 0,
    message_count INTEGER NOT NULL DEFAULT 0,
    tool_call_count INTEGER NOT NULL DEFAULT 0,
    total_tokens INTEGER NOT NULL DEFAULT 0,
    last_accessed REAL NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_pf_mtime ON processed_files(mtime);
CREATE INDEX IF NOT EXISTS idx_pf_last_accessed ON processed_files(last_accessed);

-- Subagent 统计（Phase 3.5）
CREATE TABLE IF NOT EXISTS subagent_stats (
    id TEXT PRIMARY KEY,
    parent_session_id TEXT NOT NULL,
    name TEXT,
    started_at REAL NOT NULL,
    ended_at REAL,
    total_tokens INTEGER NOT NULL DEFAULT 0,
    tool_call_count INTEGER NOT NULL DEFAULT 0,
    message_count INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_subagent_parent ON subagent_stats(parent_session_id);
```

---

## 五、目标 UI 结构

```
菜单栏图标 (Phase 4.1):
  [🟢/🟡/🔴] tokens/min | sessions | context%

面板 (Phase 4.2 可定制):
├── Token 摘要 (今日 tokens + 数据质量诊断)
├── Burn Rate 卡片 (tokens/min + pace 颜色)
├── 趋势图 (7日堆叠柱状 / 可切换 Cost 视图)
├── 模型分解 (按模型 Token 用量排序)
├── 活跃会话 (含 Context Window 进度条 + subagent 折叠面板)
├── 项目聚合 (各项目今日用量列表)
├── 工具调用分布 (真实的 tool name 统计)
├── 历史会话
└── [可选] 贡献热力图 / 会话浏览器 / 成本估算
```

---

## 六、实施优先级

```
Phase 1 (数据精确 + 核心指标) → 必须先做：消除假数据 + burn rate + context window
Phase 2 (持久化 + 增量性能) → 重启后增量生效，冷启动 5-10x
Phase 3 (实时性 + 告警)     → 文件监听 + 通知系统 + subagent 独立追踪
Phase 4 (UI 模块化 + 动态图标) → 用户体验最直观的提升
Phase 5 (深度分析)          → 热力图、回放、成本分析，锦上添花
```

| Phase | 独立价值 | 依赖 |
|-------|---------|------|
| Phase 1 | 消除假数据 + burn rate/context window 核心指标 + 项目级聚合 | 无 |
| Phase 2 | 重启后增量生效，冷启动性能 5-10x | 无（但与 Phase 1 的持久化有重叠，可并行） |
| Phase 3 | 文件监听 + 告警推送 + subagent 独立追踪 | Phase 2（持久化基础） |
| Phase 4 | 动态图标 + 可定制面板 + 密度模式 | Phase 1（burn rate 数据是前提） |
| Phase 5 | 历史洞察 + 成本分析 + 会话回放 | Phase 2（SQLite 持久化） |

---

## 七、风险与技术注意

1. **macOS 沙箱** — `DispatchSourceFileSystemObject` 监控 `~/.claude/` 目录需要 Full Disk Access 权限，首次启动需引导用户授权
2. **SQLite 并发** — 使用 WAL 模式，避免 `ClaudeDataReader` 和 `AppState` 同时写入冲突
3. **JSONL 文件数量增长** — `processed_files` 表需要定期清理（淘汰 > 7 天未访问的条目）
4. **Burn Rate 波动** — 使用 EMA 平滑，推荐 α = 0.3，时间窗口 5 分钟
5. **Context Window 估算** — JSONL 中的 `input_tokens` 已包含完整 conversation context，可直接用于累加
6. **Hooks 是可选的** — 文件写入事件监听是主要实时通道，hooks 只是增强
7. **纯本地定位** — 所有数据仅存储在本地 SQLite，不上传、不遥测，保持 Specter 的"纯本地只读"可信度
