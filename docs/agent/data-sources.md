# 数据来源

> [AI-AGENT-MAINTAINED]

## 概述

应用只读取本地文件，不调用任何远程 API。默认数据根目录为 `~/.claude/`，并额外扫描 Xcode Claude 集成目录。

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

**路径（多根目录）**:
- `~/.claude/projects/<encoded-cwd>/<sessionId>.jsonl`
- `~/Library/Developer/Xcode/CodingAssistant/ClaudeAgentConfig/projects/<encoded-cwd>/<sessionId>.jsonl`

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

| 字段 | 作用 |
|------|------|
| `message.id` + `requestId` | 同一 assistant 响应在流式阶段会重复写入，需用于去重 |
| `message.usage.*` | Token 统计来源，流式片段中不同字段会逐步更新 |
| `content[].type == "tool_use"` | 工具调用统计来源（优先按 `tool_use.id` 去重） |

**计算规则**: assistant 消息按 `message.id(+requestId)` 去重，同一消息的 `input/output/cache` 按字段取最大值后再汇总。

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
1. 逐行读取 JSONL（可选按时间窗口过滤）
2. `type == "user"` 且 `message.content` 为可见用户输入（字符串，或 `[{type:text}] / image / file` 等块）→ `messageCount++`（过滤 `tool_result`/thinking 包装事件）
3. `type == "assistant"` 且存在 `message.usage`：
   - 以 `message.id(+requestId)` 为键做去重
   - 同键消息按字段取最大值：`input/output/cache_read/cache_creation`
   - 按 `message.model` 聚合（含 per-model breakdown）
   - `content[].type == tool_use`：优先按 `tool_use.id` 去重；无 id 时按 `name+input+message` 指纹去重
4. 会话文件定位优先走 `cwd → encoded-cwd` 路径；若未命中，按 `sessionId` 跨项目目录兜底查找，避免路径编码差异导致漏读

### 增量索引机制（性能与一致性）

为避免每次轮询都全量重读 JSONL，解析器维护内存索引：

- 索引键：`file path + dateRange + mtime/size/offset`
- 增量策略：文件仅追加时只解析新增字节（从上次 offset 继续）
- 回退策略：若检测到非追加改写（前缀探针不一致、文件变短），自动全量重建该文件索引
- 上限控制：索引条目数超过阈值时按最近访问时间淘汰

这套机制不会改变统计口径，只优化读取开销，并降低高频轮询时的 CPU 与 I/O 压力。

### 数据质量校验（JSONL vs stats-cache）

每次刷新会对“今日实时 JSONL 聚合”与 `stats-cache` 做对账：

- 校验项：`totalTokens`、`messageCount`、`sessionCount`、`toolCallCount`
- 输出级别：`healthy / warning / critical / unavailable`
- 触发条件（当前实现）：
  - 最大相对差异 > 35% → `critical`
  - 最大相对差异 > 15% 或 cache 日期滞后 → `warning`
  - 差异低且 cache 新鲜 → `healthy`

UI 会展示校验结果，便于快速判断“统计偏差是缓存延迟，还是解析链路异常”。

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
│  (~/.claude/projects + Xcode projects)/*.jsonl            │
│        → readTodayUsage()  → TodayStats                   │
│  stats-cache.json   → readStatsCache() → 今日计数补充 + 7日趋势 │
└───────────────────────────────────────────────────────────┘
```
