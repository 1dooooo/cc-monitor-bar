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
├── 面板模块
│   ├── Token 摘要 [√]
│   ├── 趋势图 [√]
│   ├── 模型分解 [√]
│   ├── 活跃会话 [√]
│   ├── 历史会话 [ ]
│   ├── 工具调用 [√]
│   ├── 数据质量诊断 [√]
│   ├── 贡献热力图 [ ]
│   ├── 成本估算 [ ]
│   └── 会话浏览器 [ ]
└── 信息密度
    ├── 紧凑 / 标准 / 详细
    └── 刷新频率预设
```

### 设计参考

| 模块 | 视觉参考 | 关键设计要素 |
|------|---------|------------|
| Token 摘要 | cctray | 颜色编码 + 简洁数字 |
| 趋势图 | tokscale | 堆叠柱状 + Token 分解 |
| 工具调用 | observagent | 实时时间线 + 工具名标签 |
| 数据质量 | anjor | 可展开诊断面板 |
| 贡献图 | tokscale | GitHub-style 热力图 |
| 会话浏览器 | kmizzi | 搜索 + 筛选 + 列表 |

---

## 六、实施优先级建议

### 推荐顺序

```
Phase 1 (数据可信) → 必须先做，否则所有 UI 展示的都是不可信数据
Phase 2 (持久性能) → 解决重启丢失和轮询开销，为后续 hooks 打基础
Phase 4 (模块化 UI) → 用户体验提升最直观
Phase 3 (实时可观测) → 依赖 Phase 2 的基础设施
Phase 5 (深度分析) → 锦上添花，随时可以加
```

### 每 Phase 的独立价值

| Phase | 独立价值 | 依赖 |
|-------|---------|------|
| Phase 1 | 消除所有假数据，统计口径精确化 | 无 |
| Phase 2 | 重启后增量生效，冷启动性能 5-10x | Phase 1（工具调用持久化） |
| Phase 3 | 实时 tool_use 级别追踪，< 1s 延迟 | Phase 2（事件流基础设施） |
| Phase 4 | 用户可定制面板，信息密度可控 | 无（但 Phase 1 的数据是前提） |
| Phase 5 | 历史洞察 + 成本分析 | Phase 2（SQLite 持久化） |

---

## 七、风险与注意事项

### 技术风险

1. **Hooks 注册的权限问题** — macOS 沙箱可能阻止 Unix socket 监听
2. **SQLite 并发读写** — `ClaudeDataReader` 和 `AppState` 可能同时写入，需要 WAL 模式
3. **JSONL 文件数量增长** — 长期运行后 `processed_files` 表可能很大，需要定期清理
4. **内存 vs SQLite 索引一致性** — 双重索引（内存 + SQLite）需要保持同步

### 设计决策注意事项

1. **不引入遥测** — 保持 Specter 的"纯本地只读"定位，这是可信度卖点
2. **不替换 stats-cache** — 它是 Claude Code 官方产物，我们只读取不写入
3. **hooks 是可选的** — 即使 hooks 不可用，轮询回退方案必须完整可用
4. **保持 SQLite 包引用** — 继续使用 SQLite.swift，不引入新依赖
