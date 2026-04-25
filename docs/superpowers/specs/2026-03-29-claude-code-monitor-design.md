# cc-monitor-bar 架构设计

> 版本：2.0 · 日期：2026-04-25
> 状态：已批准

## 1. 概述

cc-monitor-bar 是一款 macOS 原生菜单栏应用，用于本地监控 Claude Code 的使用情况。应用**纯本地只读**，从 `~/.claude/` 目录获取数据，不依赖任何远程 API 或云端服务。

### 核心能力

- **实时会话监控** — 追踪活跃会话状态、Token 消耗、Context Window 用量
- **精确 Token 统计** — 从 JSONL 转录文件直接解析，非估算
- **Burn Rate 追踪** — 滑动窗口 EMA 计算消耗速率
- **数据质量校验** — JSONL 实时数据与 stats-cache 对账
- **7 日趋势** — 堆叠柱状图展示输入/输出/缓存三维 Token 分解
- **项目级聚合** — 按项目维度对比 Token 用量

### 数据来源

| 文件 | 内容 | 用途 |
|------|------|------|
| `~/.claude/stats-cache.json` | 全局聚合统计 | 7 日趋势 + 与 JSONL 对账校验 |
| `~/.claude/history.jsonl` | 会话历史索引 | 历史会话列表 |
| `~/.claude/sessions/*.json` | 活跃会话元数据 | 会话发现、PID 追踪 |
| `~/.claude/projects/*/*.jsonl` | 会话转录 | Token 精确统计、工具调用、模型分解 |
| `projects/*/subagents/*.jsonl` | 子代理转录 | 合并到主会话，独立追踪 |
| `~/Library/Developer/Xcode/.../projects/*/*.jsonl` | Xcode Claude 转录 | 额外扫描源 |

---

## 2. 架构

```
┌──────────────────────────────────────────────────┐
│  NSStatusItem (菜单栏图标)                        │
│  · burn rate 颜色编码                            │
│  · 轮播显示 tokens/min / sessions / context%     │
└──────────────────────┬───────────────────────────┘
                       │ NSPopover
                       ▼
┌──────────────────────────────────────────────────┐
│  MonitorView (单面板，垂直滚动)                    │
│  · TokenSummarySection                           │
│  · BurnRateSection                               │
│  · TrendChartSection                             │
│  · ModelConsumptionSection                       │
│  · ActiveSessionSection (含 Context Window)      │
│  · ProjectSummarySection                         │
│  · TopToolsSection                               │
│  · RecentSessionSection                          │
└──────────────────────┬───────────────────────────┘
                       │ @Published
                       ▼
┌──────────────────────────────────────────────────┐
│  AppState (ObservableObject)                      │
│  · 调度数据轮询                                   │
│  · 管理 @Published 状态                           │
│  · 数据质量校验 (buildDataQualityStatus)          │
└──────┬───────────────────────────────┬────────────┘
       │                               │
       ▼                               ▼
┌──────────────────────┐   ┌────────────────────────┐
│  ClaudeDataReader    │   │  DataPoller            │
│  · 解析 JSONL        │   │  · 多频率轮询           │
│  · 增量索引          │   │  · 错误指数退避         │
│  · 去重/聚合         │   │  · FileWatcher 监听     │
│  · readTodayUsage    │   │                        │
│  · readSessionUsage  │   │                        │
└──────┬───────────────┘   └────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────────────┐
│  SQLite 持久化层 (SQLite.swift)                    │
│  · sessions / session_token_usage                 │
│  · daily_stats (含 project_id)                    │
│  · daily_model_usage                              │
│  · tool_calls (含 dedup_key UNIQUE)               │
│  · processed_files (增量索引持久化)                │
│  · subagent_stats                                 │
└──────┬────────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────────────┐
│  ~/.claude/ 本地文件 (只读)                        │
└──────────────────────────────────────────────────┘
```

### 分层说明

| 层级 | 职责 | 关键文件 |
|------|------|---------|
| **UI** | 单面板渲染，响应式更新 | `MonitorView.swift`, `Sections/*.swift` |
| **状态** | 数据轮询调度，@Published 驱动 UI | `AppState.swift` |
| **服务** | 文件读取、增量解析、去重聚合 | `ClaudeDataReader.swift` |
| **轮询** | 多频率定时器，文件监听 | `DataPoller.swift`, `FileWatcher.swift` |
| **数据** | SQLite 持久化 | `Database/` 目录 |
| **模型** | 数据模型定义 | `Models/` 目录 |

---

## 3. 数据流

### 3.1 刷新流程

```
Timer (10s/30s/60s) / FileWatcher 事件
  → AppState.refreshData()
    → [后台线程]
      1. ClaudeDataReader.readActiveSessions()
         → [ActiveSessionInfo]
      2. 对每个活跃会话:
         ClaudeDataReader.readSessionUsage(cwd, sessionId)
         → SessionUsage (精确 Token 数据)
      3. ClaudeDataReader.readTodayUsage()
         → TodayStats (今日 JSONL 聚合)
      4. ClaudeDataReader.readStatsCache()
         → 数据质量校验 + 7 日趋势补充
      5. ClaudeDataReader.readHistory()
         → [HistoryEntry]
    → [主线程]
      更新 @Published 属性 → SwiftUI 刷新
```

### 3.2 Token 精确统计

**不再使用估算**。直接从 JSONL 转录文件解析：

1. 按 `message.id + requestId` 去重（流式片段会重复写入同一条消息）
2. `type == "assistant"` 且有 `message.usage` 时，按字段取最大值后汇总
3. `type == "user"` 统计可见用户输入（过滤 tool_result/thinking 包装）
4. `tool_use` 按 `tool_use.id` 去重计数（保留 tool name 分布）
5. 同步扫描 `subagents/*.jsonl`，合并子代理数据

### 3.3 增量解析索引

内存索引 + SQLite 持久化：

1. 记录 `path + mtime + offset`
2. 文件只追加时，仅解析新增字节
3. 检测到改写/截断（前缀探针不一致）时自动全量重建
4. 索引持久化到 `processed_files` 表，重启不丢失

### 3.4 数据质量校验

```
readTodayUsage() (实时 JSONL)
  + readStatsCache() (预聚合 cache)
  → buildDataQualityStatus()
    → level: healthy/warning/critical/unavailable
    → diffRatio: token/message/session/tool 四个维度的相对差异
    → reason: cache 延迟 / 解析遗漏 / 数据源不一致
    → suggestion: 建议操作
  → TokenSummarySection 校验提示
```

---

## 4. 核心指标

### 4.1 Burn Rate

- 维护最近 5 分钟的 token 消耗时间序列
- EMA 平滑：`ema_new = α * current + (1 - α) * ema_old`，α = 0.3
- 输出 `tokens/min`（5 分钟 EMA）
- 颜色编码：🟢 < 300 / 🟡 300-700 / 🔴 > 700 tokens/min

### 4.2 Context Window

- 从 JSONL 解析每个活跃会话的累计 context 使用
- `input_tokens` 已包含完整 conversation context（system prompt + history）
- 展示：`Context: 142K / 200K (71%)`
- 阈值：🟢 < 60% / 🟡 60-85% / 🔴 > 85%

---

## 5. 数据库 Schema

### 已有表（从 Phase 2 启用）

| 表 | 主键 | 用途 |
|----|------|------|
| `sessions` | id (TEXT) | 会话元数据 |
| `session_token_usage` | session_id (TEXT) | 会话 Token 用量 |
| `daily_stats` | date (TEXT) | 每日聚合（含 `project_id`） |
| `daily_model_usage` | (date, model) | 每日 × 模型 Token |
| `tool_calls` | id (INTEGER AUTO) | 工具调用（含 `dedup_key UNIQUE`） |

### 新增表

```sql
-- 已处理文件索引（增量解析持久化）
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

-- Subagent 统计
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
```

---

## 6. 技术实现

### 6.1 技术栈

| 组件 | 技术 |
|------|------|
| 语言 | Swift 5.9+ |
| UI 框架 | SwiftUI + AppKit (菜单栏集成) |
| 数据持久化 | SQLite.swift |
| 文件监控 | DispatchSourceFileSystemObject |
| 通知 | UNUserNotificationCenter |

### 6.2 项目目录结构

```
cc-monitor-bar/
├── App/
│   ├── CCMonitorBarApp.swift
│   ├── AppDelegate.swift
│   └── AppState.swift
├── Views/
│   ├── MonitorView.swift
│   ├── Sections/
│   │   ├── TokenSummarySection.swift
│   │   ├── BurnRateSection.swift
│   │   ├── TrendChartSection.swift
│   │   ├── ModelConsumptionSection.swift
│   │   ├── ActiveSessionSection.swift
│   │   ├── ProjectSummarySection.swift
│   │   ├── TopToolsSection.swift
│   │   └── RecentSessionSection.swift
│   └── Components/
│       ├── GlassBackground.swift
│       ├── ProgressBar.swift
│       └── Badge.swift
├── Models/
│   ├── ClaudeDataModels.swift
│   ├── SessionUsage.swift
│   └── Session.swift
├── Services/
│   ├── ClaudeDataReader.swift
│   ├── DataPoller.swift
│   ├── FileWatcher.swift
│   ├── BurnRateTracker.swift
│   ├── ProjectResolver.swift
│   └── NotificationManager.swift
├── Database/
│   ├── DatabaseManager.swift
│   ├── Schema.swift
│   └── Repository.swift
└── Settings/
    └── AppPreferences.swift
```

### 6.3 纯本地定位

- **不引入遥测** — 保持 Specter 的"纯本地只读"定位
- **不替换 stats-cache** — Claude Code 官方产物，只读取不写入
- **SQLite 是本地缓存** — 所有数据仅存储在本地
- **hooks 是可选的** — 文件监听是主要实时通道，hooks 只是增强

---

## 7. 风险与缓解

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| macOS Full Disk Access 权限 | JSONL 文件无法读取 | 首次启动引导用户授权 |
| stats-cache.json 格式变更 | 对账校验失败 | 版本检测 + 降级处理 |
| SQLite 并发读写 | 写入冲突 | WAL 模式 |
| JSONL 文件数量增长 | 索引表膨胀 | 定期清理 > 7 天未访问条目 |
| Burn Rate 波动 | 虚高/迟钝 | EMA 平滑（α=0.3, 5 分钟窗口） |
| 多会话并发读取 | 数据覆盖 | SQLite 串行写入 + WAL |

---

**文档结束**
