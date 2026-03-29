# 数据来源

> [AI-AGENT-MAINTAINED]

## 概述

应用只读取 `~/.claude/` 目录下的本地文件，不调用任何远程 API。所有数据来自 Claude Code CLI 自动写入的文件。

## 数据文件

### 1. stats-cache.json — 全局聚合统计

**路径**: `~/.claude/stats-cache.json`

```json
{
  "version": 2,
  "lastComputedDate": "2026-03-28",
  "dailyActivity": [
    { "date": "2026-03-28", "messageCount": 4080, "sessionCount": 25, "toolCallCount": 1336 }
  ],
  "dailyModelTokens": [
    { "date": "2026-03-28", "tokensByModel": { "glm-5.1": 4571127 } }
  ],
  "modelUsage": {
    "glm-5.1": {
      "inputTokens": 4938361,
      "outputTokens": 442907,
      "cacheReadInputTokens": 106578496,
      "cacheCreationInputTokens": 0,
      "webSearchRequests": 0,
      "costUSD": 0,
      "contextWindow": 0,
      "maxOutputTokens": 0
    }
  }
}
```

**用途**: 全局 Token 统计、模型用量分布、7 日趋势数据

**限制**: 只有全局聚合数据，无 per-session 分解；`lastComputedDate` 可能不总是最新

### 2. sessions/*.json — 活跃会话元数据

**路径**: `~/.claude/sessions/*.json`

```json
{
  "pid": 24364,
  "sessionId": "d5510623-06e4-4d79-b0da-3b8e68735fc5",
  "cwd": "/Users/ido/project/mac/cc-monitor-bar",
  "startedAt": 1775139748957,
  "kind": "interactive",
  "entrypoint": "sdk-ts"
}
```

**用途**: 发现当前正在运行的 Claude Code 会话

**注意**: 文件存在 = 会话活跃，会话结束后文件被删除

### 3. projects/*/*.jsonl — 会话转录（核心数据源）

**路径**: `~/.claude/projects/<encoded-cwd>/<sessionId>.jsonl`

路径编码规则：将 cwd 的 `/` 替换为 `-`，例如 `/Users/ido/project/mac/cc-bar` → `-Users-ido-project-mac-cc-bar`

**关键记录类型**:

| type | 说明 | 含 usage |
|------|------|---------|
| `user` | 用户消息 | 否 |
| `assistant` | AI 回复 | 是（见下方） |
| `system` | 系统事件 | 否 |

**assistant 消息的关键结构**:

```json
{
  "type": "assistant",
  "message": {
    "role": "assistant",
    "model": "glm-5.1",
    "stop_reason": "tool_use",
    "usage": {
      "input_tokens": 29589,
      "output_tokens": 235,
      "cache_read_input_tokens": 320,
      "cache_creation_input_tokens": 0
    },
    "content": [
      { "type": "thinking" },
      { "type": "text", "text": "..." },
      { "type": "tool_use", "name": "Read" }
    ]
  }
}
```

**关键区分**:

| 条件 | 含义 | usage 值 |
|------|------|---------|
| `stop_reason != null` | 最终汇总消息 | 完整精确值 |
| `stop_reason == null` | 流式输出中间片段 | `{input_tokens: 0, output_tokens: 0}` |

**计算规则**: 只累加 `stop_reason != null` 的条目的 usage 字段。

### 4. projects/*/subagents/*.jsonl — 子代理转录

**路径**: `~/.claude/projects/<encoded-cwd>/<sessionId>/subagents/agent-<id>.jsonl`

格式与主 JSONL 相同，也包含 assistant 的 usage 数据。需要合并到主会话统计中。

### 5. history.jsonl — 会话历史索引

**路径**: `~/.claude/history.jsonl`

```json
{ "display": "who are you", "timestamp": 1773852790476, "project": "/Users/ido/project/test", "sessionId": "30fd6140-..." }
```

**用途**: 获取历史会话列表、项目归属、去重

## Token 计算逻辑

### 当前方案：直接解析 JSONL（精确值）

```
readSessionUsage(cwd, sessionId)
  → parseJsonlUsage("<basePath>.jsonl")        // 主转录
  → parseJsonlUsage("subagents/agent-*.jsonl")  // 子代理
  → merging()                                    // 合并
```

`parseJsonlUsage` 算法：
1. 逐行读取 JSONL
2. `type == "user"` → messageCount++
3. `type == "assistant"` 且 `stop_reason != null`:
   - 累加 input_tokens, output_tokens, cache_read_input_tokens, cache_creation_input_tokens
   - 按 message.model 分组
   - 统计 content 中 tool_use 数量

### 已废弃方案：基线差值法

~~通过记录 stats-cache.json 在会话启动时的全局 Token 作为基线，定期计算差值。~~ 已删除。直接解析 JSONL 更精确。

## 数据流汇总

```
┌─ AppState.refreshData() ─────────────────────────────────┐
│                                                           │
│  sessions/*.json    → readActiveSessions()                │
│       ↓                    ↓                              │
│  ActiveSessionInfo   readSessionUsage(cwd, sessionId)     │
│                          ↓                                │
│                   projects/*/<id>.jsonl                   │
│                   + subagents/*.jsonl                     │
│                          ↓                                │
│                     SessionUsage                          │
│                                                           │
│  history.jsonl      → readHistory()  → [HistoryEntry]    │
│                                                           │
│  stats-cache.json   → readStatsCache() → TodayStats      │
│                                       + weeklyData        │
└───────────────────────────────────────────────────────────┘
```
