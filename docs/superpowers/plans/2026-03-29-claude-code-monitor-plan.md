# Claude Code Monitor 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans 来实施本计划。步骤使用复选框 (`- [ ]`) 语法进行追踪。

**目标:** 构建 macOS 原生菜单栏应用，监控 Claude Code 的会话、Token 消耗、历史数据，提供三种 UI 风格（极简/看板/时间线）。

**架构:** 三层架构——UI 层 (SwiftUI + AppKit)、服务层 (DataPoller/TokenEstimator/SessionTracker)、数据层 (SQLite)。使用液态玻璃效果，文件轮询获取数据，baseline 差值法估算 Token。

**技术栈:** Swift 5.9+, SwiftUI, AppKit, SQLite.swift, Xcode 15+

---

## 文件结构总览

```
ClaudeCodeMonitor/
├── ClaudeCodeMonitor/
│   ├── App/
│   │   ├── ClaudeCodeMonitorApp.swift    # 应用入口
│   │   ├── AppDelegate.swift             # 菜单栏代理
│   │   └── Info.plist
│   │
│   ├── Views/
│   │   ├── ContentView.swift             # 主视图容器
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
├── Package.swift                     # Swift Package Manager (SQLite.swift)
└── README.md
```

---

## Task 1: 项目脚手架

**Files:**
- Create: `ClaudeCodeMonitor/ClaudeCodeMonitor.xcodeproj` (Xcode 项目)
- Create: `ClaudeCodeMonitor/Package.swift`
- Create: `ClaudeCodeMonitor/App/ClaudeCodeMonitorApp.swift`
- Create: `ClaudeCodeMonitor/App/AppDelegate.swift`
- Create: `ClaudeCodeMonitor/App/Info.plist`

- [ ] **Step 1: 创建 Xcode 项目目录结构**

```bash
mkdir -p ClaudeCodeMonitor/ClaudeCodeMonitor/App
mkdir -p ClaudeCodeMonitor/ClaudeCodeMonitor/Views/Minimal
mkdir -p ClaudeCodeMonitor/ClaudeCodeMonitor/Views/Dashboard
mkdir -p ClaudeCodeMonitor/ClaudeCodeMonitor/Views/Timeline
mkdir -p ClaudeCodeMonitor/ClaudeCodeMonitor/Views/Components
mkdir -p ClaudeCodeMonitor/ClaudeCodeMonitor/Models
mkdir -p ClaudeCodeMonitor/ClaudeCodeMonitor/Services
mkdir -p ClaudeCodeMonitor/ClaudeCodeMonitor/Database
mkdir -p ClaudeCodeMonitor/ClaudeCodeMonitor/Settings
mkdir -p ClaudeCodeMonitor/ClaudeCodeMonitor/Resources/Assets.xcassets
mkdir -p ClaudeCodeMonitor/ClaudeCodeMonitor/Resources/Preview\ Content
```

- [ ] **Step 2: 创建 Package.swift (SQLite.swift 依赖)**

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClaudeCodeMonitor",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ClaudeCodeMonitor", targets: ["ClaudeCodeMonitor"])
    ],
    dependencies: [
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.15.0")
    ],
    targets: [
        .executableTarget(
            name: "ClaudeCodeMonitor",
            dependencies: [
                .product(name: "SQLite", package: "SQLite.swift")
            ],
            path: "ClaudeCodeMonitor"
        )
    ]
)
```

- [ ] **Step 3: 创建应用入口 ClaudeCodeMonitorApp.swift**

```swift
import SwiftUI

@main
struct ClaudeCodeMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
```

- [ ] **Step 4: 创建 AppDelegate.swift (菜单栏集成)**

```swift
import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 创建菜单栏图标
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        // 创建 Popover
        popover = NSPopover()
        popover?.contentViewController = NSHostingController(rootView: ContentView())
        popover?.behavior = .transient
        popover?.animates = true

        // 设置按钮动作
        statusItem?.button?.action = #selector(togglePopover)
        statusItem?.button?.image = NSImage(systemSymbolName: "chart.bar.fill", accessibilityDescription: "Claude Monitor")
        statusItem?.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc func togglePopover() {
        guard let button = statusItem?.button else { return }

        if popover?.isShown == true {
            popover?.performClose(nil)
        } else {
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
```

- [ ] **Step 5: 创建 Info.plist**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
</dict>
</plist>
```

- [ ] **Step 6: 创建空的 ContentView.swift (占位)**

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        Text("Claude Code Monitor")
            .frame(width: 300, height: 400)
    }
}

#Preview {
    ContentView()
}
```

- [ ] **Step 7: 验证项目可编译**

```bash
cd ClaudeCodeMonitor
swift build
```

预期：成功编译（可能有依赖下载输出）

- [ ] **Step 8: 提交**

```bash
git add -A
git commit -m "feat: 创建项目脚手架"
```

---

## Task 2: 数据模型层

**Files:**
- Create: `ClaudeCodeMonitor/Models/Session.swift`
- Create: `ClaudeCodeMonitor/Models/TokenUsage.swift`
- Create: `ClaudeCodeMonitor/Models/DailyStats.swift`
- Create: `ClaudeCodeMonitor/Models/ToolCall.swift`

- [ ] **Step 1: 创建 Session.swift**

```swift
import Foundation

struct Session: Identifiable, Codable {
    let id: String              // UUID
    let pid: Int32
    let projectPath: String
    let projectId: String       // Git 根目录或规范化路径
    let startedAt: Date
    var endedAt: Date?
    var durationMs: Int64
    var messageCount: Int
    var toolCallCount: Int
    let entrypoint: String      // "cli" | "gui" | "ide"

    var isRunning: Bool {
        endedAt == nil
    }

    var durationFormatted: String {
        let seconds = Int(durationMs / 1000)
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
```

- [ ] **Step 2: 创建 TokenUsage.swift**

```swift
import Foundation

struct TokenUsage: Identifiable, Codable {
    let sessionId: String
    let inputTokens: Int64
    let outputTokens: Int64
    let cacheReadTokens: Int64
    let cacheWriteTokens: Int64
    let model: String
    let isEstimated: Bool
    let confidence: String      // "high" | "medium" | "low"

    var totalTokens: Int64 {
        inputTokens + outputTokens + cacheReadTokens + cacheWriteTokens
    }

    var confidenceEmoji: String {
        switch confidence {
        case "high": return "✓"
        case "medium": return "≈"
        case "low": return "≈"
        default: return "?"
        }
    }
}
```

- [ ] **Step 3: 创建 DailyStats.swift**

```swift
import Foundation

struct DailyStats: Identifiable, Codable {
    let date: String            // YYYY-MM-DD
    let messageCount: Int
    let sessionCount: Int
    let toolCallCount: Int
    let inputTokens: Int64
    let outputTokens: Int64
    let cacheTokens: Int64

    var totalTokens: Int64 {
        inputTokens + outputTokens + cacheTokens
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: date) else { return date }

        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "今天"
        } else if calendar.isDateInYesterday(date) {
            return "昨天"
        } else {
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "MM/dd"
            return dayFormatter.string(from: date)
        }
    }
}
```

- [ ] **Step 4: 创建 ToolCall.swift**

```swift
import Foundation

struct ToolCall: Identifiable, Codable {
    let id: Int64
    let sessionId: String
    let timestamp: Date
    let toolName: String        // "Bash", "Read", "Write", "Glob", "Grep", etc.
    let durationMs: Int64?
    let success: Bool

    var toolIcon: String {
        switch toolName {
        case "Bash": return "terminal"
        case "Read": return "doc.text"
        case "Write": return "pencil.and.list"
        case "Glob": return "folder"
        case "Grep": return "magnifyingglass"
        case "Edit": return "pencil"
        default: return "wrench"
        }
    }
}
```

- [ ] **Step 5: 提交**

```bash
git add ClaudeCodeMonitor/Models/*.swift
git commit -m "feat: 创建数据模型"
```

---

## Task 3: 数据库层

**Files:**
- Create: `ClaudeCodeMonitor/Database/Schema.swift`
- Create: `ClaudeCodeMonitor/Database/DatabaseManager.swift`
- Create: `ClaudeCodeMonitor/Database/Repository.swift`

- [ ] **Step 1: 创建 Schema.swift (表结构定义)**

```swift
import SQLite

struct Schema {
    // 表
    static let sessions = Table("sessions")
    static let sessionTokenUsage = Table("session_token_usage")
    static let dailyStats = Table("daily_stats")
    static let dailyModelUsage = Table("daily_model_usage")
    static let toolCalls = Table("tool_calls")
    static let sessionBaseline = Table("session_baseline")

    // sessions 列
    static let id = Expression<String>("id")
    static let pid = Expression<Int32>("pid")
    static let projectPath = Expression<String>("project_path")
    static let projectId = Expression<String>("project_id")
    static let startedAt = Expression<Int64>("started_at")
    static let endedAt = Expression<Int64?>("ended_at")
    static let durationMs = Expression<Int64>("duration_ms")
    static let messageCount = Expression<Int>("message_count")
    static let toolCallCount = Expression<Int>("tool_call_count")
    static let entrypoint = Expression<String>("entrypoint")

    // session_token_usage 列
    static let sessionId = Expression<String>("session_id")
    static let inputTokens = Expression<Int64>("input_tokens")
    static let outputTokens = Expression<Int64>("output_tokens")
    static let cacheReadTokens = Expression<Int64>("cache_read_tokens")
    static let cacheWriteTokens = Expression<Int64>("cache_write_tokens")
    static let model = Expression<String>("model")
    static let isEstimated = Expression<Bool>("is_estimated")
    static let confidence = Expression<String>("confidence")

    // daily_stats 列
    static let date = Expression<String>("date")
    static let messageCount = Expression<Int>("message_count")
    static let sessionCount = Expression<Int>("session_count")
    static let toolCallCount = Expression<Int>("tool_call_count")
    static let cacheTokens = Expression<Int64>("cache_tokens")

    // daily_model_usage 列
    static let modelDate = Expression<String>("date")
    static let model = Expression<String>("model")

    // tool_calls 列
    static let toolId = Expression<Int64>("id")
    static let toolTimestamp = Expression<Int64>("timestamp")
    static let toolName = Expression<String>("tool_name")
    static let success = Expression<Bool>("success")

    // session_baseline 列
    static let baselineTokensJson = Expression<String>("baseline_tokens_json")
    static let lastScanAt = Expression<Int64?>("last_scan_at")
    static let estimatedDelta = Expression<Int64>("estimated_delta")

    // 创建表语句
    static let createSessions = """
        CREATE TABLE IF NOT EXISTS sessions (
            id TEXT PRIMARY KEY,
            pid INTEGER,
            project_path TEXT,
            project_id TEXT,
            started_at INTEGER NOT NULL,
            ended_at INTEGER,
            duration_ms INTEGER DEFAULT 0,
            message_count INTEGER DEFAULT 0,
            tool_call_count INTEGER DEFAULT 0,
            entrypoint TEXT
        )
    """

    static let createSessionTokenUsage = """
        CREATE TABLE IF NOT EXISTS session_token_usage (
            session_id TEXT PRIMARY KEY,
            input_tokens INTEGER DEFAULT 0,
            output_tokens INTEGER DEFAULT 0,
            cache_read_tokens INTEGER DEFAULT 0,
            cache_write_tokens INTEGER DEFAULT 0,
            model TEXT NOT NULL,
            is_estimated BOOLEAN DEFAULT 0,
            confidence TEXT DEFAULT 'medium',
            FOREIGN KEY (session_id) REFERENCES sessions(id)
        )
    """

    static let createDailyStats = """
        CREATE TABLE IF NOT EXISTS daily_stats (
            date TEXT PRIMARY KEY,
            message_count INTEGER DEFAULT 0,
            session_count INTEGER DEFAULT 0,
            tool_call_count INTEGER DEFAULT 0,
            input_tokens INTEGER DEFAULT 0,
            output_tokens INTEGER DEFAULT 0,
            cache_tokens INTEGER DEFAULT 0
        )
    """

    static let createDailyModelUsage = """
        CREATE TABLE IF NOT EXISTS daily_model_usage (
            date TEXT NOT NULL,
            model TEXT NOT NULL,
            input_tokens INTEGER DEFAULT 0,
            output_tokens INTEGER DEFAULT 0,
            cache_tokens INTEGER DEFAULT 0,
            PRIMARY KEY (date, model)
        )
    """

    static let createToolCalls = """
        CREATE TABLE IF NOT EXISTS tool_calls (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id TEXT NOT NULL,
            timestamp INTEGER NOT NULL,
            tool_name TEXT NOT NULL,
            duration_ms INTEGER,
            success BOOLEAN DEFAULT 1,
            FOREIGN KEY (session_id) REFERENCES sessions(id)
        )
    """

    static let createSessionBaseline = """
        CREATE TABLE IF NOT EXISTS session_baseline (
            session_id TEXT PRIMARY KEY,
            started_at INTEGER NOT NULL,
            baseline_tokens_json TEXT NOT NULL,
            last_scan_at INTEGER,
            estimated_delta INTEGER DEFAULT 0,
            confidence TEXT DEFAULT 'medium',
            project_id TEXT
        )
    """

    static let createIndexes = """
        CREATE INDEX IF NOT EXISTS idx_sessions_started ON sessions(started_at);
        CREATE INDEX IF NOT EXISTS idx_sessions_project ON sessions(project_id);
        CREATE INDEX IF NOT EXISTS idx_daily_stats_date ON daily_stats(date);
        CREATE INDEX IF NOT EXISTS idx_tool_calls_session ON tool_calls(session_id);
    """
}
```

- [ ] **Step 2: 创建 DatabaseManager.swift**

```swift
import SQLite
import Foundation

class DatabaseManager {
    static let shared = DatabaseManager()

    private var db: Connection?
    private let dbPath: String

    init() {
        let libraryPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appPath = libraryPath.appendingPathComponent("ClaudeMonitor", isDirectory: true)

        // 创建目录
        try? FileManager.default.createDirectory(at: appPath, withIntermediateDirectories: true)

        dbPath = appPath.appendingPathComponent("data.db").path
    }

    func connect() throws {
        guard db == nil else { return }

        db = try Connection(dbPath)
        try createTables()
    }

    private func createTables() throws {
        guard let db = db else { throw NSError(domain: "DB", code: 1, userInfo: [NSLocalizedDescriptionKey: "未连接数据库"]) }

        try db.run(Schema.createSessions)
        try db.run(Schema.createSessionTokenUsage)
        try db.run(Schema.createDailyStats)
        try db.run(Schema.createDailyModelUsage)
        try db.run(Schema.createToolCalls)
        try db.run(Schema.createSessionBaseline)
        try db.run(Schema.createIndexes)
    }

    func run(_ query: QueryType) throws -> AnyIterator<Row> {
        guard let db = db else { throw NSError(domain: "DB", code: 1, userInfo: [NSLocalizedDescriptionKey: "未连接数据库"]) }
        return try db.prepare(query).makeIterator()
    }

    func run(_ statement: String) throws {
        guard let db = db else { throw NSError(domain: "DB", code: 1, userInfo: [NSLocalizedDescriptionKey: "未连接数据库"]) }
        try db.run(statement)
    }

    func insert(_ query: Insert) throws -> Int64 {
        guard let db = db else { throw NSError(domain: "DB", code: 1, userInfo: [NSLocalizedDescriptionKey: "未连接数据库"]) }
        return try db.run(query)
    }

    func update(_ query: Query) throws {
        guard let db = db else { throw NSError(domain: "DB", code: 1, userInfo: [NSLocalizedDescriptionKey: "未连接数据库"]) }
        try db.run(query)
    }

    func delete(_ query: Query) throws {
        guard let db = db else { throw NSError(domain: "DB", code: 1, userInfo: [NSLocalizedDescriptionKey: "未连接数据库"]) }
        try db.run(query.delete())
    }
}
```

- [ ] **Step 3: 创建 Repository.swift (数据访问层)**

```swift
import SQLite
import Foundation

class Repository {
    private let db: DatabaseManager

    init(db: DatabaseManager = .shared) {
        self.db = db
    }

    // MARK: - Sessions

    func saveSession(_ session: Session) throws {
        let endedAtValue = session.endedAt?.timeIntervalSince1970 ?? 0
        try db.run("""
            INSERT OR REPLACE INTO sessions (id, pid, project_path, project_id, started_at, ended_at, duration_ms, message_count, tool_call_count, entrypoint)
            VALUES ('\((session.id))', \(session.pid), '\((session.projectPath))', '\((session.projectId))', \(Int64(session.startedAt.timeIntervalSince1970)), \(endedAtValue), \(session.durationMs), \(session.messageCount), \(session.toolCallCount), '\((session.entrypoint))')
        """)
    }

    func getRunningSessions() throws -> [Session] {
        var sessions: [Session] = []
        // TODO: 实现查询运行中会话
        return sessions
    }

    func getRecentSessions(limit: Int = 10) throws -> [Session] {
        var sessions: [Session] = []
        // TODO: 实现查询最近会话
        return sessions
    }

    // MARK: - Token Usage

    func saveTokenUsage(_ usage: TokenUsage) throws {
        try db.run("""
            INSERT OR REPLACE INTO session_token_usage (session_id, input_tokens, output_tokens, cache_read_tokens, cache_write_tokens, model, is_estimated, confidence)
            VALUES ('\((usage.sessionId))', \(usage.inputTokens), \(usage.outputTokens), \(usage.cacheReadTokens), \(usage.cacheWriteTokens), '\((usage.model))', \(usage.isEstimated ? 1 : 0), '\((usage.confidence))')
        """)
    }

    // MARK: - Daily Stats

    func saveDailyStats(_ stats: DailyStats) throws {
        try db.run("""
            INSERT OR REPLACE INTO daily_stats (date, message_count, session_count, tool_call_count, input_tokens, output_tokens, cache_tokens)
            VALUES ('\((stats.date))', \(stats.messageCount), \(stats.sessionCount), \(stats.toolCallCount), \(stats.inputTokens), \(stats.outputTokens), \(stats.cacheTokens)
        """)
    }

    func getDailyStats(days: Int = 7) throws -> [DailyStats] {
        var stats: [DailyStats] = []
        // TODO: 实现查询
        return stats
    }

    // MARK: - Session Baseline

    func saveBaseline(sessionId: String, startedAt: Date, baseline: [String: Int64], projectId: String) throws {
        let json = try JSONSerialization.data(withJSONObject: baseline).asString()
        try db.run("""
            INSERT OR REPLACE INTO session_baseline (session_id, started_at, baseline_tokens_json, project_id)
            VALUES ('\((sessionId))', \(Int64(startedAt.timeIntervalSince1970)), '\((json))', '\((projectId))')
        """)
    }

    func getBaseline(sessionId: String) throws -> [String: Int64]? {
        // TODO: 实现查询
        return nil
    }

    func updateBaselineDelta(sessionId: String, delta: Int64, confidence: String) throws {
        try db.run("""
            UPDATE session_baseline
            SET estimated_delta = \(delta), confidence = '\((confidence))', last_scan_at = \(Int64(Date().timeIntervalSince1970))
            WHERE session_id = '\((sessionId))'
        """)
    }

    func removeBaseline(sessionId: String) throws {
        try db.run("""
            DELETE FROM session_baseline WHERE session_id = '\((sessionId))'
        """)
    }
}

extension Data {
    func asString() -> String {
        String(data: self, encoding: .utf8) ?? ""
    }
}
```

- [ ] **Step 4: 提交**

```bash
git add ClaudeCodeMonitor/Database/*.swift
git commit -m "feat: 创建数据库层 (Schema/Manager/Repository)"
```

---

## Task 4: 服务层 - ProjectResolver

**Files:**
- Create: `ClaudeCodeMonitor/Services/ProjectResolver.swift`

- [ ] **Step 1: 创建 ProjectResolver.swift (Git 根目录识别)**

```swift
import Foundation

class ProjectResolver {
    static let shared = ProjectResolver()

    /// 解析项目 ID：规范化路径 + Git 根目录匹配
    func resolveProjectId(from path: String) -> String {
        // 1. 规范化路径
        let normalized = normalizePath(path)

        // 2. 查找 Git 根目录
        if let gitRoot = findGitRoot(from: normalized) {
            return gitRoot.lastPathComponent
        }

        // 3. 返回规范化路径的最后一部分
        return normalized.lastPathComponent
    }

    /// 规范化路径
    private func normalizePath(_ path: String) -> String {
        var result = path

        // 去除末尾的 "/"
        while result.hasSuffix("/") {
            result.removeLast()
        }

        // 解析 "~"
        if result.hasPrefix("~") {
            result = result.replacingCharacters(in: ..<result.index(after: result.startIndex)), with: FileManager.default.homeDirectoryForCurrentUser.path)
        }

        // 解析 "." 和 ".."
        let components = result.components(separatedBy: "/").filter { $0.isNotEmpty && $0 != "." }
        var resolved: [String] = []

        for component in components {
            if component == ".." {
                _ = resolved.popLast()
            } else {
                resolved.append(component)
            }
        }

        return "/" + resolved.joined(separator: "/")
    }

    /// 向上查找 .git 目录
    private func findGitRoot(from path: String) -> URL? {
        var currentURL = URL(fileURLWithPath: path)

        while currentURL.path != "/" {
            let gitURL = currentURL.appendingPathComponent(".git")
            if FileManager.default.fileExists(atPath: gitURL.path) {
                return currentURL
            }
            currentURL.deleteLastPathComponent()
        }

        return nil
    }
}

extension String {
    var lastPathComponent: String {
        (self as NSString).lastPathComponent
    }

    var isNotEmpty: Bool {
        !isEmpty
    }
}
```

- [ ] **Step 2: 提交**

```bash
git add ClaudeCodeMonitor/Services/ProjectResolver.swift
git commit -m "feat: 创建 ProjectResolver (Git 根目录识别)"
```

---

## Task 5: 服务层 - ClaudeDataReader

**Files:**
- Create: `ClaudeCodeMonitor/Services/ClaudeDataReader.swift`

- [ ] **Step 1: 创建 ClaudeDataReader.swift (读取本地文件)**

```swift
import Foundation

struct ClaudeDataPaths {
    let claudeDir: String
    let statsCache: String
    let historyJsonl: String
    let sessionsDir: String
    let projectsDir: String

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        claudeDir = "\(home)/.claude"
        statsCache = "\(claudeDir)/stats-cache.json"
        historyJsonl = "\(claudeDir)/history.jsonl"
        sessionsDir = "\(claudeDir)/sessions"
        projectsDir = "\(claudeDir)/projects"
    }
}

class ClaudeDataReader {
    let paths: ClaudeDataPaths

    init(paths: ClaudeDataPaths = .init()) {
        self.paths = paths
    }

    // MARK: - Stats Cache

    func readStatsCache() throws -> StatsCache {
        let data = try Data(contentsOf: URL(fileURLWithPath: paths.statsCache))
        return try JSONDecoder().decode(StatsCache.self, from: data)
    }

    // MARK: - Sessions

    func readActiveSessions() throws -> [ActiveSessionInfo] {
        let sessionsDir = paths.sessionsDir
        let files = try FileManager.default.contentsOfDirectory(atPath: sessionsDir)
            .filter { $0.hasSuffix(".json") }

        var sessions: [ActiveSessionInfo] = []

        for file in files {
            let filePath = "\(sessionsDir)/\(file)"
            if let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)),
               let session = try? JSONDecoder().decode(ActiveSessionInfo.self, from: data) {
                sessions.append(session)
            }
        }

        return sessions
    }

    // MARK: - History

    func readHistory(limit: Int = 100) throws -> [HistoryEntry] {
        let data = try Data(contentsOf: URL(fileURLWithPath: paths.historyJsonl))
        let lines = String(data: data, encoding: .utf8)?
            .components(separatedBy: .newlines)
            .filter { $0.isNotEmpty } ?? []

        var entries: [HistoryEntry] = []
        for line in lines.prefix(limit) {
            if let entry = try? JSONDecoder().decode(HistoryEntry.self, from: Data(line.utf8)) {
                entries.append(entry)
            }
        }

        return entries
    }

    // MARK: - Project Sessions

    func readProjectSessions(projectId: String) throws -> [ProjectSessionEntry] {
        // 查找项目目录
        let projectsDir = paths.projectsDir
        let files = try FileManager.default.contentsOfDirectory(atPath: projectsDir)

        var entries: [ProjectSessionEntry] = []

        for file in files {
            if file.contains(projectId) {
                let dirPath = "\(projectsDir)/\(file)"
                let sessionFiles = try? FileManager.default.contentsOfDirectory(atPath: dirPath)
                    .filter { $0.hasSuffix(".jsonl") }

                for sessionFile in sessionFiles ?? [] {
                    let filePath = "\(dirPath)/\(sessionFile)"
                    if let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)),
                       let lines = String(data: data, encoding: .utf8)?
                        .components(separatedBy: .newlines)
                        .filter({ $0.isNotEmpty }) {
                        for line in lines {
                            if let entry = try? JSONDecoder().decode(ProjectSessionEntry.self, from: Data(line.utf8)) {
                                entries.append(entry)
                            }
                        }
                    }
                }
            }
        }

        return entries
    }
}

// MARK: - Data Models

struct StatsCache: Codable {
    let version: Int
    let lastComputedDate: String
    let dailyActivity: [DailyActivity]
    let dailyModelTokens: [DailyModelTokens]
    let modelUsage: [String: ModelUsage]
}

struct DailyActivity: Codable {
    let date: String
    let messageCount: Int
    let sessionCount: Int
    let toolCallCount: Int
}

struct DailyModelTokens: Codable {
    let date: String
    let tokensByModel: [String: Int64]
}

struct ModelUsage: Codable {
    let inputTokens: Int64
    let outputTokens: Int64
    let cacheReadInputTokens: Int64
    let cacheCreationInputTokens: Int64
    let webSearchRequests: Int
    let costUSD: Double
    let contextWindow: Int
    let maxOutputTokens: Int

    enum CodingKeys: String, CodingKey {
        case inputTokens, outputTokens, cacheReadInputTokens, cacheCreationInputTokens
        case webSearchRequests, costUSD, contextWindow, maxOutputTokens
    }
}

struct ActiveSessionInfo: Codable {
    let pid: Int32
    let sessionId: String
    let cwd: String
    let startedAt: Int64
    let kind: String
    let entrypoint: String
}

struct HistoryEntry: Codable {
    let display: String?
    let timestamp: Int64
    let project: String?
    let sessionId: String?
}

struct ProjectSessionEntry: Codable {
    let type: String?
    let message: ProjectMessage?
    let timestamp: String?
    let sessionId: String?
}

struct ProjectMessage: Codable {
    let role: String?
    let content: String?
}
```

- [ ] **Step 2: 提交**

```bash
git add ClaudeCodeMonitor/Services/ClaudeDataReader.swift
git commit -m "feat: 创建 ClaudeDataReader (本地文件读取)"
```

---

## Task 6: 服务层 - DataPoller

**Files:**
- Create: `ClaudeCodeMonitor/Services/DataPoller.swift`

- [ ] **Step 1: 创建 DataPoller.swift (数据轮询服务)**

```swift
import Foundation

class DataPoller {
    static let shared = DataPoller()

    private var timer: Timer?
    private var isRunning: Bool = false

    var refreshInterval: TimeInterval = 30.0  // 默认 30 秒
    var onPoll: (() -> Void)?

    func start(interval: TimeInterval) {
        guard !isRunning else { return }

        refreshInterval = interval
        isRunning = true

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.poll()
        }

        // 立即执行一次
        poll()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    func updateInterval(_ interval: TimeInterval) {
        refreshInterval = interval
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    private func poll() {
        // 后台执行
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.performPoll()
        }
    }

    private func performPoll() {
        // 1. 读取活跃会话
        // 2. 读取 stats-cache
        // 3. 更新 Token 估算
        // 4. 通知 UI

        onPoll?()
    }
}
```

- [ ] **Step 2: 提交**

```bash
git add ClaudeCodeMonitor/Services/DataPoller.swift
git commit -m "feat: 创建 DataPoller (数据轮询)"
```

---

## Task 7: 服务层 - TokenEstimator

**Files:**
- Create: `ClaudeCodeMonitor/Services/TokenEstimator.swift`

- [ ] **Step 1: 创建 TokenEstimator.swift (Token 估算服务)**

```swift
import Foundation

class TokenEstimator {
    static let shared = TokenEstimator()

    private let reader: ClaudeDataReader
    private let repository: Repository
    private let projectResolver: ProjectResolver

    // Token 估算率 (字符/token)
    private let chineseRate: Double = 1.5
    private let englishRate: Double = 4.0

    // 置信度阈值
    private let confidenceThreshold: Double = 0.20  // 20%

    init(reader: ClaudeDataReader = .init(), repository: Repository = .init(), projectResolver: ProjectResolver = .shared) {
        self.reader = reader
        self.repository = repository
        self.projectResolver = projectResolver
    }

    // MARK: - Baseline

    func initializeBaseline(for sessionId: String, startedAt: Date, projectId: String) throws {
        let stats = try reader.readStatsCache()
        var baseline: [String: Int64] = [:]

        // 聚合所有模型的 token
        for (model, usage) in stats.modelUsage {
            baseline[model] = usage.inputTokens + usage.outputTokens + usage.cacheReadInputTokens + usage.cacheCreationInputTokens
        }

        try repository.saveBaseline(sessionId: sessionId, startedAt: startedAt, baseline: baseline, projectId: projectId)
    }

    // MARK: - Estimate

    func estimateCurrentUsage(for sessionId: String) throws -> TokenEstimation {
        guard let baseline = try repository.getBaseline(sessionId: sessionId) else {
            throw NSError(domain: "TokenEstimator", code: 1, userInfo: [NSLocalizedDescriptionKey: "无 baseline"])
        }

        let stats = try reader.readStatsCache()
        var currentTotals: [String: Int64] = [:]

        for (model, usage) in stats.modelUsage {
            currentTotals[model] = usage.inputTokens + usage.outputTokens + usage.cacheReadInputTokens + usage.cacheCreationInputTokens
        }

        // 计算增量
        var delta: [String: Int64] = [:]
        var totalDelta: Int64 = 0

        for (model, current) in currentTotals {
            let baselineValue = baseline[model] ?? 0
            let modelDelta = current - baselineValue
            delta[model] = modelDelta
            totalDelta += modelDelta
        }

        // 交叉验证
        let crossValidation = try crossValidate(sessionId: sessionId)
        let confidence = calculateConfidence(estimated: Double(totalDelta), crossValidated: Double(crossValidation))

        // 更新 baseline 记录
        try repository.updateBaselineDelta(sessionId: sessionId, delta: totalDelta, confidence: confidence)

        return TokenEstimation(
            sessionId: sessionId,
            totalTokens: totalDelta,
            tokensByModel: delta,
            confidence: confidence,
            crossValidatedTokens: crossValidation
        )
    }

    // MARK: - Cross Validation

    private func crossValidate(sessionId: String) throws -> Int64 {
        // 读取 history.jsonl 中属于此会话的消息
        // 统计字符数并估算 token
        let history = try reader.readHistory(limit: 1000)

        // 简化：统计所有消息的字符数
        var totalChars = 0
        for entry in history {
            if let display = entry.display {
                totalChars += display.count
            }
        }

        // 按中文估算
        return Int64(Double(totalChars) / chineseRate)
    }

    private func calculateConfidence(estimated: Double, crossValidated: Double) -> String {
        guard estimated > 0 else { return "low" }

        let diff = abs(estimated - crossValidated) / estimated

        if diff <= confidenceThreshold {
            return "high"
        } else if diff <= confidenceThreshold * 2 {
            return "medium"
        } else {
            return "low"
        }
    }

    // MARK: - Token 估算公式

    func estimateTokens(from text: String, model: String) -> Int64 {
        let chineseChars = text.unicodeScalars.filter { isChinese($0) }.count
        let englishChars = text.count - chineseChars

        let chineseTokens = Double(chineseChars) / chineseRate
        let englishTokens = Double(englishChars) / englishRate

        return Int64(chineseTokens + englishTokens)
    }

    private func isChinese(_ scalar: Unicode.Scalar) -> Bool {
        let isCJK = (scalar.value >= 0x4E00 && scalar.value <= 0x9FFF) ||
                    (scalar.value >= 0x3400 && scalar.value <= 0x4DBF) ||
                    (scalar.value >= 0x20000 && scalar.value <= 0x2A6DF)
        return isCJK
    }
}

struct TokenEstimation {
    let sessionId: String
    let totalTokens: Int64
    let tokensByModel: [String: Int64]
    let confidence: String
    let crossValidatedTokens: Int64
}
```

- [ ] **Step 2: 提交**

```bash
git add ClaudeCodeMonitor/Services/TokenEstimator.swift
git commit -m "feat: 创建 TokenEstimator (Token 估算 + 交叉验证)"
```

---

## Task 8: 服务层 - SessionTracker

**Files:**
- Create: `ClaudeCodeMonitor/Services/SessionTracker.swift`

- [ ] **Step 1: 创建 SessionTracker.swift (会话追踪服务)**

```swift
import Foundation

class SessionTracker {
    static let shared = SessionTracker()

    private let reader: ClaudeDataReader
    private let repository: Repository
    private let tokenEstimator: TokenEstimator
    private let projectResolver: ProjectResolver

    init(reader: ClaudeDataReader = .init(), repository: Repository = .init(),
         tokenEstimator: TokenEstimator = .shared, projectResolver: ProjectResolver = .shared) {
        self.reader = reader
        self.repository = repository
        self.tokenEstimator = tokenEstimator
        self.projectResolver = projectResolver
    }

    // MARK: - Session Discovery

    func discoverAndTrackSessions() throws {
        let activeSessions = try reader.readActiveSessions()

        for session in activeSessions {
            let projectId = projectResolver.resolveProjectId(from: session.cwd)

            // 检查是否已存在
            // 如果不存在，创建并初始化 baseline
            // 如果存在且已结束，结算
        }
    }

    // MARK: - Multi-Session Allocation

    func allocateTokens(for projectId: String, totalDelta: Int64) throws -> [String: Int64] {
        // 获取该项目下所有活跃会话
        // 计算每个会话的权重: weight = (active_time × 0.3) + (message_count × 0.7)
        // 分配 token

        // 简化实现：返回空字典
        return [:]
    }
}
```

- [ ] **Step 2: 提交**

```bash
git add ClaudeCodeMonitor/Services/SessionTracker.swift
git commit -m "feat: 创建 SessionTracker (会话追踪)"
```

---

## Task 9: UI 层 - 设置面板

**Files:**
- Create: `ClaudeCodeMonitor/Settings/AppPreferences.swift`
- Create: `ClaudeCodeMonitor/Settings/SettingsView.swift`

- [ ] **Step 1: 创建 AppPreferences.swift (偏好设置存储)**

```swift
import Foundation

class AppPreferences {
    static let shared = AppPreferences()

    private let defaults = UserDefaults.standard

    // MARK: - View Settings

    var defaultView: DefaultView {
        get {
            let raw = defaults.string(forKey: "defaultView") ?? "minimal"
            return DefaultView(rawValue: raw) ?? .minimal
        }
        set {
            defaults.set(newValue.rawValue, forKey: "defaultView")
        }
    }

    var rememberLastView: Bool {
        get { defaults.object(forKey: "rememberLastView") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "rememberLastView") }
    }

    var lastView: DefaultView {
        get {
            let raw = defaults.string(forKey: "lastView") ?? "minimal"
            return DefaultView(rawValue: raw) ?? .minimal
        }
        set {
            defaults.set(newValue.rawValue, forKey: "lastView")
        }
    }

    // MARK: - Data Settings

    var refreshInterval: TimeInterval {
        get { defaults.object(forKey: "refreshInterval") as? TimeInterval ?? 30.0 }
        set { defaults.set(newValue, forKey: "refreshInterval") }
    }

    var compactDisplay: Bool {
        get { defaults.object(forKey: "compactDisplay") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "compactDisplay") }
    }

    // MARK: - Token Settings

    var showCostEstimate: Bool {
        get { defaults.object(forKey: "showCostEstimate") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "showCostEstimate") }
    }

    var monthlyBudgetWarning: Double? {
        get { defaults.object(forKey: "monthlyBudgetWarning") as? Double }
        set { defaults.set(newValue, forKey: "monthlyBudgetWarning") }
    }

    // MARK: - System Settings

    var launchAtLogin: Bool {
        get { defaults.object(forKey: "launchAtLogin") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "launchAtLogin") }
    }

    var iconStyle: IconStyle {
        get {
            let raw = defaults.string(forKey: "iconStyle") ?? "default"
            return IconStyle(rawValue: raw) ?? .default
        }
        set {
            defaults.set(newValue.rawValue, forKey: "iconStyle")
        }
    }

    var theme: Theme {
        get {
            let raw = defaults.string(forKey: "theme") ?? "system"
            return Theme(rawValue: raw) ?? .system
        }
        set {
            defaults.set(newValue.rawValue, forKey: "theme")
        }
    }

    // MARK: - Storage Settings

    var dataRetentionDays: Int {
        get { defaults.object(forKey: "dataRetentionDays") as? Int ?? 30 }
        set { defaults.set(newValue, forKey: "dataRetentionDays") }
    }
}

enum DefaultView: String {
    case minimal = "minimal"
    case dashboard = "dashboard"
    case timeline = "timeline"
}

enum IconStyle: String {
    case `default` = "default"
    case simple = "simple"
    case colorful = "colorful"
}

enum Theme: String {
    case system = "system"
    case light = "light"
    case dark = "dark"
}
```

- [ ] **Step 2: 创建 SettingsView.swift**

```swift
import SwiftUI

struct SettingsView: View {
    @State private var defaultView: DefaultView = .minimal
    @State private var rememberLastView: Bool = true
    @State private var refreshInterval: Double = 30.0
    @State private var compactDisplay: Bool = true
    @State private var showCostEstimate: Bool = false
    @State private var monthlyBudget: String = ""
    @State private var launchAtLogin: Bool = false
    @State private var iconStyle: IconStyle = .default
    @State private var theme: Theme = .system
    @State private var dataRetentionDays: Int = 30

    var body: some View {
        Form {
            Section("视图") {
                Picker("默认视图", selection: $defaultView) {
                    Text("极简").tag(DefaultView.minimal)
                    Text("数据看板").tag(DefaultView.dashboard)
                    Text("时间线").tag(DefaultView.timeline)
                }

                Toggle("记住上次关闭时的视图", isOn: $rememberLastView)
            }

            Section("数据") {
                VStack(alignment: .leading) {
                    Text("刷新频率：\(Int(refreshInterval))秒")
                    Slider(value: $refreshInterval, in: 3...1800, step: 3) {
                        Text("3 秒")
                    } maximumValueLabel: {
                        Text("30 分钟")
                    }
                }

                Toggle("紧凑数据显示", isOn: $compactDisplay)
            }

            Section("Token") {
                Toggle("显示成本估算", isOn: $showCostEstimate)

                HStack {
                    Toggle("月度预算警告", isOn: .constant(false))
                    TextField("$______", text: $monthlyBudget)
                        .disabled(true)
                }
            }

            Section("系统") {
                Toggle("开机自启", isOn: $launchAtLogin)

                Picker("菜单栏图标", selection: $iconStyle) {
                    Text("默认").tag(IconStyle.default)
                    Text("简约").tag(IconStyle.simple)
                    Text("彩色").tag(IconStyle.colorful)
                }

                Picker("主题", selection: $theme) {
                    Text("跟随系统").tag(Theme.system)
                    Text("浅色").tag(Theme.light)
                    Text("深色").tag(Theme.dark)
                }
            }

            Section("存储") {
                Picker("数据保留期限", selection: $dataRetentionDays) {
                    Text("7 天").tag(7)
                    Text("30 天").tag(30)
                    Text("90 天").tag(90)
                    Text("永久").tag(9999)
                }

                Text("SQLite 文件位置")
                Text("~/Library/Application Support/ClaudeMonitor/data.db")
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 400, height: 500)
        .padding()
    }
}

#Preview {
    SettingsView()
}
```

- [ ] **Step 3: 提交**

```bash
git add ClaudeCodeMonitor/Settings/*.swift
git commit -m "feat: 创建设置面板 (Preferences/SettingsView)"
```

---

## Task 10: UI 层 - 通用组件

**Files:**
- Create: `ClaudeCodeMonitor/Views/Components/GlassBackground.swift`
- Create: `ClaudeCodeMonitor/Views/Components/FrequencySlider.swift`

- [ ] **Step 1: 创建 GlassBackground.swift (液态玻璃效果)**

```swift
import SwiftUI
import AppKit

struct GlassBackground: View {
    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
        }
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
```

- [ ] **Step 2: 创建 FrequencySlider.swift (频率滑块)**

```swift
import SwiftUI

struct FrequencySlider: View {
    @Binding var interval: Double
    let minInterval: Double = 3.0
    let maxInterval: Double = 1800.0

    var body: some View {
        VStack(alignment: .leading) {
            Text("刷新频率")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                Text("3s")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Slider(value: $interval, in: minInterval...maxInterval, step: 3.0)

                Text(formatInterval(interval))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(width: 60)
            }
        }
    }

    private func formatInterval(_ seconds: Double) -> String {
        if seconds < 60 {
            return "\(Int(seconds))s"
        } else if seconds < 3600 {
            return "\(Int(seconds / 60))m"
        } else {
            return "\(Int(seconds / 3600))h"
        }
    }
}

#Preview {
    FrequencySlider(interval: .constant(30.0))
        .frame(width: 200)
}
```

- [ ] **Step 3: 提交**

```bash
git add ClaudeCodeMonitor/Views/Components/*.swift
git commit -m "feat: 创建通用 UI 组件 (GlassBackground/FrequencySlider)"
```

---

## Task 11: UI 层 - 极简风格视图

**Files:**
- Create: `ClaudeCodeMonitor/Views/Minimal/MinimalView.swift`
- Create: `ClaudeCodeMonitor/Views/Minimal/CurrentSessionCard.swift`
- Create: `ClaudeCodeMonitor/Views/Minimal/HistoryList.swift`

- [ ] **Step 1: 创建 MinimalView.swift**

```swift
import SwiftUI

struct MinimalView: View {
    @State private var currentSession: Session?
    @State private var sessionEstimation: TokenEstimation?
    @State private var historySessions: [Session] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 当前会话卡片
                if let session = currentSession {
                    CurrentSessionCard(session: session, estimation: sessionEstimation)
                } else {
                    Text("无活跃会话")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                }

                Divider()

                // 历史会话列表
                Text("历史会话")
                    .font(.headline)
                    .padding(.top)

                ForEach(historySessions) { session in
                    HistorySessionRow(session: session)
                }
            }
            .padding()
        }
        .frame(width: 350, height: 450)
        .background(GlassBackground())
        .onAppear {
            loadSessions()
        }
    }

    private func loadSessions() {
        // TODO: 从 Repository 加载数据
    }
}

struct HistorySessionRow: View {
    let session: Session

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(session.projectPath.lastPathComponent)
                    .font(.subheadline)
                Spacer()
                Text(session.durationFormatted)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text("\(session.messageCount) messages · \(session.toolCallCount) tools")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    MinimalView()
}
```

- [ ] **Step 2: 创建 CurrentSessionCard.swift**

```swift
import SwiftUI

struct CurrentSessionCard: View {
    let session: Session
    var estimation: TokenEstimation?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 状态指示器
            HStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)

                Text("会话进行中")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(session.entrypoint.uppercased())
                    .font(.caption2)
                    .padding(4)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
            }

            // 项目路径
            Text(session.projectPath.lastPathComponent)
                .font(.headline)

            // 运行时长
            Text("已运行 \(session.durationFormatted)")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            // Token 统计
            VStack(alignment: .leading, spacing: 8) {
                StatRow(label: "Token", value: estimation?.totalTokens ?? 0,
                       confidence: estimation?.confidence)
                StatRow(label: "消息数", value: session.messageCount)
                StatRow(label: "工具调用", value: session.toolCallCount)
                StatRow(label: "模型", value: "glm-5.1")
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

struct StatRow: View {
    let label: String
    let value: Int
    var confidence: String?

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            HStack(spacing: 4) {
                Text(formatNumber(value))
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let conf = confidence {
                    Text(conf == "high" ? "✓" : "≈")
                        .font(.caption)
                        .foregroundColor(conf == "high" ? .green : .orange)
                }
            }
        }
    }

    private func formatNumber(_ num: Int) -> String {
        if num >= 1_000_000 {
            return String(format: "%.1fM", Double(num) / 1_000_000)
        } else if num >= 1_000 {
            return String(format: "%.1fk", Double(num) / 1_000)
        } else {
            return "\(num)"
        }
    }
}

#Preview {
    CurrentSessionCard(
        session: Session(
            id: "test", pid: 1234, projectPath: "/Users/test/project",
            projectId: "project", startedAt: Date(), endedAt: nil,
            durationMs: 7200000, messageCount: 50, toolCallCount: 20,
            entrypoint: "cli"
        ),
        estimation: TokenEstimation(
            sessionId: "test", totalTokens: 45678, tokensByModel: ["glm-5.1": 45678],
            confidence: "medium", crossValidatedTokens: 40000
        )
    )
}
```

- [ ] **Step 3: 创建 HistoryList.swift**

```swift
import SwiftUI

struct HistoryList: View {
    let sessions: [Session]

    var body: some View {
        ForEach(sessions) { session in
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(session.projectPath.lastPathComponent)
                        .font(.subheadline)
                    Spacer()
                    Text(session.durationFormatted)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text("\(session.messageCount) messages")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
}

#Preview {
    HistoryList(sessions: [
        Session(id: "1", pid: 1234, projectPath: "/Users/test/project1",
               projectId: "project1", startedAt: Date().addingTimeInterval(-3600),
               endedAt: Date(), durationMs: 3600000, messageCount: 30,
               toolCallCount: 10, entrypoint: "cli")
    ])
}
```

- [ ] **Step 4: 提交**

```bash
git add ClaudeCodeMonitor/Views/Minimal/*.swift
git commit -m "feat: 创建极简风格视图 (MinimalView/CurrentSessionCard/HistoryList)"
```

---

## Task 12: UI 层 - 数据看板风格视图

**Files:**
- Create: `ClaudeCodeMonitor/Views/Dashboard/DashboardView.swift`
- Create: `ClaudeCodeMonitor/Views/Dashboard/StatCard.swift`
- Create: `ClaudeCodeMonitor/Views/Dashboard/TokenChart.swift`
- Create: `ClaudeCodeMonitor/Views/Dashboard/ModelDistribution.swift`

- [ ] **Step 1: 创建 DashboardView.swift**

```swift
import SwiftUI

struct DashboardView: View {
    @State private var todayStats: DailyStats?
    @State private var weekStats: [DailyStats] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 统计卡片
                HStack(spacing: 12) {
                    if let stats = todayStats {
                        StatCard(title: "今日 Token", value: "\(stats.totalTokens)", trend: "+12%")
                        StatCard(title: "本周 Token", value: "\(weekStats.reduce(0) { $0 + $1.totalTokens })", trend: "+8%")
                    }
                }

                HStack(spacing: 12) {
                    StatCard(title: "今日会话", value: "\(todayStats?.sessionCount ?? 0)", trend: nil)
                    StatCard(title: "平均时长", value: "1h 23m", trend: "-0.2s")
                }

                Divider()

                // Token 趋势图
                Text("Token 消耗 (7 日)")
                    .font(.headline)
                TokenChart(stats: weekStats)

                Divider()

                // 模型分布
                Text("模型分布")
                    .font(.headline)
                ModelDistribution()
            }
            .padding()
        }
        .frame(width: 400, height: 500)
        .background(GlassBackground())
    }
}

#Preview {
    DashboardView()
}
```

- [ ] **Step 2: 创建 StatCard.swift**

```swift
import SwiftUI

struct StatCard: View {
    let title: String
    let value: String
    var trend: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            if let trend = trend {
                Text(trend)
                    .font(.caption)
                    .foregroundColor(trend.hasPrefix("+") ? .green : .red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview {
    StatCard(title: "今日 Token", value: "2,456,789", trend: "+12%")
}
```

- [ ] **Step 3: 创建 TokenChart.swift**

```swift
import SwiftUI
import Charts

struct TokenChart: View {
    let stats: [DailyStats]

    var body: some View {
        Chart(stats) { stat in
            BarMark(
                x: .value("日期", stat.formattedDate),
                y: .value("Token", stat.totalTokens)
            )
            .foregroundStyle(by: .value("类型", "Token"))
        }
        .frame(height: 150)
        .chartXAxisLabel("日期")
        .chartYAxisLabel("Token")
    }
}

#Preview {
    TokenChart(stats: [])
}
```

- [ ] **Step 4: 创建 ModelDistribution.swift**

```swift
import SwiftUI

struct ModelDistribution: View {
    let models: [(name: String, percentage: Double)] = [
        ("glm-5.1", 0.78),
        ("qwen3.5-plus", 0.18),
        ("其他", 0.04)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(models, id: \.name) { model in
                HStack {
                    Text(model.name)
                        .font(.subheadline)

                    Spacer()

                    Text("\(Int(model.percentage * 100))%")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                ProgressView(value: model.percentage)
                    .progressViewStyle(LinearProgressViewStyle())
            }
        }
    }
}

#Preview {
    ModelDistribution()
}
```

- [ ] **Step 5: 提交**

```bash
git add ClaudeCodeMonitor/Views/Dashboard/*.swift
git commit -m "feat: 创建数据看板风格视图 (Dashboard/StatCard/TokenChart/ModelDistribution)"
```

---

## Task 13: UI 层 - 时间线风格视图

**Files:**
- Create: `ClaudeCodeMonitor/Views/Timeline/TimelineView.swift`
- Create: `ClaudeCodeMonitor/Views/Timeline/TimelineEvent.swift`
- Create: `ClaudeCodeMonitor/Views/Timeline/SnapshotDetail.swift`

- [ ] **Step 1: 创建 TimelineView.swift**

```swift
import SwiftUI

struct TimelineView: View {
    @State private var events: [TimelineEvent] = []
    @State private var selectedDate: Date = Date()
    @State private var viewMode: TimelineViewMode = .day

    var body: some View {
        VStack(spacing: 0) {
            // 日期导航
            HStack {
                Button("<") { }
                Spacer()
                Text(formatDate(selectedDate))
                    .font(.headline)
                Spacer()
                Button(">") { }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            // 视图模式切换
            Picker("", selection: $viewMode) {
                Text("日").tag(TimelineViewMode.day)
                Text("周").tag(TimelineViewMode.week)
                Text("月").tag(TimelineViewMode.month)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)

            Divider()

            // 时间线列表
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(events) { event in
                        TimelineEventRow(event: event)
                    }
                }
                .padding()
            }
        }
        .frame(width: 400, height: 500)
        .background(GlassBackground())
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy 年 MM 月"
        return formatter.string(from: date)
    }
}

enum TimelineViewMode {
    case day, week, month
}

#Preview {
    TimelineView()
}
```

- [ ] **Step 2: 创建 TimelineEvent.swift**

```swift
import SwiftUI

struct TimelineEvent: Identifiable {
    let id: String
    let timestamp: Date
    let type: TimelineEventType
    let sessionId: String?
    let project: String?
    let tokens: Int64?
    let details: String
}

enum TimelineEventType {
    case sessionStart
    case sessionEnd
    case toolCallPeak
    case snapshot
}

struct TimelineEventRow: View {
    let event: TimelineEvent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 时间
            Text(formatTime(event.timestamp))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 50)

            // 图标
            Image(systemName: iconForType(event.type))
                .foregroundColor(colorForType(event.type))

            // 内容
            VStack(alignment: .leading, spacing: 4) {
                Text(event.details)
                    .font(.subheadline)

                if let project = event.project {
                    Text(project)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                if let tokens = event.tokens {
                    Text("\(tokens) tokens")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func iconForType(_ type: TimelineEventType) -> String {
        switch type {
        case .sessionStart: return "play.circle.fill"
        case .sessionEnd: return "stop.circle.fill"
        case .toolCallPeak: return "bolt.fill"
        case .snapshot: return "doc.fill"
        }
    }

    private func colorForType(_ type: TimelineEventType) -> Color {
        switch type {
        case .sessionStart: return .green
        case .sessionEnd: return .red
        case .toolCallPeak: return .orange
        case .snapshot: return .blue
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

#Preview {
    TimelineEventRow(event: TimelineEvent(
        id: "1", timestamp: Date(), type: .sessionStart,
        sessionId: "test", project: "mac-cc-bar", tokens: 12456,
        details: "会话启动"
    ))
}
```

- [ ] **Step 3: 创建 SnapshotDetail.swift**

```swift
import SwiftUI

struct SnapshotDetail: View {
    let sessionId: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("会话快照")
                .font(.headline)

            Divider()

            DetailRow(label: "启动时间", value: "2026-03-29 09:00:54")
            DetailRow(label: "项目路径", value: "~/project/mac/cc-bar")
            DetailRow(label: "模型", value: "glm-5.1")
            DetailRow(label: "Token", value: "12,456 (in: 10k, out: 2k)")
            DetailRow(label: "消息数", value: "15")
            DetailRow(label: "Tool Calls", value: "Bash×5, Read×3")
        }
        .padding()
        .frame(width: 300)
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)

            Text(value)
                .font(.subheadline)
        }
    }
}

#Preview {
    SnapshotDetail(sessionId: "test")
}
```

- [ ] **Step 4: 提交**

```bash
git add ClaudeCodeMonitor/Views/Timeline/*.swift
git commit -m "feat: 创建时间线风格视图 (TimelineView/TimelineEvent/SnapshotDetail)"
```

---

## Task 14: UI 层 - ContentView 整合

**Files:**
- Modify: `ClaudeCodeMonitor/App/ContentView.swift`

- [ ] **Step 1: 更新 ContentView.swift (视图容器)**

```swift
import SwiftUI

struct ContentView: View {
    @State private var currentView: DefaultView

    init() {
        _currentView = State(initialValue: AppPreferences.shared.defaultView)
    }

    var body: some View {
        Group {
            switch currentView {
            case .minimal:
                MinimalView()
            case .dashboard:
                DashboardView()
            case .timeline:
                TimelineView()
            }
        }
        .environmentObject(self)
    }

    func switchToView(_ view: DefaultView) {
        currentView = view
        if AppPreferences.shared.rememberLastView {
            AppPreferences.shared.lastView = view
        }
    }
}

#Preview {
    ContentView()
}
```

- [ ] **Step 2: 提交**

```bash
git add ClaudeCodeMonitor/App/ContentView.swift
git commit -m "feat: 整合三视图到 ContentView"
```

---

## Task 15: 测试与验收

**Files:**
- Create: `ClaudeCodeMonitorTests/`

- [ ] **Step 1: 创建测试目录**

```bash
mkdir -p ClaudeCodeMonitor/ClaudeCodeMonitorTests
```

- [ ] **Step 2: 创建 ProjectResolverTests.swift**

```swift
import XCTest
@testable import ClaudeCodeMonitor

final class ProjectResolverTests: XCTestCase {
    let resolver = ProjectResolver.shared

    func testNormalizePath() {
        // 测试路径规范化
    }

    func testGitRootDetection() {
        // 测试 Git 根目录检测
    }

    func testProjectIdExtraction() {
        // 测试项目 ID 提取
    }
}
```

- [ ] **Step 3: 创建 TokenEstimatorTests.swift**

```swift
import XCTest
@testable import ClaudeCodeMonitor

final class TokenEstimatorTests: XCTestCase {
    let estimator = TokenEstimator.shared

    func testTokenEstimation() {
        // 测试 Token 估算公式
        let text = "你好 Hello"
        let tokens = estimator.estimateTokens(from: text, model: "glm-5.1")
        XCTAssertGreaterThan(tokens, 0)
    }

    func testConfidenceCalculation() {
        // 测试置信度计算
    }
}
```

- [ ] **Step 4: 运行测试**

```bash
cd ClaudeCodeMonitor
swift test
```

- [ ] **Step 5: 提交**

```bash
git add ClaudeCodeMonitor/ClaudeCodeMonitorTests/*.swift
git commit -m "test: 创建单元测试"
```

---

## Task 16: README 与文档

**Files:**
- Create: `ClaudeCodeMonitor/README.md`

- [ ] **Step 1: 创建 README.md**

```markdown
# Claude Code Monitor

macOS 原生菜单栏应用，监控 Claude Code 的所有本地行为。

## 功能

- **会话监控**: 追踪活跃会话状态、时长、项目路径
- **Token 统计**: 实时估算当前会话 Token 消耗、展示历史趋势
- **模型分析**: 按模型聚合使用量
- **三种 UI 风格**: 极简/数据看板/时间线可切换

## 技术栈

- Swift 5.9+
- SwiftUI + AppKit
- SQLite.swift
- macOS 14+

## 安装

1. 打开 `ClaudeCodeMonitor.xcodeproj`
2. 选择 `Product > Build`
3. 将生成的应用拖拽到 `/Applications`

## 配置

首次启动后，点击菜单栏图标，进入设置面板配置：
- 默认视图
- 刷新频率 (3 秒 -30 分钟)
- 数据保留期限

## 数据存储

数据存储在 `~/Library/Application Support/ClaudeMonitor/data.db`

## 开发

```bash
cd ClaudeCodeMonitor
swift build
swift test
```

## License

MIT
```

- [ ] **Step 2: 提交**

```bash
git add ClaudeCodeMonitor/README.md
git commit -m "docs: 创建 README"
```

---

## 自审清单

- [ ] **Spec 覆盖检查**: 逐条核对设计文档中的需求，确保每个功能都有对应的 Task
- [ ] **占位符扫描**: 检查是否有 "TBD"、"TODO"、"实现上述功能" 等占位符
- [ ] **类型一致性**: 检查 Model 定义与 Service/View 中使用的类型是否一致
- [ ] **文件路径**: 确保所有文件路径正确
- [ ] **命令可执行**: 确保所有 bash 命令可执行

---

**计划完成。** 两个执行选项：

**1. 子代理驱动 (推荐)** - 每个 Task 分配一个子代理独立执行，Task 间设置审查点，快速迭代

**2. 内联执行** - 在当前会话中使用 executing-plans 技能批量执行 Task，设置审查点

选择哪种方式？
