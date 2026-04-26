import Foundation
import SQLite

// MARK: - Claude Data Paths

struct ClaudeDataPaths {
    let claudeDir: String
    let statsCache: String
    let historyJsonl: String
    let sessionsDir: String
    let projectsDir: String
    let xcodeProjectsDir: String
    let backupsDir: String

    init(baseDir: String? = nil) {
        let home = baseDir ?? FileManager.default.homeDirectoryForCurrentUser.path
        claudeDir = "\(home)/.claude"
        statsCache = "\(claudeDir)/stats-cache.json"
        historyJsonl = "\(claudeDir)/history.jsonl"
        sessionsDir = "\(claudeDir)/sessions"
        projectsDir = "\(claudeDir)/projects"
        xcodeProjectsDir = "\(home)/Library/Developer/Xcode/CodingAssistant/ClaudeAgentConfig/projects"
        backupsDir = "\(claudeDir)/backups"
    }

    var projectRoots: [String] {
        var seen = Set<String>()
        return [projectsDir, xcodeProjectsDir].filter { seen.insert($0).inserted }
    }
}

// MARK: - Claude Data Reader (Facade)

/// 门面类：协调子组件，暴露所有公共方法签名不变
class ClaudeDataReader {
    let paths: ClaudeDataPaths
    private let db: Connection
    private let statsCacheReader: StatsCacheReader
    private let indexManager: SQLiteIndexManager
    private let sessionUsageReader: SessionUsageReader

    init(paths: ClaudeDataPaths = .init()) {
        self.paths = paths
        let connection: Connection = DatabaseManager.shared.db
        self.db = connection

        self.statsCacheReader = StatsCacheReader(paths: paths)
        self.indexManager = SQLiteIndexManager(db: connection)
        self.sessionUsageReader = SessionUsageReader(paths: paths, indexManager: indexManager)

        try? Schema.migrate(db)
        indexManager.loadIndex()
    }

    func invalidateUsageIndex() {
        sessionUsageReader.invalidateUsageIndex()
    }

    // MARK: - Stats Cache

    func readStatsCache() throws -> StatsCache {
        try statsCacheReader.readStatsCache()
    }

    func readLatestBackup() -> [String: ProjectBackupData] {
        statsCacheReader.readLatestBackup()
    }

    // MARK: - Persistence

    func persistSessions(_ sessions: [(id: String, pid: Int32, projectPath: String, projectId: String, startedAt: Date, messageCount: Int, toolCallCount: Int, entrypoint: String)], usages: [String: SessionUsage]) {
        let now = Date().timeIntervalSince1970
        for session in sessions {
            do {
                _ = try db.run("""
                    INSERT OR REPLACE INTO sessions (id, pid, project_path, project_id, started_at, ended_at, duration_ms, message_count, tool_call_count, entrypoint, updated_at)
                    VALUES (?, ?, ?, ?, ?, NULL, ?, ?, ?, ?, ?)
                    """, session.id, Int64(session.pid), session.projectPath, session.projectId,
                    session.startedAt.timeIntervalSince1970,
                    Int64(Date().timeIntervalSince1970 * 1000) - Int64(session.startedAt.timeIntervalSince1970 * 1000),
                    Int64(session.messageCount), Int64(session.toolCallCount), session.entrypoint, now
                )

                if let usage = usages[session.id] {
                    _ = try db.run("""
                        INSERT OR REPLACE INTO session_token_usage (session_id, input_tokens, output_tokens, cache_read_tokens, cache_creation_tokens, context_tokens)
                        VALUES (?, ?, ?, ?, ?, ?)
                        """, session.id, usage.inputTokens, usage.outputTokens,
                        usage.cacheReadTokens, usage.cacheCreationTokens, usage.contextTokens
                    )
                }
            } catch {
                // Ignore write errors
            }
        }
    }

    func persistDailyStats(
        date: String,
        projectId: String,
        messageCount: Int,
        sessionCount: Int,
        toolCallCount: Int,
        totalTokens: Int64,
        inputTokens: Int64,
        outputTokens: Int64,
        cacheTokens: Int64,
        modelBreakdown: [(name: String, tokens: Int64, inputTokens: Int64, outputTokens: Int64, cacheTokens: Int64)]
    ) {
        do {
            _ = try db.run("""
                INSERT OR REPLACE INTO daily_stats (date, project_id, message_count, session_count, tool_call_count, total_tokens, input_tokens, output_tokens, cache_tokens)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, date, projectId, messageCount, sessionCount, toolCallCount,
                totalTokens, inputTokens, outputTokens, cacheTokens
            )

            for model in modelBreakdown {
                _ = try db.run("""
                    INSERT OR REPLACE INTO daily_model_usage (date, model, input_tokens, output_tokens, cache_tokens, total_tokens)
                    VALUES (?, ?, ?, ?, ?, ?)
                    """, date, model.name, model.inputTokens, model.outputTokens, model.cacheTokens, model.tokens
                )
            }
        } catch {
            // Ignore write errors
        }
    }

    // MARK: - Active Sessions

    func readActiveSessions() throws -> [ActiveSessionInfo] {
        try sessionUsageReader.readActiveSessions()
    }

    // MARK: - History

    func readHistory(limit: Int = 100) throws -> [HistoryEntry] {
        try sessionUsageReader.readHistory(limit: limit)
    }

    // MARK: - Per-Session Usage

    func readSessionUsage(cwd: String, sessionId: String) -> SessionUsage {
        sessionUsageReader.readSessionUsage(cwd: cwd, sessionId: sessionId)
    }

    // MARK: - Today Usage from JSONL

    func readTodayUsage() -> (
        messageCount: Int,
        sessionCount: Int,
        toolCallCount: Int,
        totalTokens: Int64,
        inputTokens: Int64,
        outputTokens: Int64,
        cacheTokens: Int64,
        modelBreakdown: [(name: String, tokens: Int64, inputTokens: Int64, outputTokens: Int64, cacheTokens: Int64)],
        toolCounts: [String: Int]
    ) {
        sessionUsageReader.readTodayUsage()
    }

    // MARK: - Today Usage by Project

    func readTodayUsageByProject() -> [ProjectSummary] {
        sessionUsageReader.readTodayUsageByProject()
    }

    // MARK: - Path Resolution

    func resolveSessionBasePath(cwd: String, sessionId: String) -> String? {
        sessionUsageReader.resolveSessionBasePath(cwd: cwd, sessionId: sessionId)
    }
}
