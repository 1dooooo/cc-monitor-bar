# cc-monitor-bar 全面升级路线图

> 基于 12 个竞品项目的调研分析，制定分阶段实施蓝图。
> 本文档为规划用途，非实施指令。

## 一、当前问题清单

| # | 问题 | 严重度 | 代码位置 |
|---|------|--------|---------|
| P1 | 工具调用分布是**伪造数据** — `toolCallCount / 3` 平分给 Bash/Read/Edit | 高 | `MonitorView.swift:11-18` |
| P2 | 增量索引仅内存 — 每次重启全量重解析 | 中 | `ClaudeDataReader.swift:43-46` |
| P3 | SQLite 持久化层已定义但**完全未接入**主数据流 | 中 | `Database/` 目录 |
| P4 | 数据质量校验只能告诉你"有偏差"，无法解释偏差原因 | 中 | `AppState.swift:buildDataQualityStatus` |
| P5 | 固定 30s 轮询 — 所有数据源同频率，活跃会话可能已变更但延迟感知 | 低 | `DataPoller.swift` |
| P6 | 菜单栏图标无状态变化 — 静态图标 | 低 | `AppDelegate.swift` |
| P7 | 信息密度单一 — 不可开关模块，滚动到底 | 低 | `MonitorView.swift` |
| P8 | 无 hooks 支持 — 纯轮询，无法捕获实时事件（tool_use 级别） | 低 | — |
| P9 | 周数据 token 分解依赖 `modelRatios` 近似分摊，不精确 | 中 | `AppState.swift:last7Days` |
| P10 | 缺少 cost 估算 — 无定价表，无 USD 成本展示 | 低 | — |
| P11 | 无 burn rate（消耗速率）指标 — 不知道当前消耗多快 | 高 | — |
| P12 | 无 Context Window 追踪 — 不知道是否接近 200K 极限 | 高 | `ModelUsage.contextWindow` 存在但未使用 |
| P13 | 无通知/告警系统 — 异常消耗、预算超支、会话卡住都不感知 | 中 | — |
| P14 | 无项目级聚合 — 各项目的成本/用量趋势对比缺失 | 中 | — |
| P15 | Subagent 只合并不独立观测 — 无法理解 subagent 成本占比 | 中 | — |
| P16 | 无会话回放 — 只能看统计，无法按时间顺序重放对话 | 低 | — |
| P17 | 无订阅方案感知 — 不知道相对于 Pro/Team 限额的使用率 | 低 | — |

## 二、竞品关键模式映射

### 数据层

| 竞品 | 模式 | 对应问题 |
|------|------|---------|
| phuryn/claude-usage | `mtime + line_offset` 增量扫描 + SQLite `processed_files` 持久化索引 | P2, P3 |
| ryoppippi/ccusage | `message_id` 精确去重 + UNIQUE INDEX | P1 (去重不够严格) |
| junhoyeo/tokscale | Rust SIMD 并行 JSONL 解析 | 性能参考 |
| alizenhom/Specter | 纯本地只读、零遥测 | 可信度定位 |

### 实时性

| 竞品 | 模式 | 对应问题 |
|------|------|---------|
| darshannere/observagent | Claude Code hooks → SSE 事件流 | P5 |
| anjor-labs/anjor | 零侵入 `--watch-transcripts` 被动读取 | P5 |
| goniszewski/cctray | 指数退避（错误时降频） | P5 |

### UI 层

| 竞品 | 模式 | 对应问题 |
|------|------|---------|
| exelban/stats | 模块化、每模块独立刷新间隔、可开关 | P7 |
| goniszewski/cctray | 动态图标颜色（绿/黄/红阈值）、轮播显示 | P6 |
| hamed-elfayome/Claude-Usage-Tracker | 6 级 pace 系统 + 颜色标记 | P6 |
| kmizzi/claude-code-sessions | 会话检索/筛选/回放 | 新功能 |
| junhoyeo/tokscale | 贡献热力图（GitHub 风格） | 新功能 |
| darshannere/observagent | 实时 tool_use 时间线诊断面板 | 新功能 |

## 三、五阶段路线图

```
Phase 1: 数据可信 (Data Integrity)    ← 先搞准
Phase 2: 持久性能 (Persistent Cache)   ← 再搞快
Phase 3: 实时可观测 (Real-time)        ← 再搞实时
Phase 4: 模块化 UI (Modular UI)        ← 再搞好看
Phase 5: 深度分析 (Deep Analysis)      ← 高阶功能
```

### 新增能力速查

| 能力 | 阶段 | 竞品来源 | 对应问题 |
|------|------|---------|---------|
| 消除工具调用伪造 | 1.1 | phuryn/ccusage | P1 |
| message_id 精确去重 | 1.2 | ccusage/tokscale | P1 |
| 数据质量可解释 | 1.3 | anjor/observagent | P4 |
| **Burn Rate 一级指标** | **1.4** | **cctray/Claude-Tracker** | **P11** |
| **Context Window 追踪** | **1.5** | **anjor** | **P12** |
| **项目级聚合** | **1.6** | **specter/kmizzi** | **P14** |
| 增量索引持久化 | 2.1 | phuryn/claude-usage | P2, P3 |
| 会话记录持久化 | 2.2 | phuryn/observagent | P3 |
| 多频率轮询 | 2.3 | exelban/stats/cctray | P5 |
| 增量扫描优化 | 2.4 | phuryn/claude-usage | P9 |
| Hooks 集成 | 3.1 | observagent/anjor | P8 |
| 会话时间线 | 3.2 | observagent/anjor | — |
| 轮询降级 | 3.3 | exelban/stats/cctray | P5 |
| **通知/告警系统** | **3.4** | **cctray/gitify** | **P13** |
| **Subagent 独立观测** | **3.5** | **observagent/anjor** | **P15** |
| **订阅方案感知** | **3.6** | **cctray** | **P17** |
| 可开关面板 | 4.1 | exelban/stats | P7 |
| 动态图标 | 4.2 | cctray | P6 |
| 信息密度模式 | 4.3 | Claude-Tracker | P7 |
| 会话浏览 | 5.1 | kmizzi | — |
| **会话回放** | **5.2** | **kmizzi** | **P16** |
| 贡献热力图 | 5.3 | tokscale | — |
| Cost 估算 | 5.4 | ccusage/tokscale/cctray | P10 |
| 模型迁移分析 | 5.5 | tokscale | — |

---

## Phase 1: 数据可信 (Data Integrity)

**目标**: 消除所有假数据，建立精确统计口径。

### 1.1 消除工具调用伪造

**当前**: `MonitorView.topTools` 把 `toolCallCount / 3` 硬编码分配给 Bash/Read/Edit。

**改动**:

- 从 `TodayStats` 的 JSONL 解析结果中提取**真实的 tool_use 分布**
- 当前 `UsageAccumulator` 已有 `toolUseIds: Set<String>` + `anonymousToolUseFingerprints: Set<String>`，但只有计数，没有按 tool name 分类
- 新增字段: `toolCounts: [String: Int]` — 按 `tool_use.name` 聚合（Bash, Read, Edit, Grep, Write 等）
- `TopToolsSection` 从假数据改为真实分布
- 保留一个"总工具调用数"用于趋势展示

**涉及文件**: `ClaudeDataReader.swift`, `SessionUsage.swift`, `MonitorView.swift`, 新建 `Views/Sections/TopToolsSection.swift`

**参考**: phuryn/claude-usage（精确 tool 统计），ccusage/tokscale（按工具类型分解）

### 1.2 增强 message_id 去重

**当前**: 内存中按 `message.id + requestId` 去重，用 `[String: IndexedMessageUsage]` 字典。

**改动**:

- 将去重键写入 SQLite `tool_calls` 表，添加 `UNIQUE INDEX`
- 每次解析后检查去重命中率，用于质量校验
- 记录 `duplicate_count` 到数据质量报告（帮助理解偏差来源）

**涉及文件**: `ClaudeDataReader.swift`, `Database/Schema.swift`, `Database/Repository.swift`

**参考**: phuryn/claude-usage（`UNIQUE INDEX ON turns(message_id)`），ccusage/tokscale（exact dedup by message_id）

### 1.3 数据质量可解释化

**当前**: `DataQualityStatus` 只有 level + summary，不解释"为什么有偏差"。

**改动**:

- `buildDataQualityStatus` 返回 `diffBreakdown: [String: DiffDetail]`
- `DiffDetail` 包含:
  - `source`: 差异来源（如 "session X 的 JSONL 缺少 usage 字段"）
  - `jsonlValue`: JSONL 聚合值
  - `cacheValue`: stats-cache 值
  - `explanation`: 原因分析（cache 延迟 / 解析遗漏 / 数据源不一致）
  - `actionable`: 建议操作（"刷新 cache" / "检查 JSONL 完整性"）
- UI 展示为可展开的诊断面板

**涉及文件**: `AppState.swift`, `TokenSummarySection.swift`

**参考**: darshannere/observagent（失败聚类），anjor-labs/anjor（可诊断性）

### 1.4 周数据精确 Token 分解

**当前**: 当 JSONL 无当日数据时，用 `dailyModelTokens` 的总量 × `modelRatios` 近似分摊。

**改动**:

- 将 JSONL 解析的当日数据持久化到 SQLite
- 周数据优先从 SQLite 查询（已有数据），不足时补 JSONL 实时解析
- 消除 `modelRatios` 近似分摊（只在无 JSONL 数据时回退到 stats-cache 的精确值）

**涉及文件**: `AppState.swift`, `Database/Repository.swift`

### 1.4 Burn Rate（消耗速率）作为一级指标

**当前**: 无任何 burn rate 展示。用户无法感知"当前消耗多快"，这是 cctray 和 Claude-Usage-Tracker 的核心价值。

**改动**:

- 计算实时 burn rate：
  - `tokens/min` — 最近 5 分钟的 token 消耗速率
  - `messages/min` — 最近 5 分钟的消息速率
  - 如有 cost 数据：`$/min`
  - `remaining_time` — 基于当前速率，距今日预估上限的剩余时间
- 新增 `BurnRateSection` 放在 Token 摘要下方，展示为紧凑数字卡片
- 颜色编码：绿（< 300 tokens/min）、黄（300-700）、红（> 700）
- 菜单栏图标同步使用此 burn rate 做颜色编码（Phase 4.2）

**涉及文件**: 新建 `Services/BurnRateTracker.swift`，新建 `Views/Sections/BurnRateSection.swift`

**参考**: goniszewski/cctray（burn rate + remaining time），Claude-Usage-Tracker（6 级 pace 系统）

### 1.5 Context Window 追踪

**当前**: `ModelUsage.contextWindow` 字段存在于数据模型但未使用。用户不知道当前会话的上下文窗口剩余多少。

**改动**:

- 从会话 JSONL 解析时追踪累计的 context window 使用量：
  - `input_tokens` + `output_tokens` + `cache_tokens` = 单次请求的 context 消耗
  - 对活跃会话累计所有请求，计算已用 context 百分比
- 展示在活跃会话卡片上：`Context: 142K/200K (71%)`
- 超过 80% 时警告（黄色），超过 95% 时严重警告（红色）
- 子代理的 context 单独追踪

**涉及文件**: `ClaudeDataReader.swift`（context 追踪），`ActiveSessionSection.swift`（展示）

**参考**: anjor-labs/anjor（context window observability），observagent（subagent context tracking）

### 1.6 项目级聚合

**当前**: 数据聚合只有"全局"和"单会话"两个维度，缺少项目视角。

**改动**:

- 按项目（cwd）聚合今日和历史的 Token/Cost/Session 数据
- 新增 `ProjectSummary` 视图：
  - 项目列表 + 每个项目的今日用量
  - 点击展开项目详情（模型分布、趋势、历史会话）
  - 项目间对比（按 Token 或 Cost 排序）
- 持久化到 SQLite `daily_stats` 表时增加 `project_id` 字段

**涉及文件**: `ClaudeDataReader.swift`（按项目过滤），新建 `Views/Sections/ProjectSummarySection.swift`，修改 `Database/Schema.swift`

**参考**: kmizzi/claude-code-sessions（按项目筛选），specter（multi-project dashboard）

---

## Phase 2: 持久性能 (Persistent Cache)

**目标**: 增量索引跨重启持久化，减少冷启动和轮询开销。

### 2.1 增量索引持久化

**当前**: `usageIndex` 是内存字典 `var usageIndex: [String: [JsonlRangeKey: FileUsageIndexEntry]]`，重启丢失。

**改动**:

- 新增 SQLite 表 `processed_files`:
  ```sql
  CREATE TABLE processed_files (
      path TEXT PRIMARY KEY,
      mtime REAL NOT NULL,
      file_size INTEGER NOT NULL,
      line_count INTEGER NOT NULL,
      offset INTEGER NOT NULL DEFAULT 0,
      message_count INTEGER NOT NULL DEFAULT 0,
      tool_call_count INTEGER NOT NULL DEFAULT 0,
      total_tokens INTEGER NOT NULL DEFAULT 0,
      last_accessed REAL NOT NULL
  );
  CREATE INDEX idx_processed_files_last_accessed ON processed_files(last_accessed);
  ```
- `ClaudeDataReader` 初始化时从 SQLite 加载索引
- 每次 `parseJsonlUsage` 完成时更新 SQLite
- 增量策略不变（path + mtime + offset），但跨重启生效
- 超过上限时按 `last_accessed` 淘汰

**涉及文件**: `Database/Schema.swift`, `Database/Repository.swift`, `ClaudeDataReader.swift`

**参考**: phuryn/claude-usage（`processed_files` 表 + mtime 追踪）

### 2.2 会话级使用记录持久化

**当前**: SQLite 的 `sessions` / `session_token_usage` / `daily_stats` 表已定义但未使用。

**改动**:

- 每次 `refreshData()` 后将结果写入 SQLite
- `sessions` 表记录会话元数据（pid, sessionId, cwd, startedAt, kind）
- `session_token_usage` 记录每个会话的精确 Token 用量
- `daily_stats` 记录每日聚合
- `daily_model_usage` 记录每日 × 模型的 Token 分解

**涉及文件**: `AppState.swift` (写入), `Database/Repository.swift`

**参考**: phuryn/claude-usage（sessions/turns 表），observagent/anjor（SQLite 持久化）

### 2.3 多频率轮询

**当前**: 单一 30s 定时器轮询所有数据源。

**改动**:

- 拆分为多个频率：
  - 活跃会话 + 用量：10s（用户正在操作，需要即时反馈）
  - 今日统计：30s（中期趋势）
  - 历史会话：60s（低频变化）
  - 周数据：60s（低频变化）
- 使用独立 Timer 或优先级队列实现
- 错误时启动指数退避（1s → 2s → 4s → 8s → 16s → 32s → 60s max）

**涉及文件**: `DataPoller.swift`

**参考**: exelban/stats（每模块独立刷新间隔），cctray（指数退避）

### 2.4 增量扫描优化

**当前**: `readTodayUsage()` 每次遍历所有项目目录的 JSONL 文件。

**改动**:

- 使用 SQLite `processed_files` 表快速定位"今日有变更的文件"（`mtime > today_start`）
- 只解析增量部分（从 offset 开始）
- 文件未变更时直接从缓存读取上次结果
- 预期冷启动性能提升 5-10x（取决于文件数量）

**涉及文件**: `ClaudeDataReader.swift`

**参考**: phuryn/claude-usage（增量扫描器）

---

## Phase 3: 实时可观测 (Real-time Observability)

**目标**: 从轮询升级为事件驱动，实现 tool_use 级别的实时追踪。

### 3.1 Claude Code Hooks 集成

**当前**: 纯文件轮询，最快速度受限于 10-30s 间隔。

**改动**:

- 注册 Claude Code hooks（PreToolUse / PostToolUse / SubagentStart / SubagentStop）
- Hook 脚本将事件写入本地 Unix socket 或 HTTP 端点
- 应用启动时监听该端点，接收实时事件流
- 事件格式：
  ```json
  {
    "type": "post_tool_use",
    "tool": "Read",
    "input": { "file_path": "/path/to/file" },
    "duration_ms": 120,
    "timestamp": "2026-04-25T12:00:00Z",
    "session_id": "d5510623-..."
  }
  ```
- UI 实时更新工具调用计数和分布

**涉及文件**: 新建 `Services/HookServer.swift`（Unix socket 或 HTTP 监听），修改 `AppDelegate.swift`（注册 hooks），新建 `Models/HookEvent.swift`

**参考**: darshannere/observagent（hooks → SSE），anjor-labs/anjor（hook-based 事件流）

### 3.2 会话级实时时间线

**目标**: 点击活跃会话时，展开 tool_use 的实时时间线。

**改动**:

- 新增 `SessionDetailSheet` 视图（从活跃会话卡片点击展开）
- 展示：
  - 消息时间线（user → assistant → tool_use → assistant）
  - 每次调用的工具名、耗时、结果摘要
  - Token 消耗瀑布图
- 子代理展开（显示 subagent 的独立时间线）

**涉及文件**: 新建 `Views/Sections/SessionDetailSheet.swift`，修改 `ActiveSessionSection.swift`

**参考**: darshannere/observagent（诊断面板），anjor-labs/anjor（实时工具调用视图）

### 3.3 轮询降级策略

**当 hooks 不可用时的降级方案**:

- 回退到多频率轮询（Phase 2.3）
- 文件变更检测：使用 `DispatchSourceFileSystemObject` 监控 JSONL 文件的写事件，比定时轮询更快
- 错误时指数退避

**涉及文件**: `DataPoller.swift`

### 3.4 通知/告警系统

**当前**: 完全无告警机制。用户需要主动打开菜单栏才能看到信息。

**改动**:

- 新增 `NotificationManager`，基于 `UNUserNotificationCenter`：
  - **预算告警**：当日 cost 超过阈值时通知（可配置：¥50 / ¥100 / ¥500）
  - **异常消耗**：1 小时内的 Token 消耗是日常均值的 3 倍以上
  - **会话卡住**：活跃会话超过 30 分钟但 token 增长为 0
  - **模型切换**：当前会话模型从高 cost 模型（Opus）切换到低 cost 模型（Haiku）时提示
- 告警规则可在 Preferences 中配置（开/关 + 阈值）
- macOS 原生通知，支持 Action（"查看详情" / "忽略"）

**涉及文件**: 新建 `Services/NotificationManager.swift`，修改 `Preferences` 窗口

**参考**: goniszewski/cctray（NotificationManager），gitify-app/gitify（通知设计范式）

### 3.5 Subagent 独立可观测

**当前**: Subagent 数据直接合并到父会话，无法区分 subagent 和主会话的成本占比。

**改动**:

- 解析时区分主会话和 subagent 的数据
- 会话详情页增加 subagent 折叠面板：
  - 每个 subagent 的名称/ID、启动时间、token 用量、工具调用数
  - subagent 的 cost 占父会话的比例（饼图）
  - subagent 的 tool_use 分布
- 持久化 subagent 统计到 SQLite（新增 `subagent_stats` 表）

**涉及文件**: 新建 `Database/Schema.swift`（subagent_stats 表），修改 `ClaudeDataReader.swift`（subagent 数据分离），修改 `SessionDetailSheet.swift`

**参考**: darshannere/observagent（subagent observability），anjor-labs/anjor（subagent cost breakdown）

### 3.6 订阅/计费方案感知

**当前**: 无任何方案/限额感知。

**改动**:

- 新增 `BillingPlanManager`：
  - 用户选择当前 Claude Code tier（Pro/Team/Enterprise）
  - 内嵌各 tier 的 rate limit 和上下文窗口上限
  - 展示"已用 / 限额"比例条（类似 cctray 的 billing plan 面板）
  - 接近限额时触发 Phase 3.4 的告警
- 注意：Claude Code 的 Pro tier 没有固定 rate limit，但有 soft cap。Team/Enterprise 有明确的 monthly token cap。

**涉及文件**: 新建 `Services/BillingPlanManager.swift`，修改 `TokenSummarySection.swift`

**参考**: goniszewski/cctray（BillingPlanManager），Claude-Usage-Tracker（multi-tier rate limits）

---

## Phase 4: 模块化 UI (Modular UI)

**目标**: 面板可定制，按需展示，减少信息过载。

### 4.1 可开关面板模块

**当前**: `MonitorView` 硬编码了 6 个 Section，全部显示。

**改动**:

- 每个 Section 可独立开关（Preferences 设置）
- 新增 `UserPreferences` 的 `moduleVisibility: [ModuleID: Bool]`
- `ModuleID` 枚举: `.tokenSummary`, `.trendChart`, `.modelConsumption`, `.activeSessions`, `.recentSessions`, `.toolCalls`
- 拖拽排序（可选，后续迭代）

**涉及文件**: `MonitorView.swift`, `AppState.swift`（preferences 扩展），各 Section 文件

**参考**: exelban/stats（每模块独立开关）

### 4.2 动态菜单栏图标

**当前**: 静态 NSStatusItem 图标。

**改动**:

- 颜色编码阈值（token burn rate）：
  - 绿色：< 300 tokens/min（空闲）
  - 黄色：300-700 tokens/min（活跃）
  - 红色：> 700 tokens/min（高负载）
- 轮播显示：每 5 秒切换显示当前指标（今日 tokens → 今日 cost → messages/min → sessions）
- 脉冲动画：当达到 threshold 时图标闪烁

**涉及文件**: `AppDelegate.swift`，新建 `Services/MenuBarDisplayManager.swift`

**参考**: goniszewski/cctray（动态图标颜色 + 轮播），Claude-Usage-Tracker（6 级 pace 系统）

### 4.3 信息密度模式

**目标**: 根据用户场景切换信息密度。

**改动**:

- **紧凑模式**：只显示核心数字（今日 tokens + 数据质量状态）
- **标准模式**（当前）：完整 Section 列表
- **详细模式**：展开所有 Sub-details（模型分解、工具分布、会话时间线）
- 快捷键切换（Cmd+1/2/3）

**涉及文件**: `MonitorView.swift`，各 Section 的 compact/detail 变体

**参考**: Claude-Usage-Tracker（状态线 + 多视图）

---

## Phase 5: 深度分析 (Deep Analysis)

**目标**: 从"今日监控"扩展到"历史洞察"。

### 5.1 会话浏览与搜索

**目标**: 列出所有历史会话，支持筛选和搜索。

**改动**:

- 新建 `Views/Sections/SessionBrowserView.swift`
- 功能：
  - 按项目/日期/模型筛选
  - 关键词搜索（从 JSONL 转录中搜索）
  - 按 tokens 排序
  - 点击展开会话详情（Phase 3.2 的时间线）

**涉及文件**: 新建 `SessionBrowserView.swift`，`Database/Repository.swift`（会话查询），修改 `MonitorView.swift`（添加导航）

**参考**: kmizzi/claude-code-sessions（检索/筛选/回放）

### 5.2 会话回放

**目标**: 按时间顺序逐步重放历史会话的对话过程，不只是看统计，而是"回到对话中"。

**改动**:

- 从 JSONL 转录文件构建对话时间线
- 支持逐步回放（播放/暂停/步进）
- 每条消息展示：
  - 用户消息（纯文本）
  - AI 回复（含工具调用、思考过程）
  - Token 用量标注
  - 时间戳
- 支持搜索定位（关键词跳转到对应消息）
- 高亮显示异常点（高 cost 消息、错误、长时间停顿）

**涉及文件**: 新建 `Views/Sections/SessionReplayView.swift`，从 JSONL 直接读取（不经 SQLite）

**参考**: kmizzi/claude-code-sessions（replay capability）

### 5.2 贡献热力图

**目标**: GitHub-style 的 Token 使用热力图。

**改动**:

- 新增 `Views/Sections/ContributionHeatmap.swift`
- 展示最近 12 个月的每日 Token 使用量
- 颜色深浅 = tokens 数量
- 点击某一天展开该日详情

**涉及文件**: 新建 `ContributionHeatmap.swift`，从 SQLite `daily_stats` 读取数据

**参考**: junhoyeo/tokscale（2D + 3D 热力图）

### 5.3 Cost 估算

**目标**: 展示 USD 成本估算。

**改动**:

- 新增 `Services/PricingTable.swift`（内嵌 Anthropic 定价表）
- 每个模型的 Token → USD 转换
- 按日/周/月聚合成本
- 周数据中的 cost 趋势图

**涉及文件**: 新建 `PricingTable.swift`，修改 `TrendChartSection.swift`（成本视图切换）

**参考**: ccusage/tokscale（LiteLLM 定价表 + 手动 fallback），cctray（billing plan manager）

### 5.4 模型版本迁移分析

**目标**: 追踪模型使用变化趋势。

**改动**:

- 新增 `Views/Sections/ModelMigrationChart.swift`
- 展示每月各模型的使用占比变化
- 堆叠面积图（面积 = tokens）
- 突出显示高 cost 模型的使用

**涉及文件**: 新建 `ModelMigrationChart.swift`，从 SQLite `daily_model_usage` 读取

---

## 四、数据库 Schema 规划

### 新增表

```sql
-- 已处理文件索引（Phase 2.1）
CREATE TABLE IF NOT EXISTS processed_files (
    path TEXT PRIMARY KEY,
    mtime REAL NOT NULL,
    file_size INTEGER NOT NULL,
    line_count INTEGER NOT NULL,
    offset INTEGER NOT NULL DEFAULT 0,
    message_count INTEGER NOT NULL DEFAULT 0,
    tool_call_count INTEGER NOT NULL DEFAULT 0,
    total_tokens INTEGER NOT NULL DEFAULT 0,
    last_accessed REAL NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_processed_files_mtime ON processed_files(mtime);
CREATE INDEX IF NOT EXISTS idx_processed_files_last_accessed ON processed_files(last_accessed);

-- 工具调用明细（Phase 1.1）
CREATE TABLE IF NOT EXISTS tool_call_details (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT NOT NULL,
    tool_name TEXT NOT NULL,
    tool_input TEXT,
    timestamp REAL NOT NULL,
    dedup_key TEXT UNIQUE
);
CREATE INDEX IF NOT EXISTS idx_tool_calls_session ON tool_call_details(session_id);
CREATE INDEX IF NOT EXISTS idx_tool_calls_name ON tool_call_details(tool_name);

-- 子代理统计（Phase 3.5）
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

### 已有但未使用的表（保持现有 Schema）

| 表 | 用途 | Phase 启用 |
|----|------|-----------|
| `sessions` | 会话元数据 | Phase 2.2 |
| `session_token_usage` | 会话 Token 用量 | Phase 2.2 |
| `daily_stats` | 每日聚合统计 | Phase 2.2 |
| `daily_model_usage` | 每日 × 模型 Token | Phase 2.2 |
| `tool_calls` | 工具调用计数 | Phase 1.1（扩展） |

---

## 五、UI 设计方向

### 当前 UI 结构

```
ScrollView
├── TokenSummarySection (今日 Token + 质量校验)
├── TrendChartSection (7日堆叠柱状图)
├── ModelConsumptionSection (模型分解)
├── ActiveSessionSection (活跃会话)
├── RecentSessionSection (历史会话)
├── ToolCallSection (工具调用)
```

### 目标 UI 结构（Phase 4 完成后）

```
Preferences (可定制模块)
├── 菜单栏模块
│   ├── 图标颜色编码 (开/关)
│   ├── 轮播显示 (开/关)
│   └── 轮播间隔 (秒)
├── 告警设置
│   ├── 预算阈值 (¥)
│   ├── 异常消耗检测 (开/关)
│   ├── 会话卡住检测 (开/关)
│   └── 通知权限引导
└── 面板模块
    ├── Token 摘要 [√]
    ├── **Burn Rate 卡片** [√]  ← 新增
    ├── 趋势图 [√]
    ├── 模型分解 [√]
    ├── 活跃会话 (含 Context Window) [√]
    ├── **Subagent 详情** [√]  ← 新增
    ├── 历史会话 [ ]
    ├── 工具调用 [√]
    ├── 数据质量诊断 [√]
    ├── **项目聚合** [√]  ← 新增
    ├── 贡献热力图 [ ]
    ├── 成本估算 [ ]
    └── 会话浏览器/回放 [ ]
```

### 设计参考

| 模块 | 视觉参考 | 关键设计要素 |
|------|---------|------------|
| Token 摘要 | cctray | 颜色编码 + 简洁数字 |
| **Burn Rate** | **cctray** | **实时数字 + pace 颜色 + 剩余时间** |
| 趋势图 | tokscale | 堆叠柱状 + Token 分解 |
| 工具调用 | observagent | 实时时间线 + 工具名标签 |
| 数据质量 | anjor | 可展开诊断面板 |
| **Context Window** | **anjor** | **进度条 + 阈值颜色** |
| **Subagent 面板** | **observagent** | **折叠面板 + 成本占比饼图** |
| 贡献图 | tokscale | GitHub-style 热力图 |
| 会话浏览器 | kmizzi | 搜索 + 筛选 + 列表 |
| **会话回放** | **kmizzi** | **逐步播放 + 对话流 + 高亮异常** |

---

## 六、实施优先级建议

### 推荐顺序

```
Phase 1 (数据可信 + 核心指标) → 必须先做：消除假数据 + 建立 burn rate + context window 展示
Phase 2 (持久性能) → 解决重启丢失和轮询开销，为后续 hooks 打基础
Phase 3 (实时可观测 + 告警) → 通知系统、subagent 独立追踪、hooks 实时事件
Phase 4 (模块化 UI) → 用户体验提升最直观，用户可定制面板
Phase 5 (深度分析) → 会话回放、热力图、成本分析，锦上添花
```

### 每 Phase 的独立价值

| Phase | 独立价值 | 依赖 |
|-------|---------|------|
| Phase 1 | 消除所有假数据 + burn rate/context window 一级指标 + 项目级聚合 | 无 |
| Phase 2 | 重启后增量生效，冷启动性能 5-10x | Phase 1 |
| Phase 3 | 实时追踪 + 告警推送 + subagent 独立可观测 | Phase 2（持久化基础） |
| Phase 4 | 用户可定制面板 + 动态图标 + 密度模式 | Phase 1（数据是前提） |
| Phase 5 | 历史洞察 + 成本分析 + 会话回放 | Phase 2（SQLite 持久化） |

---

## 七、风险与注意事项

### 技术风险

1. **Hooks 注册的权限问题** — macOS 沙箱可能阻止 Unix socket 监听
2. **SQLite 并发读写** — `ClaudeDataReader` 和 `AppState` 可能同时写入，需要 WAL 模式
3. **JSONL 文件数量增长** — 长期运行后 `processed_files` 表可能很大，需要定期清理
4. **内存 vs SQLite 索引一致性** — 双重索引（内存 + SQLite）需要保持同步
5. **通知权限** — macOS 需要用户授权 `UNUserNotificationCenter` 权限，首次启动需引导
6. **Context Window 估算误差** — Claude Code 的实际 context 使用量可能与 JSONL 中的 token 统计有偏差（系统消息、thinking 等未计入的部分）
7. **Burn Rate 波动** — 短时间内的高频请求会导致 burn rate 虚高，需要滑动窗口平滑（推荐 5 分钟 EMA）

### 设计决策注意事项

1. **不引入遥测** — 保持 Specter 的"纯本地只读"定位，这是可信度卖点
2. **不替换 stats-cache** — 它是 Claude Code 官方产物，我们只读取不写入
3. **hooks 是可选的** — 即使 hooks 不可用，轮询回退方案必须完整可用
4. **保持 SQLite 包引用** — 继续使用 SQLite.swift，不引入新依赖
5. **SQLite 是本地缓存** — 强调所有数据仅存储在本地，不上传、不遥测，与 Specter 的"纯本地"定位一致
6. **订阅方案感知是可选的** — 用户可选择不关联方案，基础功能不受影响
