# Claude Code macOS 数据源调研文档

> 文档版本：1.0
> 最后更新：2026-03-29
> 调研目的：为开发 macOS 端 Claude Code 监控工具提供数据源分析

---

## 目录

1. [概述](#1-概述)
2. [核心数据源](#2-核心数据源)
3. [数据结构详解](#3-数据结构详解)
4. [监控工具架构建议](#4-监控工具架构建议)
5. [实现参考代码](#5-实现参考代码)
6. [参考项目](#6-参考项目)

---

## 1. 概述

### 1.1 调研背景

Claude Code 在 macOS 本地存储了丰富的会话、token、模型使用数据。本文档详细分析了所有可获取的数据源，为开发监控工具提供技术依据。

### 1.2 数据位置

所有数据存储在 `~/.claude/` 目录下：

```
~/.claude/
├── backups/                          # Token/Cost 核心数据
├── projects/                         # 会话完整记录
├── sessions/                         # 当前活跃会话
├── telemetry/                        # 客户端遥测事件
├── history.jsonl                     # 历史会话索引
├── file-history/                     # 文件变更快照
├── tasks/                            # 任务状态
├── plans/                            # 实现计划
└── stats-cache.json                  # 预聚合统计
```

### 1.3 可获取数据总览

| 数据类型 | 是否可获取 | 数据源 | 实时性 |
|---------|----------|--------|--------|
| 历史会话列表 | ✅ | history.jsonl | 实时 |
| 会话完整对话 | ✅ | projects/*/*.jsonl | 实时 |
| Token 消耗 | ✅ | backups/.claude.json.backup.* | 定期 |
| 费用统计 | ✅ | backups/.claude.json.backup.* | 定期 |
| 模型使用 | ✅ | backups/, stats-cache.json | 定期 |
| 工具调用 | ✅ | transcript-cache/, telemetry/ | 实时 |
| SubAgent 活动 | ✅ | projects/*/subagents/*.jsonl | 实时 |
| 上下文使用率 | ✅ | stdin JSON (via hook) | 实时 |
| 文件变更历史 | ✅ | file-history/*/* | 定期 |

---

## 2. 核心数据源

### 2.1 备份文件 - Token 与费用核心数据

**路径**: `~/.claude/backups/.claude.json.backup.*.json`

**更新频率**: 定期自动备份（约每 2-5 分钟）

**数据内容**:
- 每个项目的 token 使用详情
- 按模型分类的 token 统计
- 费用计算（costUSD）
- 会话指标

**数据结构**:
```json
{
  "projects": {
    "/Users/ido/project/docker/new-api": {
      "lastCost": 3.901021,
      "lastModelUsage": {
        "glm-5.1": {
          "inputTokens": 346072,
          "outputTokens": 29805,
          "cacheReadInputTokens": 2851072,
          "cacheCreationInputTokens": 0,
          "costUSD": 3.901021,
          "webSearchRequests": 0,
          "contextWindow": 0,
          "maxOutputTokens": 0
        }
      },
      "lastSessionId": "df6a87f8-ae8d-4b69-916c-f4e91b4974b6",
      "lastSessionMetrics": {
        "frame_duration_ms_count": 67,
        "frame_duration_ms_min": 0.28,
        "frame_duration_ms_max": 6.66,
        "frame_duration_ms_avg": 0.95
      },
      "lastTotalInputTokens": 346072,
      "lastTotalOutputTokens": 29805,
      "lastTotalCacheReadInputTokens": 2851072,
      "lastTotalCacheCreationInputTokens": 0
    }
  }
}
```

**监控工具用途**:
- 计算每日/每周/每月 token 消耗
- 按项目统计费用
- 模型使用成本分析
- Cache 命中率分析

---

### 2.2 会话记录 - 完整对话历史

**路径**: `~/.claude/projects/{project-id}/{session-id}.jsonl`

**更新频率**: 实时追加

**数据内容**:
- 完整对话历史（用户/助手消息）
- 工具调用事件
- 系统事件
- 文件快照

**数据结构** (每行一个 JSON 对象):
```json
{"type":"user","message":{"role":"user","content":"你好"},"timestamp":"2026-03-29T14:04:22.860Z","sessionId":"7c78860b-4bec-4599-b934-49a7b261f0cb"}

{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"你好！有什么可以帮助你的？"}]},"timestamp":"2026-03-29T14:04:25.123Z"}

{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"call_xxx","name":"Read","input":{"file_path":"/path/to/file"}}]},"timestamp":"2026-03-29T14:04:26.456Z"}

{"type":"system","subtype":"local_command","content":"<local-command-stdout></local-command-stdout>","level":"info"}
```

**事件类型**:
| 类型 | 说明 |
|------|------|
| `user` | 用户消息 |
| `assistant` | 助手响应（含工具调用） |
| `system` | 系统事件（命令执行结果等） |
| `file-history-snapshot` | 文件历史快照 |

**监控工具用途**:
- 实时对话流展示
- 工具调用历史追踪
- 会话时长统计
- 消息数量统计

---

### 2.3 历史索引 - 会话快速检索

**路径**: `~/.claude/history.jsonl`

**更新频率**: 实时更新

**数据结构**:
```json
{
  "display": "帮我安装一个 claude-hub",
  "pastedContents": {},
  "timestamp": 1774490200598,
  "project": "/Users/ido",
  "sessionId": "d04ad507-82bf-4a34-b959-dca298737e9a"
}
```

**监控工具用途**:
- 会话列表展示
- 会话快速搜索
- 项目维度聚合

---

### 2.4 活跃会话 - 当前运行状态

**路径**: `~/.claude/sessions/*.json`

**更新频率**: 会话启动时创建

**数据结构**:
```json
{
  "pid": 39569,
  "sessionId": "5e58aa2a-bd72-49dd-ba08-4f879df820c0",
  "cwd": "/Users/ido",
  "startedAt": 1774776959159,
  "kind": "interactive",
  "entrypoint": "cli"
}
```

**监控工具用途**:
- 当前运行会话检测
- 会话进程监控
- 启动方式统计（cli/sdk）

---

### 2.5 遥测数据 - 客户端事件

**路径**: `~/.claude/telemetry/*.json`

**更新频率**: 事件触发时

**事件类型** (从实际数据分析):
| 事件名 | 说明 |
|--------|------|
| `tengu_tool_use_progress` | 工具调用进度 |
| `tengu_tool_search_mode_decision` | 搜索模式决策 |
| `tengu_input_command` | 用户命令输入 |
| `tengu_paste_text` | 粘贴文本事件 |
| `tengu_api_success` | API 调用成功 |
| `tengu_unknown_model_cost` | 模型成本记录 |
| `tengu_skill_loaded` | 技能加载 |
| `tengu_run_hook` | Hook 执行 |

**数据结构**:
```json
{
  "event_type": "ClaudeCodeInternalEvent",
  "event_data": {
    "event_name": "tengu_unknown_model_cost",
    "client_timestamp": "2026-03-27T13:32:17.770Z",
    "model": "glm-5.1",
    "session_id": "04768595-3292-4d70-8217-8305f1c8afbd",
    "user_type": "external",
    "env": {
      "platform": "darwin",
      "version": "2.1.85",
      "arch": "arm64"
    },
    "entrypoint": "cli",
    "is_interactive": true
  }
}
```

**监控工具用途**:
- 工具调用频率分析
- Hook 执行监控
- API 成功率统计

---

### 2.6 文件历史 - 上下文文件快照

**路径**: `~/.claude/file-history/{sessionId}/{hash}@v{version}`

**更新频率**: 文件变更时

**数据结构**:
```
~/.claude/file-history/ab273b05-9fc4-49a9-8d59-bcb06209a186/
  4f7f1f436de257cd@v1
  4f7f1f436de257cd@v2
  6604ed283fdeeb15@v1
  6604ed283fdeeb15@v2
  ...
```

**监控工具用途**:
- 文件变更追踪
- 上下文构建分析
- 代码修改统计

---

### 2.7 预聚合统计 - 快速查询

**路径**: `~/.claude/stats-cache.json`

**更新频率**: 定期更新

**数据结构**:
```json
{
  "version": 2,
  "lastComputedDate": "2026-03-28",
  "dailyActivity": [
    {
      "date": "2026-03-28",
      "messageCount": 4080,
      "sessionCount": 25,
      "toolCallCount": 1336
    }
  ],
  "dailyModelTokens": [
    {
      "date": "2026-03-28",
      "tokensByModel": {
        "glm-5.1": 4571127,
        "kimi-k2.5": 8992,
        "qwen3.5-plus": 7050125
      }
    }
  ],
  "modelUsage": {
    "glm-5.1": {
      "inputTokens": 4938361,
      "outputTokens": 442907,
      "cacheReadInputTokens": 106578496,
      "costUSD": 0
    }
  },
  "totalSessions": 61,
  "totalMessages": 7456,
  "longestSession": {
    "sessionId": "60b351e1-8152-4e83-ad6f-02db5399a191",
    "duration": 19892543,
    "messageCount": 1217
  }
}
```

**监控工具用途**:
- 快速获取聚合数据
- 日报/周报生成
- 趋势分析

---

### 2.8 SubAgent 记录

**路径**: `~/.claude/projects/{project-id}/{session-id}/subagents/agent-*.jsonl`

**更新频率**: SubAgent 活动时

**数据结构**:
```json
{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"call_xxx","name":"Task","input":{"subagent_type":"explore","model":"haiku","description":"搜索 auth 相关代码"}}]}}
```

**监控工具用途**:
- SubAgent 调用统计
- 子任务追踪
- 模型分配分析

---

### 2.9 转录缓存 - 解析后工具历史

**路径**: `~/.claude/plugins/claude-hud/transcript-cache/*.json`

**更新频率**: 会话活动时

**数据结构**:
```json
{
  "transcriptPath": "/Users/ido/.claude/projects/-Users-ido/xxx.jsonl",
  "transcriptState": {
    "mtimeMs": 1774494307561.7356,
    "size": 45172
  },
  "data": {
    "tools": [
      {
        "id": "call_452d15aa",
        "name": "Bash",
        "target": "ls -la...",
        "status": "completed",
        "startTime": "2026-03-26T03:04:05.652Z",
        "endTime": "2026-03-26T03:04:06.241Z"
      }
    ],
    "agents": [],
    "todos": [],
    "sessionStart": "2026-03-26T03:03:53.258Z",
    "sessionName": "linear-churning-salamander"
  }
}
```

**监控工具用途**:
- 最近工具调用展示（最近 20 个）
- 工具执行时长统计
- 活跃工具实时监控

---

## 3. 数据结构详解

### 3.1 完整数据模型

```
Claude Code 数据体系
│
├── 会话维度
│   ├── history.jsonl (索引)
│   ├── projects/{project}/{session}.jsonl (完整记录)
│   ├── sessions/*.json (活跃状态)
│   └── file-history/{session}/ (文件快照)
│
├── Token/Cost 维度
│   ├── backups/.claude.json.backup.* (项目级)
│   └── stats-cache.json (聚合统计)
│
├── 工具维度
│   ├── transcript-cache/*.json (解析后)
│   └── telemetry/*.json (原始事件)
│
└── SubAgent 维度
    └── projects/{project}/{session}/subagents/agent-*.jsonl
```

### 3.2 关键字段映射

| 业务需求 | 数据源 | 字段路径 |
|---------|--------|---------|
| 当前会话 ID | sessions/*.json | `.sessionId` |
| 当前使用模型 | settings.json | `.env.ANTHROPIC_MODEL` |
| 输入 Token 数 | backups/*.json | `.projects[project].lastModelUsage[model].inputTokens` |
| 输出 Token 数 | backups/*.json | `.projects[project].lastModelUsage[model].outputTokens` |
| Cache 命中 | backups/*.json | `.projects[project].lastModelUsage[model].cacheReadInputTokens` |
| 费用 | backups/*.json | `.projects[project].lastCost` |
| 工具调用 | transcript-cache/*.json | `.data.tools[]` |
| SubAgent | projects/*/subagents/*.jsonl | `.message.content[].input.subagent_type` |

---

## 4. 监控工具架构建议

### 4.1 数据源优先级

```
┌─────────────────────────────────────────────────────────────┐
│  Tier 1: 实时数据（高频轮询 ~1 秒）                          │
├─────────────────────────────────────────────────────────────┤
│  - ~/.claude/sessions/*.json        (当前会话)              │
│  - ~/.claude/projects/*/*.jsonl     (追加式对话记录)         │
│  - ~/.claude/plugins/claude-hud/transcript-cache/*.json    │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  Tier 2: 定期聚合（每 5-10 分钟）                             │
├─────────────────────────────────────────────────────────────┤
│  - ~/.claude/backups/.claude.json.backup.*  (token/cost)   │
│  - ~/.claude/stats-cache.json         (预聚合统计)          │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  Tier 3: 事件驱动（监听文件变化）                            │
├─────────────────────────────────────────────────────────────┤
│  - ~/.claude/history.jsonl            (新会话)              │
│  - ~/.claude/telemetry/*.json         (工具/agent 事件)      │
│  - ~/.claude/file-history/*/*         (文件变更)            │
└─────────────────────────────────────────────────────────────┘
```

### 4.2 推荐技术栈

| 功能模块 | 技术方案 | 说明 |
|---------|---------|------|
| 文件监控 | `fswatch` / `FileSystemObserver` | 监听文件变化 |
| JSONL 解析 | 增量读取器 | 只读新增行 |
| 数据持久化 | SQLite / Realm | 本地数据库 |
| UI 框架 | SwiftUI / Electron | macOS 原生或跨平台 |
| 图表库 | Swift Charts / Recharts | 数据可视化 |
| 状态栏 | Swift + AppKit | macOS Menu Bar |

### 4.3 核心监控指标

#### 实时指标（每秒刷新）
- 当前会话 ID
- 会话开始时间
- 当前使用模型
- 活跃工具调用（名称、参数、状态、耗时）
- SubAgent 状态（类型、模型、描述）
- 上下文使用率（需通过 stdin hook 获取）

#### 聚合指标（每分钟刷新）
- 当日 token 消耗（input/output/cache）
- 当日费用
- 会话数量
- 工具调用次数
- 模型使用分布

#### 历史分析
- 按项目聚合 token/cost
- 按模型聚合使用情况
- 最长会话排行
- 最常用工具排行
- 时间段趋势（日/周/月）

### 4.4 系统架构图

```
┌────────────────────────────────────────────────────────────┐
│                      macOS 监控工具                         │
├────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │  文件监控层   │  │   数据解析层  │  │   数据持久层  │     │
│  │              │  │              │  │              │     │
│  │  - fswatch   │  │  - JSONL     │  │  - SQLite    │     │
│  │  - FSEvents  │  │  - JSON      │  │  - Realm     │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│           ↓                ↓                ↓              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │                  业务逻辑层                           │  │
│  │  - Token 聚合  - 费用计算  - 趋势分析  - 告警规则     │  │
│  └──────────────────────────────────────────────────────┘  │
│           ↓                                                 │
│  ┌──────────────────────────────────────────────────────┐  │
│  │                    UI 展示层                          │  │
│  │  - 状态栏插件  - 主窗口  - 图表  - 设置               │  │
│  └──────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────┘
                              ↓
┌────────────────────────────────────────────────────────────┐
│                    ~/.claude/ 数据源                        │
└────────────────────────────────────────────────────────────┘
```

---

## 5. 实现参考代码

### 5.1 读取最新备份文件

```bash
#!/bin/bash
# 获取最新备份文件
LATEST_BACKUP=$(ls -t ~/.claude/backups/.claude.json.backup.* 2>/dev/null | head -1)

# 提取项目 token 数据
cat "$LATEST_BACKUP" | jq '.projects | to_entries[] | {
  project: .key,
  inputTokens: .value.lastTotalInputTokens,
  outputTokens: .value.lastTotalOutputTokens,
  cost: .value.lastCost,
  modelUsage: .value.lastModelUsage
}'
```

### 5.2 监控 JSONL 新增内容

```javascript
// Node.js 示例 - 使用 tail 库监控 JSONL
import Tail from 'tail';

const sessionPath = '/Users/ido/.claude/projects/-Users-ido/xxx.jsonl';
const tail = new Tail(sessionPath);

tail.on('line', (data) => {
  const event = JSON.parse(data);
  if (event.type === 'assistant') {
    // 处理助手响应
    console.log('Assistant:', event.message.content);
  }
  if (event.type === 'user') {
    // 处理用户消息
    console.log('User:', event.message.content);
  }
});
```

### 5.3 Swift 文件监控

```swift
import Foundation
import Combine

class ClaudeCodeMonitor: ObservableObject {
    @Published var currentSession: Session?
    @Published var todayTokens: TokenStats = .empty

    private var sessionObserver: DirectoryObserver?
    private var backupObserver: FileObserver?

    func startMonitoring() {
        // 监控 sessions 目录
        sessionObserver = DirectoryObserver(path: "~/.claude/sessions") { [weak self] changes in
            self?.handleSessionChanges(changes)
        }

        // 监控备份文件
        backupObserver = FileObserver(path: "~/.claude/backups") { [weak self] in
            self?.parseLatestBackup()
        }
    }

    func parseLatestBackup() {
        let backups = try? FileManager.default.contentsOfDirectory(
            at: URL(fileURLWithPath: NSHomeDirectory() + "/.claude/backups"),
            includingPropertiesForKeys: [.contentModificationDateKey]
        )
        .filter { $0.pathExtension == "json" }
        .sorted {
            ($0.resourceValues(forKeys: [.contentModificationDateKey])?.contentModificationDate ?? .distantPast) >
            ($1.resourceValues(forKeys: [.contentModificationDateKey])?.contentModificationDate ?? .distantPast)
        }

        if let latest = backups.first {
            let data = try? Data(contentsOf: latest)
            let backup = try? JSONDecoder().decode(Backup.self, from: data!)
            self.todayTokens = backup?.computeTodayTokens() ?? .empty
        }
    }
}
```

### 5.4 解析 transcript-cache

```javascript
// 获取最近工具调用
const cacheDir = '~/.claude/plugins/claude-hud/transcript-cache';
const cacheFiles = fs.readdirSync(cacheDir);

const tools = [];
for (const file of cacheFiles) {
  const data = JSON.parse(fs.readFileSync(path.join(cacheDir, file)));
  tools.push(...data.data.tools);
}

// 按时间排序，获取最近 20 个
const recentTools = tools
  .sort((a, b) => new Date(b.startTime) - new Date(a.startTime))
  .slice(0, 20);
```

### 5.5 聚合统计计算

```javascript
// 从备份文件计算每日统计
function computeDailyStats(backups) {
  const stats = {};

  for (const backup of backups) {
    const date = new Date(backup.timestamp).toISOString().split('T')[0];

    if (!stats[date]) {
      stats[date] = {
        inputTokens: 0,
        outputTokens: 0,
        cacheReadTokens: 0,
        cost: 0,
        sessions: new Set(),
        models: {}
      };
    }

    for (const [project, data] of Object.entries(backup.projects)) {
      stats[date].sessions.add(data.lastSessionId);
      stats[date].inputTokens += data.lastTotalInputTokens || 0;
      stats[date].outputTokens += data.lastTotalOutputTokens || 0;
      stats[date].cacheReadTokens += data.lastTotalCacheReadInputTokens || 0;
      stats[date].cost += data.lastCost || 0;

      for (const [model, usage] of Object.entries(data.lastModelUsage || {})) {
        if (!stats[date].models[model]) {
          stats[date].models[model] = { inputTokens: 0, outputTokens: 0, cost: 0 };
        }
        stats[date].models[model].inputTokens += usage.inputTokens || 0;
        stats[date].models[model].outputTokens += usage.outputTokens || 0;
        stats[date].models[model].cost += usage.costUSD || 0;
      }
    }
  }

  return stats;
}
```

---

## 6. 参考项目

### 6.1 ccusage

**功能**: Token 使用统计与费用计算

**数据源**: `~/.claude/backups/.claude.json.backup.*`

**安装**: `npm install -g ccusage`

**命令**:
```bash
ccusage session          # 按会话分组
ccusage daily            # 按日期分组
ccusage monthly          # 按月分组
ccusage session --json   # JSON 输出
```

**参考代码**: 读取备份文件解析 `lastModelUsage`

---

### 6.2 claude-hud

**功能**: 实时状态栏显示

**数据源**:
- stdin JSON (上下文、模型)
- transcript JSONL (工具、agent、todos)

**安装**: `/plugin marketplace add jarrodwatts/claude-hud`

**参考代码位置**:
- `~/.claude/plugins/cache/claude-hud/claude-hud/0.0.11/src/transcript.ts` - JSONL 解析
- `~/.claude/plugins/cache/claude-hud/claude-hud/0.0.11/src/usage-api.ts` - usage 数据

---

### 6.3 ai-token-monitor

**功能**: Token 监控（你的配置中已安装）

**配置文件**: `~/.claude/ai-token-monitor-prefs.json`

**配置内容**:
```json
{
  "show_tray_cost": true,
  "usage_tracking_enabled": true,
  "monthly_salary": 1000.0,
  "language": "zh-CN"
}
```

---

## 附录 A: 文件路径速查

| 用途 | 路径 |
|------|------|
| 备份文件 | `~/.claude/backups/.claude.json.backup.*` |
| 会话记录 | `~/.claude/projects/{project-id}/{session-id}.jsonl` |
| 历史索引 | `~/.claude/history.jsonl` |
| 活跃会话 | `~/.claude/sessions/*.json` |
| 遥测事件 | `~/.claude/telemetry/*.json` |
| 文件快照 | `~/.claude/file-history/{session-id}/` |
| 预聚合统计 | `~/.claude/stats-cache.json` |
| SubAgent | `~/.claude/projects/{project}/{session}/subagents/` |
| 转录缓存 | `~/.claude/plugins/claude-hud/transcript-cache/*.json` |
| 用户配置 | `~/.claude/settings.json` |

---

## 附录 B: 关键 JSON 路径速查

```bash
# 当前会话 ID
jq -r '.sessionId' ~/.claude/sessions/*.json

# 项目 token 使用
jq '.projects[].lastTotalInputTokens' ~/.claude/backups/latest.json

# 模型使用明细
jq '.projects[].lastModelUsage' ~/.claude/backups/latest.json

# 每日活动统计
jq '.dailyActivity[]' ~/.claude/stats-cache.json

# 工具调用历史
jq '.data.tools[]' ~/.claude/plugins/claude-hud/transcript-cache/*.json
```

---

## 附录 C: 数据更新频率

| 数据源 | 更新频率 | 延迟 |
|--------|---------|------|
| sessions/*.json | 会话启动时 | 无 |
| projects/*/*.jsonl | 实时追加 | <100ms |
| history.jsonl | 实时 | <1s |
| backups/.claude.json.backup.* | 定期 | 2-5 分钟 |
| stats-cache.json | 定期 | 5-10 分钟 |
| telemetry/*.json | 事件触发 | <1s |
| transcript-cache/*.json | 会话活动时 | <1s |
| file-history/*/* | 文件变更时 | <1s |

---

**文档结束**
