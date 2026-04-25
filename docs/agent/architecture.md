# 架构设计

> [AI-AGENT-MAINTAINED]

## 分层架构

```
┌─────────────────────────────────────────────────────┐
│  UI 层 — SwiftUI + AppKit                            │
│  App/        Views/         Settings/    Theme/      │
│  (AppDelegate, AppState)  (各视图)     (设置窗口)   (主题)  │
└──────────────────────┬──────────────────────────────┘
                       │ 观察 @Published
                       ▼
┌─────────────────────────────────────────────────────┐
│  服务层 — 业务逻辑                                    │
│  ClaudeDataReader    DataPoller    FileWatcher       │
│  (文件读取)          (多频轮询)    (文件监听)         │
│  BurnRateTracker    NotificationManager              │
│  (速率计算)          (告警推送)                      │
└──────────────────────┬──────────────────────────────┘
                       │ 读写
                       ▼
┌─────────────────────────────────────────────────────┐
│  数据层                                              │
│  Models/     Database/                               │
│  (数据模型)  (SQLite: Manager → Schema → Repository) │
└──────────────────────┬──────────────────────────────┘
                       │ 读取
                       ▼
┌─────────────────────────────────────────────────────┐
│  本地文件 — ~/.claude/ + Xcode Claude projects        │
│  stats-cache.json  history.jsonl  sessions/*.json    │
│  ~/.claude/projects/*/*.jsonl                         │
│  ~/Library/.../ClaudeAgentConfig/projects/*/*.jsonl  │
│  projects/*/subagents/*.jsonl                        │
└─────────────────────────────────────────────────────┘
```

## 核心数据流

### 1. 实时数据刷新

```
Timer (10s/30s/60s) 或 FileWatcher 事件
  → AppState.refreshData()
    → [后台线程]
      1. ClaudeDataReader.readActiveSessions()
         读取 ~/.claude/sessions/*.json → [ActiveSessionInfo]
      2. 对每个活跃会话:
         ClaudeDataReader.readSessionUsage(cwd, sessionId)
         优先读取 projects/<path>/<sessionId>.jsonl
         若 cwd 映射未命中则按 sessionId 跨项目目录兜底查找
         + subagents/*.jsonl
         → SessionUsage (精确 Token 数据)
      3. ClaudeDataReader.readTodayUsage()
         读取多根目录 projects/*/*.jsonl（按今日时间窗口）→ 今日 Token 精确统计
      4. ClaudeDataReader.readStatsCache()
         读取 ~/.claude/stats-cache.json → 今日计数补充 + 7日趋势 + 质量对账
      5. ClaudeDataReader.readHistory()
         读取 ~/.claude/history.jsonl → [HistoryEntry]
    → [主线程]
      更新 @Published 属性 → SwiftUI 自动刷新
```

### 2. Token 用量计算

**方法：直接解析 JSONL（精确值，非估算）**

每个活跃会话的 Token 数据通过解析 `projects/<encoded-path>/<sessionId>.jsonl` 获取：

1. 逐行读取 JSONL
2. `type == "assistant"` 且存在 `message.usage` 时，按 `message.id(+requestId)` 去重
3. 同一条消息按字段取最大值（input/output/cache），再做汇总
4. `type == "user"` 统计可见用户输入（纯文本或 text/image/file 块，过滤 tool_result/thinking 包装内容）
5. `tool_use` 按 `tool_use.id` 去重计数（保留 tool name 分布）
6. 同步扫描 `subagents/*.jsonl`，合并子代理数据
7. 按 `message.model` 统计总量 + 输入/输出/缓存分解

#### 增量解析索引

`ClaudeDataReader` 维护内存 + SQLite 双层索引（按 path + 时间窗口）：

1. 记录 `offset/carry/mtime/size`
2. 文件只追加时，仅解析新增字节
3. 检测到改写/截断（前缀探针不一致）时自动全量重建
4. 通过访问时间淘汰旧索引，防止内存增长失控
5. 索引持久化到 SQLite `processed_files` 表，重启不丢失

### 3. 核心指标

#### Burn Rate

- 维护最近 5 分钟的 token 消耗时间序列
- EMA 平滑：`α = 0.3`
- 颜色编码：🟢 < 300 / 🟡 300-700 / 🔴 > 700 tokens/min

#### Context Window

- 从 JSONL 解析累计的 `input_tokens`（已包含完整 conversation context）
- 对比模型 context window 上限
- 颜色阈值：🟢 < 60% / 🟡 60-85% / 🔴 > 85%

### 4. 数据质量校验链路

```
readTodayUsage() (实时 JSONL)
  + readStatsCache() (预聚合 cache)
  → buildDataQualityStatus()
  → level: healthy/warning/critical/unavailable
  → diffRatio: token/message/session/tool 四维差异
  → reason: cache 延迟 / 解析遗漏 / 数据源不一致
  → TokenSummarySection 校验提示
```

### 5. 项目路径转换

```
cwd: "/Users/ido/project/mac/cc-bar"
→ cwdToProjectDir() → "-Users-ido-project-mac-cc-bar"
→ 文件路径（优先）: ~/.claude/projects/-Users-ido-project-mac-cc-bar/<sessionId>.jsonl
→ 未命中时按 `sessionId` 在已配置项目根目录中兜底搜索
```

## 模块职责

### App 层

| 文件 | 职责 |
|------|------|
| `CCMonitorBarApp.swift` | @main 入口，TipKit 配置 |
| `AppDelegate.swift` | NSStatusItem 菜单栏图标、NSPopover 弹出窗口、全局快捷键 |
| `AppState.swift` | ObservableObject 全局状态，数据轮询调度，@Published 属性驱动 UI |

### 服务层

| 文件 | 职责 |
|------|------|
| `ClaudeDataReader.swift` | 核心读取服务：stats-cache、sessions、history、per-session JSONL |
| `DataPoller.swift` | 多频率定时轮询器，错误指数退避 |
| `FileWatcher.swift` | DispatchSourceFileSystemObject 文件写入事件监听 |
| `BurnRateTracker.swift` | Burn Rate 计算（EMA 平滑） |
| `NotificationManager.swift` | 系统告警推送 |
| `ProjectResolver.swift` | cwd → projectId 解析（Git 根目录匹配或路径规范化） |

### 数据层

| 文件 | 职责 |
|------|------|
| `DatabaseManager.swift` | SQLite 连接管理，WAL 模式 |
| `Schema.swift` | 表结构定义（5 张已有表 + processed_files + subagent_stats） |
| `Repository.swift` | CRUD 封装（sessions、token_usage、daily_stats） |

### 模型层

| 文件 | 职责 |
|------|------|
| `ClaudeDataModels.swift` | Claude 本地文件的数据模型（StatsCache、ActiveSessionInfo、DailyActivity 等） |
| `SessionUsage.swift` | 会话 Token 用量（含 merging 合并子代理） |

## 数据库表结构

| 表 | 主键 | 用途 |
|----|------|------|
| `sessions` | id (TEXT) | 会话元数据 |
| `session_token_usage` | session_id (TEXT) | 会话 Token 用量 |
| `daily_stats` | date (TEXT) | 每日聚合（含 project_id） |
| `daily_model_usage` | (date, model) 复合 | 每日 × 模型 Token |
| `tool_calls` | id (INTEGER AUTO) | 工具调用（含 dedup_key UNIQUE） |
| `processed_files` | path (TEXT) | 增量索引持久化 |
| `subagent_stats` | id (TEXT) | Subagent 独立统计 |

## 单面板 UI 结构

```
MonitorView (ScrollView, 垂直滚动)
├── TokenSummarySection      # 今日 Token + 数据质量状态
├── BurnRateSection          # 消耗速率（Phase 4 新增）
├── TrendChartSection        # 7日堆叠柱状图
├── ModelConsumptionSection   # 模型消耗分解
├── ActiveSessionSection      # 活跃会话（含 Context Window）
├── ProjectSummarySection     # 项目级聚合（Phase 4 新增）
├── TopToolsSection           # 真实工具调用分布
└── RecentSessionSection      # 最近会话
```

## 主题系统

```
DesignTokens (常量)  ←  ColorTheme (三主题)  ←  ThemeEnvironment (SwiftUI 注入)
      ↓                      ↓
   间距/圆角/尺寸          颜色映射 (背景/卡片/强调色/模型色/工具色)
```

三套主题：
- **native** — 跟随系统外观自动适配
- **frosted** — 毛玻璃通透效果
- **warm** — Claude 暖色调
