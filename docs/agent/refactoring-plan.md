# 代码结构重构计划

> 生成时间: 2026-04-26
> 目标: 消除 God Object、拆分职责、清理重复、统一命名

---

## 问题总览

| 问题 | 文件 | 行数 | 严重程度 |
|------|------|------|---------|
| God Object | AppState.swift | 708 | 高 |
| God Object | ClaudeDataReader.swift | 1198 | 高 |
| 数据模型重复 | Models/ vs Database/ | - | 中 |
| 配置膨胀 | AppPreferences.swift | 223 | 中 |
| 主题与颜色混杂 | ColorTheme.swift | 165 | 低 |

---

## 重构 1: 拆分 AppState (708 行 → 4 个文件)

### 当前问题
AppState 同时承担 6 种职责：数据属性、轮询调度、数据加载、数据质量校验、周数据计算、FileWatcher/HookServer 管理。

### 目标结构

```
cc-monitor-bar/App/
  AppState.swift          (约 150 行 — 仅保留 Published 属性 + init/deinit + refreshData 入口)
  DataPollingEngine.swift (约 150 行 — 轮询调度 + 指数退避)
  DataLoader.swift        (约 200 行 — loadSessions/loadHistory/loadTodayStats/loadWeeklyData)
  DataQuality.swift       (约 150 行 — buildDataQualityStatus/buildDiffBreakdown/diffRatio)
```

### 具体拆分

**AppState** — 仅保留：
- 所有 `@Published` 属性
- `init()` / `deinit`
- 属性（preferences, reader, resolver, fileWatcher, hookServer, timers, cancellables）
- `refreshData()` 公共入口
- 依赖 DataLoader 和 DataPollingEngine

**DataPollingEngine** — 新类：
- `PollingDataType` 枚举
- `PollingState` 结构体
- `pollingTimers` + `pollingStates`
- `startPolling()` / `stopPolling()` / `tickPolling()` / `loadDataType()`
- 指数退避逻辑
- 通过回调通知 AppState 刷新 UI

**DataLoader** — 新类：
- `loadSessions()` / `loadHistory()` / `loadTodayStats()` / `loadWeeklyData()`
- `modelRatios()` / `last7Days()`
- 通过 `@Published` 或直接返回结果通知 AppState

**DataQuality** — 新 struct（纯函数）：
- `buildDataQualityStatus()`
- `buildDiffBreakdown()`
- `diffRatio()`

### 通信方式
- DataPollingEngine 和 DataLoader 通过闭包回调或 Combine 向 AppState 传递数据
- AppState 不直接操作 pollingStates，由 DataPollingEngine 内部管理

---

## 重构 2: 拆分 ClaudeDataReader (1198 行 → 4 个文件)

### 当前问题
ClaudeDataReader 同时处理 JSONL 解析、SQLite 索引、stats cache、会话管理、项目解析、备份读取。

### 目标结构

```
cc-monitor-bar/Services/
  ClaudeDataReader.swift        (约 150 行 — 公共 API 门面 + 协调子组件)
  JsonlParser.swift             (约 300 行 — JSONL 行消费 + 去重 + 增量索引)
  SQLiteIndexManager.swift      (约 150 行 — SQLite 索引持久化 + 清理)
  StatsCacheReader.swift        (约 100 行 — stats-cache.json 读取 + 备份)
  SessionUsageReader.swift      (约 200 行 — readSessionUsage/readTodayUsage/readTodayUsageByProject)
```

### 具体拆分

**ClaudeDataReader** — 门面模式：
- 保留所有公共方法签名不变（外部调用方无需修改）
- 内部委托给 JsonlParser、SQLiteIndexManager、StatsCacheReader
- 仅保留路径计算和协调逻辑

**JsonlParser** — 核心 JSONL 解析：
- `consumeJsonlLine()` / `consumeJsonlChunk()`
- `parseTimestamp()` / `date()` / `int64()` / `isVisibleText()`
- `messageDedupKey()` / `anonymousToolUseFingerprint()`
- `isHumanUserMessage()`

**SQLiteIndexManager** — SQLite 索引管理：
- `loadIndexFromSQLite()` / `persistProcessedFileIndex()`
- `cleanupSQLiteIndex()`
- `persistDedupKeys()`
- 直接管理 usageIndex（内存缓存 ↔ SQLite 持久化）

**StatsCacheReader** — stats-cache 和备份：
- `readStatsCache()` / `readLatestBackup()`
- `int642()` helper

**SessionUsageReader** — 会话用量聚合：
- `readSessionUsage()` / `readTodayUsage()` / `readTodayUsageByProject()`
- `getCachedFileStats()`
- `readActiveSessions()` / `readHistory()`
- `projectDirNameToDisplayName()` / `cwdToProjectDir()`
- `availableProjectRoots()` / `resolveSessionBasePath()`

---

## 重构 3: 消除数据模型重复

### 当前问题
- `Session` (Models/) 和 `SessionRecord` (Database/Repository.swift) — 结构几乎相同
- `DailyStats` (Models/) 和 `DailyStatsRecord` (Database/Repository.swift) — 相同问题

### 修复方案

1. **统一 Session**:
   - 在 Models/Session.swift 中扩展 Session，添加从 Repository 查询所需的初始化器
   - Repository.fetchRecentSessions() 返回 `[Session]` 而非 `[SessionRecord]`
   - 删除 SessionRecord

2. **统一 DailyStats**:
   - 在 Models/DailyStats.swift 中添加 `projectId` 字段（用于项目级聚合）
   - Repository.fetchDailyStats() 返回 `[DailyStats]` 而非 `[DailyStatsRecord]`
   - 删除 DailyStatsRecord

3. **注意**: 如果 SessionRecord 的字段与 Session 有不可调和的差异（如类型不同），保留 SessionRecord 但添加 `toSession()` 转换方法。

---

## 重构 4: 拆分 AppPreferences

### 当前问题
AppPreferences.swift (223 行) 混杂了 5 个枚举 + 偏好设置类。

### 修复方案

```
cc-monitor-bar/Settings/
  AppPreferences.swift      (仅保留 Preferences 类 + load/save)
  SettingsModels.swift      (DefaultView, IconStyle, AppearanceMode, DataRetentionPolicy)
```

- `DensityMode` 保留在 DesignTokens.swift（与间距计算强相关）
- `ColorTheme` 保留在 ColorTheme.swift

---

## 重构 5: 清理 Theme 目录

### 修复方案

1. **ColorTheme.swift** 拆分：
   - `ModelColors` → 移到 Views/Components/ 或保留在 ColorTheme.swift 末尾（因为只用于 UI）
   - `ToolColors` → 同上
   - `Color` extension (amber600/amber500) → 保留在 ColorTheme.swift

2. **ThemeEnvironment.swift** (34 行)：
   - 检查是否有实际使用，如无则删除
   - 如有使用，将 `.themed()` modifier 保留

---

## 实施顺序

1. **先做重构 3（数据模型统一）** — 风险最低，不影响其他代码
2. **再做重构 4（AppPreferences 拆分）** — 纯文件移动，无逻辑变更
3. **再做重构 5（Theme 清理）** — 可选，风险低
4. **然后重构 1（AppState 拆分）** — 核心重构，需要仔细测试
5. **最后重构 2（ClaudeDataReader 拆分）** — 最大文件，逻辑最复杂

每一步完成后：
- build 验证
- commit 格式: `refactor: <重构编号> <简短描述>`
- 全部完成后 push

---

## 注意事项

- **不改变任何功能行为** — 重构只做代码组织，不修改业务逻辑
- **保持 public API 不变** — 外部调用的方法签名不变
- **每次只改一个文件/模块** — 便于 review 和回滚
- **commit 前 build 验证** — 确保每步都可编译
- **不改动 Views 文件** — Views 依赖当前数据模型，暂不调整
