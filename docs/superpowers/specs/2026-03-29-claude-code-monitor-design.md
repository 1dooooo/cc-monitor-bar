# Claude Code Monitor - 设计文档

**日期**: 2026-03-29
**状态**: 待审阅
**版本**: 1.0

---

## 1. 概述

Claude Code Monitor 是一款 macOS 原生菜单栏应用，用于监控 Claude Code 的所有本地行为。工具从本地文件系统获取数据（不使用远端 API），使用 SQLite 持久化存储，提供三种可切换的 UI 风格（极简/数据看板/时间线），采用液态玻璃效果的现代化设计。

### 1.1 核心功能

- **会话监控**: 追踪活跃会话状态、时长、项目路径
- **Token 统计**: 实时估算当前会话 Token 消耗、展示历史 Token 趋势
- **模型分析**: 按模型聚合使用量、成本估算（可选）
- **历史回顾**: 会话历史列表、时间线事件、数据看板分析

### 1.2 数据来源

| 文件路径 | 内容 | 用途 |
|----------|------|------|
| `~/.claude/stats-cache.json` | Token 聚合统计 | Token 增量计算基准 |
| `~/.claude/history.jsonl` | 会话消息历史 | 交叉验证、历史列表 |
| `~/.claude/sessions/*.json` | 活跃会话元数据 | 会话发现、PID 追踪 |
| `~/.claude/projects/*/*.jsonl` | 项目级会话记录 | 项目维度聚合 |

---

## 2. 架构设计

```
┌─────────────────────────────────────────────────────────┐
│                    Menu Bar Icon                        │
│                         │                               │
│                         ▼                               │
│  ┌─────────────────────────────────────────────────┐   │
│  │              Popover Window                      │   │
│  │  ┌───────────────────────────────────────────┐  │   │
│  │  │           Active View Controller          │  │   │
│  │  │  ┌─────────┬─────────┬─────────┐         │  │   │
│  │  │  │ Minimal │ Dashboard │ Timeline │      │  │   │
│  │  │  └─────────┴─────────┴─────────┘         │  │   │
│  │  └───────────────────────────────────────────┘  │   │
│  └─────────────────────────────────────────────────┘   │
│                         │                               │
│                         ▼                               │
│  ┌─────────────────────────────────────────────────┐   │
│  │              Service Layer                       │   │
│  │  • DataPoller (可配置轮询间隔)                   │   │
│  │  • TokenEstimator (增量计算 + 交叉验证)          │   │
│  │  • SessionTracker (会话发现 + 多会话分配)        │   │
│  │  • ProjectResolver (Git 根目录识别)              │   │
│  └─────────────────────────────────────────────────┘   │
│                         │                               │
│                         ▼                               │
│  ┌─────────────────────────────────────────────────┐   │
│  │           SQLite Database (Core Data)           │   │
│  │  • sessions                                     │   │
│  │  • session_token_usage                          │   │
│  │  • daily_stats                                  │   │
│  │  • daily_model_usage                            │   │
│  │  • tool_calls                                   │   │
│  │  • session_baseline (运行时)                    │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

### 2.1 分层说明

| 层级 | 职责 | 关键组件 |
|------|------|----------|
| **UI 层** | 菜单栏图标、Popover 窗口、三视图切换 | `AppDelegate`、`ContentView`、视图控制器 |
| **服务层** | 数据轮询、Token 估算、会话追踪 | `DataPoller`、`TokenEstimator`、`SessionTracker` |
| **数据层** | SQLite 持久化、查询聚合 | `DatabaseManager`、Repository |

---

## 3. UI 设计

### 3.1 视图切换

- **位置**: 设置面板中选择默认视图，或记忆上次关闭时的视图
- **方式**: 不在主界面显示切换控件（节省空间），通过设置或快捷键切换

### 3.2 极简风格 (Minimal View)

**定位**: 当前会话实时监控

**布局**:
```
┌─────────────────────────────────────┐
│  Claude Code Monitor           _ ✕  │
├─────────────────────────────────────┤
│  ╭─────────────────────────────╮    │
│  │   ● 会话进行中              │    │
│  │   mac-cc-bar                │    │
│  │   已运行 2h 34m             │    │
│  ╰─────────────────────────────╯    │
│                                     │
│  ──── 本次会话 ────                 │
│  Token     │  45,678 ≈ (置信度：中) │
│  消息数    │  23                    │
│  工具调用  │  12                    │
│  模型      │  glm-5.1               │
│                                     │
│  ──── 消耗趋势 ────                 │
│  ▃▅▇▆▄▅▇ (分钟级趋势)               │
│                                     │
│  ─────────────────────────────────  │
│  历史会话 (向下滚动)                │
│                                     │
│  昨天 14:00 - 15:30  mac-cc-bar     │
│         12,456 token · 8 tools      │
│  昨天 09:00 - 10:20  docker-new-api │
│         8,234 token · 5 tools       │
└─────────────────────────────────────┘
```

**核心组件**:
- `CurrentSessionCard`: 活跃会话状态卡片
- `TokenDisplay`: Token 显示（支持估算标记）
- `HistoryList`: 历史会话滚动列表

### 3.3 数据看板风格 (Dashboard View)

**定位**: 历史数据聚合分析（无当前会话概念）

**布局**:
```
┌─────────────────────────────────────┐
│  Claude Code Monitor           _ ✕  │
├─────────────────────────────────────┤
│  [概览]  [模型]  [会话]  [工具]      │
├─────────────────────────────────────┤
│ ┌───────────────┐ ┌───────────────┐ │
│ │ 今日 Token    │ │ 本周 Token    │ │
│ │ 2,456,789     │ │ 12,345,678    │ │
│ │ ↑ 12%         │ │ ↑ 8%          │ │
│ └───────────────┘ └───────────────┘ │
│ ┌───────────────┐ ┌───────────────┐ │
│ │ 今日会话数    │ │ 平均会话时长  │ │
│ │ 5             │ │ 1h 23m        │ │
│ └───────────────┘ └───────────────┘ │
│                                     │
│ ───── Token 消耗 (7 日) ───────      │
│ │▇│▇│▆│▇│▅│▇│▇│  [日/周/月切换]     │
│ ─────────────────────────────────   │
│                                     │
│ ───── 模型分布 (本周) ───────        │
│ glm-5.1    ████████████  78%        │
│ qwen3.5    ████░░░░░░░░  18%        │
│ 其他       ██░░░░░░░░░░   4%        │
│                                     │
│ ───── 最活跃项目 Top 5 ──────        │
│ mac-cc-bar      ████████  34%       │
│ docker-new-api  █████░░░  22%       │
└─────────────────────────────────────┘
```

**核心组件**:
- `StatCard`: 统计卡片（支持趋势箭头）
- `TokenChart`: Token 趋势图
- `ModelDistribution`: 模型分布条形图
- `ProjectRanking`: 项目活跃度排行

### 3.4 时间线风格 (Timeline View)

**定位**: 历史事件快照浏览

**布局**:
```
┌─────────────────────────────────────┐
│  Claude Code Monitor           _ ✕  │
├─────────────────────────────────────┤
│  < 2026 年 3 月 >                    │
│  [日] [周] [月]                      │
├─────────────────────────────────────┤
│  3 月 29 日 今天                    │
│  ├─ 09:00  ▶ 会话 #48392 启动       │
│  │         项目：mac-cc-bar         │
│  │         快照：12,456 token       │
│  │         [查看快照详情]           │
│  ├─ 14:00  ⚡ Tool Call 峰值        │
│  │         Bash×23, Glob×12         │
│  └─ 17:30  ■ 会话 #48392 结束       │
│            总计：45,678 token       │
└─────────────────────────────────────┘
```

**快照详情**:
```
╭─────────────────────────────────────╮
│ 会话快照 #48392                     │
├─────────────────────────────────────┤
│ 启动时间  │ 2026-03-29 09:00:54    │
│ 项目路径  │ ~/project/mac/cc-bar   │
│ 模型      │ glm-5.1                │
│ Token     │ 12,456 (in: 10k, out: 2k) │
│ 消息数    │ 15                     │
│ Tool Calls│ Bash×5, Read×3, ...    │
╰─────────────────────────────────────╯
```

**核心组件**:
- `TimelineView`: 时间线主容器
- `TimelineEvent`: 时间线事件项
- `SnapshotDetail`: 快照详情弹窗

---

## 4. 设置面板设计

```
┌─────────────────────────────────────┐
│  设置                          _ ✕  │
├─────────────────────────────────────┤
│  ──── 视图 ────                     │
│  默认视图                           │
│  [  极简  │ 数据看板 │ 时间线  ]    │
│                                     │
│  记住上次关闭时的视图               │
│  [●] 开启                           │
│                                     │
│  ──── 数据 ────                     │
│  刷新频率                           │
│  3s ───●───────────────── 30min     │
│         30 秒                       │
│                                     │
│  数据显示格式                       │
│  [●] 紧凑格式  [ ] 详细格式         │
│                                     │
│  ──── Token ────                    │
│  显示成本估算                       │
│  [ ] 开启 (需配置 API 价格)          │
│                                     │
│  月度预算警告                       │
│  [ ] 开启   限额：$______           │
│                                     │
│  ──── 系统 ────                     │
│  [ ] 开机自启                       │
│  菜单栏图标                         │
│  [●] 默认  [ ] 简约  [ ] 彩色       │
│  主题                               │
│  [●] 跟随系统  [ ] 浅色  [ ] 深色   │
│                                     │
│  ──── 存储 ────                     │
│  数据保留期限                       │
│  [ ]7 天  [●]30 天  [ ]90 天  [ ] 永久│
│                                     │
│  SQLite 文件位置                    │
│  ~/Library/Application Support/     │
│  ClaudeMonitor/data.db              │
│                [更改位置...]         │
│                                     │
│           [保存]  [取消]            │
└─────────────────────────────────────┘
```

### 4.1 设置项说明

| 分类 | 设置项 | 类型 | 默认值 |
|------|--------|------|--------|
| 视图 | 默认视图 | 三选一 | 极简 |
| 视图 | 记忆上次视图 | 布尔 | true |
| 数据 | 刷新频率 | 滑块 (3s-30min) | 30s |
| 数据 | 数据显示格式 | 布尔 | 紧凑 |
| Token | 显示成本估算 | 布尔 | false |
| Token | 月度预算警告 | 布尔 + 金额 | false |
| 系统 | 开机自启 | 布尔 | false |
| 系统 | 菜单栏图标 | 三选一 | 默认 |
| 系统 | 主题 | 三选一 | 跟随系统 |
| 存储 | 数据保留期限 | 四选一 | 30 天 |
| 存储 | SQLite 文件位置 | 路径 | 默认路径 |

---

## 5. 数据层设计

### 5.1 表结构

```sql
-- 1. 会话历史表
CREATE TABLE sessions (
    id              TEXT PRIMARY KEY,      -- UUID
    pid             INTEGER,
    project_path    TEXT,
    project_id      TEXT,                  -- Git 根目录/规范化路径
    started_at      INTEGER NOT NULL,      -- Unix timestamp
    ended_at        INTEGER,
    duration_ms     INTEGER,
    message_count   INTEGER DEFAULT 0,
    tool_call_count INTEGER DEFAULT 0,
    entrypoint      TEXT                   -- 'cli' | 'gui' | 'ide'
);

-- 2. Token 使用表（按会话）
CREATE TABLE session_token_usage (
    session_id          TEXT PRIMARY KEY,
    input_tokens        INTEGER DEFAULT 0,
    output_tokens       INTEGER DEFAULT 0,
    cache_read_tokens   INTEGER DEFAULT 0,
    cache_write_tokens  INTEGER DEFAULT 0,
    model               TEXT NOT NULL,
    is_estimated        BOOLEAN DEFAULT 0,  -- 是否估算值
    confidence          TEXT DEFAULT 'medium', -- high/medium/low
    FOREIGN KEY (session_id) REFERENCES sessions(id)
);

-- 3. 每日统计表
CREATE TABLE daily_stats (
    date            TEXT PRIMARY KEY,      -- YYYY-MM-DD
    message_count   INTEGER DEFAULT 0,
    session_count   INTEGER DEFAULT 0,
    tool_call_count INTEGER DEFAULT 0,
    input_tokens    INTEGER DEFAULT 0,
    output_tokens   INTEGER DEFAULT 0,
    cache_tokens    INTEGER DEFAULT 0
);

-- 4. 模型使用表（按日期 + 模型）
CREATE TABLE daily_model_usage (
    date            TEXT NOT NULL,
    model           TEXT NOT NULL,
    input_tokens    INTEGER DEFAULT 0,
    output_tokens   INTEGER DEFAULT 0,
    cache_tokens    INTEGER DEFAULT 0,
    PRIMARY KEY (date, model)
);

-- 5. 工具调用表
CREATE TABLE tool_calls (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id      TEXT NOT NULL,
    timestamp       INTEGER NOT NULL,
    tool_name       TEXT NOT NULL,
    duration_ms     INTEGER,
    success         BOOLEAN DEFAULT 1,
    FOREIGN KEY (session_id) REFERENCES sessions(id)
);

-- 6. 会话 baseline 表（运行时状态）
CREATE TABLE session_baseline (
    session_id          TEXT PRIMARY KEY,
    started_at          INTEGER NOT NULL,
    baseline_tokens_json TEXT NOT NULL,   -- JSON: {"glm-5.1": 12345}
    last_scan_at        INTEGER,
    estimated_delta     INTEGER DEFAULT 0,
    confidence          TEXT DEFAULT 'medium',
    project_id          TEXT
);

-- 索引
CREATE INDEX idx_sessions_started ON sessions(started_at);
CREATE INDEX idx_sessions_project ON sessions(project_id);
CREATE INDEX idx_daily_stats_date ON daily_stats(date);
CREATE INDEX idx_tool_calls_session ON tool_calls(session_id);
```

### 5.2 数据流

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Claude Code    │     │   DataPoller     │     │   SQLite        │
│  Local Files    │────▶│  • 解析 JSONL    │────▶│   Database      │
│  • stats-cache  │     │  • 去重/合并     │     │  • 聚合查询     │
│  • history.jsonl│     │  • 增量更新      │     │  • 历史趋势     │
│  • sessions/*   │     │                  │     │                 │
└─────────────────┘     └──────────────────┘     └─────────────────┘
                                                        │
                                                        ▼
                                              ┌─────────────────┐
                                              │   TokenEstimator│
                                              │  • baseline 差值 │
                                              │  • 交叉验证     │
                                              │  • 置信度标记   │
                                              └─────────────────┘
```

---

## 6. Token 估算方案

### 6.1 核心算法

```
会话启动时 (T0):
  1. 读取 stats-cache.json 中各模型的累计 Token
  2. 记录为 baseline: { glm-5.1: 4938361, ... }
  3. 写入 session_baseline 表

定期扫描 (每 N 秒):
  1. 读取 stats-cache.json 最新累计值
  2. 计算增量：current - baseline = 本次会话消耗
  3. 交叉验证:
     - 读取 history.jsonl / projects/*.jsonl
     - 统计新增消息的字符数
     - 按模型 token 率估算 (中文~1.5 字符/token)
     - 计算差异率：|估算值 - 增量值| / 增量值
     - 差异率 > 20% → 置信度标记为 "low"

会话结束时:
  1. 最终扫描 stats-cache.json
  2. 计算总会话增量
  3. 写入 session_token_usage 表 (is_estimated=true)
  4. 从 session_baseline 删除记录
```

### 6.2 多会话 Token 分配

```
场景 1: 不同项目
  → 独立计算，不冲突

场景 2: 同项目多会话
  → 加权分配:
     weight = (active_time_ratio × 0.3) + (message_count_ratio × 0.7)
     session_token = total_delta × weight

示例:
  项目 X 有 2 个会话 A 和 B，总增量 1000 token
  会话 A: active_time=60%, message_count=70%
  weight_A = 0.3×0.6 + 0.7×0.7 = 0.67
  Token_A = 1000 × 0.67 = 670
```

### 6.3 项目识别 (ProjectResolver)

```
1. 规范化路径:
   - 去除末尾 "/"
   - 解析 "." ".."
   - 统一大小写 (macOS HFS+ 不区分大小写)

2. Git 根目录匹配:
   - 从 cwd 向上查找 .git 目录
   - 如果找到，使用 Git 根目录作为 project_id
   - 否则使用规范化路径作为 project_id

示例:
   /Users/ido/project/mac/cc-bar      → project_id: "mac-cc-bar" (Git 根)
   /Users/ido/project/mac/cc-bar/src  → project_id: "mac-cc-bar" (同一项目)
```

### 6.4 Token 估算公式

| 模型 | 估算方式 |
|------|----------|
| glm-5 / glm-5.1 | 中文 ~1.5 字符/token, 英文 ~4 字符/token |
| qwen3.5-plus | 中文 ~1.5 字符/token, 英文 ~4 字符/token |
| kimi-k2.5 | 中文 ~1.5 字符/token, 英文 ~4 字符/token |

**混合内容估算**:
```
total_tokens = (chinese_chars / 1.5) + (english_chars / 4)
```

---

## 7. 技术实现

### 7.1 技术栈

| 组件 | 技术 |
|------|------|
| 语言 | Swift 5.9+ |
| UI 框架 | SwiftUI + AppKit (菜单栏集成) |
| 数据持久化 | SQLite.swift (或 Core Data) |
| 文件监控 | DispatchSourceFileSystemObject + 轮询 |
| 液态玻璃效果 | NSVisualEffectView + SwiftUI Material |

### 7.2 关键代码示例

```swift
// 液态玻璃背景
struct GlassBackground: View {
    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
        }
    }
}

// 菜单栏入口
@main
struct ClaudeCodeMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.squareLength
        )
        popover = NSPopover()
        popover?.contentViewController = NSHostingController(
            rootView: ContentView()
        )
        popover?.behavior = .transient
        popover?.animates = true

        statusItem?.button?.action = #selector(togglePopover)
        statusItem?.button?.image = NSImage(
            systemSymbolName: "chart.bar.fill",
            accessibilityDescription: "Claude Monitor"
        )
    }

    @objc func togglePopover() {
        if let button = statusItem?.button {
            if popover?.isShown == true {
                popover?.performClose(nil)
            } else {
                popover?.show(
                    relativeTo: button.bounds,
                    of: button,
                    preferredEdge: .minY
                )
            }
        }
    }
}
```

### 7.3 项目目录结构

```
ClaudeCodeMonitor/
├── ClaudeCodeMonitor/
│   ├── App/
│   │   ├── ClaudeCodeMonitorApp.swift
│   │   ├── AppDelegate.swift
│   │   └── Info.plist
│   │
│   ├── Views/
│   │   ├── ContentView.swift
│   │   ├── Minimal/
│   │   │   ├── MinimalView.swift
│   │   │   ├── CurrentSessionCard.swift
│   │   │   └── HistoryList.swift
│   │   ├── Dashboard/
│   │   │   ├── DashboardView.swift
│   │   │   ├── StatCard.swift
│   │   │   ├── TokenChart.swift
│   │   │   └── ModelDistribution.swift
│   │   ├── Timeline/
│   │   │   ├── TimelineView.swift
│   │   │   ├── TimelineEvent.swift
│   │   │   └── SnapshotDetail.swift
│   │   └── Components/
│   │       ├── GlassBackground.swift
│   │       ├── SegmentedControl.swift
│   │       └── FrequencySlider.swift
│   │
│   ├── Models/
│   │   ├── Session.swift
│   │   ├── TokenUsage.swift
│   │   ├── DailyStats.swift
│   │   └── ToolCall.swift
│   │
│   ├── Services/
│   │   ├── DataPoller.swift
│   │   ├── ClaudeDataReader.swift
│   │   ├── TokenEstimator.swift
│   │   ├── SessionTracker.swift
│   │   └── ProjectResolver.swift
│   │
│   ├── Database/
│   │   ├── DatabaseManager.swift
│   │   ├── Schema.swift
│   │   └── Repository.swift
│   │
│   ├── Settings/
│   │   ├── SettingsView.swift
│   │   └── AppPreferences.swift
│   │
│   └── Resources/
│       ├── Assets.xcassets
│       └── Preview Content/
│
├── ClaudeCodeMonitor.xcodeproj
└── README.md
```

---

## 8. 验收标准

### 8.1 功能验收

- [ ] 菜单栏图标正常显示，点击弹出 popover
- [ ] 三种视图风格可切换，布局符合设计
- [ ] 设置面板可配置所有选项，设置持久化
- [ ] 活跃会话检测准确，Token 估算误差 < 20%
- [ ] 历史会话列表完整，支持滚动
- [ ] 数据看板图表正确展示趋势
- [ ] 时间线事件按时间排序，快照详情准确

### 8.2 性能验收

- [ ] 应用启动时间 < 2 秒
- [ ] Popover 打开响应时间 < 200ms
- [ ] 数据轮询不阻塞 UI（后台执行）
- [ ] 内存占用 < 100MB（空闲时）

### 8.3 数据准确性

- [ ] 会话发现延迟 < 轮询间隔 + 1 秒
- [ ] Token 估算值与 stats-cache 最终值差异 < 20%
- [ ] 多会话分配逻辑正确（同项目加权）
- [ ] 项目识别准确（Git 根目录匹配）

---

## 9. 后续迭代

### Phase 2 (可选功能)

1. **Hook 集成**: 编写 Claude Code hook 脚本，精确记录每次请求的 Token
2. **Tokenizer 集成**: 引入官方 tokenizer 库，提高估算精度
3. **成本计算**: 支持配置各模型 API 价格，显示实时成本
4. **导出功能**: 导出 CSV/JSON 报告
5. **通知提醒**: Token 预算警告、会话时长提醒

### Phase 3 (扩展功能)

1. **跨平台**: Tauri/Electron 版本
2. **远端同步**: 可选同步到远端数据库
3. **团队协作**: 共享 Token 使用统计

---

## 10. 风险与缓解

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| stats-cache.json 格式变更 | 高 | 版本检测 + 降级处理 |
| Token 估算误差过大 | 中 | 交叉验证 + 置信度标记 |
| 多会话并发分配不准 | 中 | 加权算法 + 用户反馈 |
| 文件权限问题 | 低 | 启动时检查权限 |
| 高频轮询影响性能 | 低 | 最小间隔限制 (3s) + 增量读取 |

---

**文档结束**
