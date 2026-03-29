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
│  ClaudeDataReader    DataPoller    ProjectResolver   │
│  (文件读取)          (定时轮询)    (项目解析)          │
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
│  本地文件 — ~/.claude/                                │
│  stats-cache.json  history.jsonl  sessions/*.json    │
│  projects/*/*.jsonl  projects/*/subagents/*.jsonl    │
└─────────────────────────────────────────────────────┘
```

## 核心数据流

### 1. 实时数据刷新

```
Timer (N 秒)
  → AppState.refreshData()
    → [后台线程]
      1. ClaudeDataReader.readActiveSessions()
         读取 ~/.claude/sessions/*.json → [ActiveSessionInfo]
      2. 对每个活跃会话:
         ClaudeDataReader.readSessionUsage(cwd, sessionId)
         读取 projects/<path>/<sessionId>.jsonl
         + subagents/*.jsonl
         → SessionUsage (精确 Token 数据)
      3. ClaudeDataReader.readHistory(limit: 200)
         读取 ~/.claude/history.jsonl → [HistoryEntry]
      4. ClaudeDataReader.readStatsCache()
         读取 ~/.claude/stats-cache.json → 全局统计
    → [主线程]
      更新 @Published 属性 → SwiftUI 自动刷新
```

### 2. Token 用量计算

**方法：直接解析 JSONL（精确值，非估算）**

每个活跃会话的 Token 数据通过解析 `projects/<encoded-path>/<sessionId>.jsonl` 获取：

1. 逐行读取 JSONL
2. 只取 `type == "assistant"` 且 `stop_reason != null` 的消息（最终汇总，跳过流式片段）
3. 累加 `usage` 字段中的 `input_tokens + output_tokens + cache_read_input_tokens + cache_creation_input_tokens`
4. 同步扫描 `subagents/*.jsonl`，合并子代理的 Token 数据
5. 按 `message.model` 分组统计各模型用量

### 3. 项目路径转换

```
cwd: "/Users/ido/project/mac/cc-bar"
→ cwdToProjectDir() → "-Users-ido-project-mac-cc-bar"
→ 文件路径: ~/.claude/projects/-Users-ido-project-mac-cc-bar/<sessionId>.jsonl
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
| `DataPoller.swift` | 定时轮询器，触发 AppState 刷新 |
| `ProjectResolver.swift` | cwd → projectId 解析（Git 根目录匹配或路径规范化） |
| `KeyboardShortcuts.swift` | 全局快捷键注册与管理 |

### 数据层

| 文件 | 职责 |
|------|------|
| `DatabaseManager.swift` | SQLite 连接管理，数据库初始化 |
| `Schema.swift` | 表结构定义（5 张表的 CREATE SQL） |
| `Repository.swift` | CRUD 封装（sessions、token_usage、daily_stats） |

### 模型层

| 文件 | 职责 |
|------|------|
| `Session.swift` | 会话模型 |
| `SessionUsage.swift` | 会话 Token 用量（含 merging 合并子代理） |
| `TokenUsage.swift` | UI 展示用 Token 用量 |
| `DailyStats.swift` | 每日统计 |
| `ToolCall.swift` | 工具调用记录 |
| `ClaudeDataModels.swift` | Claude 本地文件的数据模型（StatsCache、ActiveSessionInfo 等） |

## 数据库表结构

| 表 | 主键 | 当前使用状态 |
|----|------|-------------|
| sessions | id (TEXT) | Schema 定义，Repository 有 CRUD，AppState 未调用 |
| session_token_usage | session_id (TEXT) | 同上 |
| daily_stats | date (TEXT) | 同上 |
| daily_model_usage | (date, model) 复合 | 同上 |
| tool_calls | id (INTEGER AUTO) | 同上 |

> 注意：当前 AppState 直接从文件读取数据，SQLite 持久化层已定义但未接入主数据流。

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
