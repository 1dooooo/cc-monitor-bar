import Foundation
import SQLite

/// Repository — 查询 SQLite 持久化的会话和统计
struct SessionRecord: Identifiable {
    let id: String
    let pid: Int
    let projectPath: String
    let projectId: String
    let startedAt: Date
    let endedAt: Date?
    let durationMs: Int
    let messageCount: Int
    let toolCallCount: Int
    let entrypoint: String
    let inputTokens: Int64
    let outputTokens: Int64
    let cacheReadTokens: Int64
    let cacheCreationTokens: Int64
    let contextTokens: Int64
}

struct DailyStatsRecord {
    let date: String
    let projectId: String
    let messageCount: Int
    let sessionCount: Int
    let toolCallCount: Int
    let totalTokens: Int64
    let inputTokens: Int64
    let outputTokens: Int64
    let cacheTokens: Int64
}

final class Repository {
    private let db: Connection

    init(db: Connection = DatabaseManager.shared.db) {
        self.db = db
    }

    // MARK: - Sessions

    /// 查询最近 N 个会话
    func fetchRecentSessions(limit: Int = 50) throws -> [SessionRecord] {
        let query = """
            SELECT s.id, s.pid, s.project_path, s.project_id, s.started_at, s.ended_at,
                   s.duration_ms, s.message_count, s.tool_call_count, s.entrypoint,
                   u.input_tokens, u.output_tokens, u.cache_read_tokens,
                   u.cache_creation_tokens, u.context_tokens
            FROM sessions s
            LEFT JOIN session_token_usage u ON s.id = u.session_id
            ORDER BY s.started_at DESC
            LIMIT \(limit)
        """
        return try db.prepare(query).map { row -> SessionRecord in
            let endedAtRaw: Double? = row[5] as? Double
            return SessionRecord(
                id: row[0] as? String ?? "",
                pid: row[1] as? Int ?? 0,
                projectPath: row[2] as? String ?? "",
                projectId: row[3] as? String ?? "",
                startedAt: Date(timeIntervalSince1970: row[4] as? Double ?? 0),
                endedAt: endedAtRaw.map { Date(timeIntervalSince1970: $0) },
                durationMs: row[6] as? Int ?? 0,
                messageCount: row[7] as? Int ?? 0,
                toolCallCount: row[8] as? Int ?? 0,
                entrypoint: row[9] as? String ?? "",
                inputTokens: row[10] as? Int64 ?? 0,
                outputTokens: row[11] as? Int64 ?? 0,
                cacheReadTokens: row[12] as? Int64 ?? 0,
                cacheCreationTokens: row[13] as? Int64 ?? 0,
                contextTokens: row[14] as? Int64 ?? 0
            )
        }
    }

    /// 按项目筛选会话
    func fetchSessionsByProject(_ projectId: String, limit: Int = 50) throws -> [SessionRecord] {
        let query = """
            SELECT s.id, s.pid, s.project_path, s.project_id, s.started_at, s.ended_at,
                   s.duration_ms, s.message_count, s.tool_call_count, s.entrypoint,
                   u.input_tokens, u.output_tokens, u.cache_read_tokens,
                   u.cache_creation_tokens, u.context_tokens
            FROM sessions s
            LEFT JOIN session_token_usage u ON s.id = u.session_id
            WHERE s.project_id = ?
            ORDER BY s.started_at DESC
            LIMIT \(limit)
        """
        return try db.prepare(query, projectId).map { row -> SessionRecord in
            let endedAtRaw: Double? = row[5] as? Double
            return SessionRecord(
                id: row[0] as? String ?? "",
                pid: row[1] as? Int ?? 0,
                projectPath: row[2] as? String ?? "",
                projectId: row[3] as? String ?? "",
                startedAt: Date(timeIntervalSince1970: row[4] as? Double ?? 0),
                endedAt: endedAtRaw.map { Date(timeIntervalSince1970: $0) },
                durationMs: row[6] as? Int ?? 0,
                messageCount: row[7] as? Int ?? 0,
                toolCallCount: row[8] as? Int ?? 0,
                entrypoint: row[9] as? String ?? "",
                inputTokens: row[10] as? Int64 ?? 0,
                outputTokens: row[11] as? Int64 ?? 0,
                cacheReadTokens: row[12] as? Int64 ?? 0,
                cacheCreationTokens: row[13] as? Int64 ?? 0,
                contextTokens: row[14] as? Int64 ?? 0
            )
        }
    }

    // MARK: - Daily Stats

    /// 查询最近 N 天的每日统计
    func fetchDailyStats(days: Int = 30) throws -> [DailyStatsRecord] {
        let adjustedQuery = """
            SELECT date, project_id, message_count, session_count, tool_call_count,
                   total_tokens, input_tokens, output_tokens, cache_tokens
            FROM daily_stats
            WHERE date >= date('now', '-\(days) days') AND project_id = '_global'
            ORDER BY date DESC
        """
        return try db.prepare(adjustedQuery).map { row -> DailyStatsRecord in
            DailyStatsRecord(
                date: row[0] as? String ?? "",
                projectId: row[1] as? String ?? "",
                messageCount: row[2] as? Int ?? 0,
                sessionCount: row[3] as? Int ?? 0,
                toolCallCount: row[4] as? Int ?? 0,
                totalTokens: row[5] as? Int64 ?? 0,
                inputTokens: row[6] as? Int64 ?? 0,
                outputTokens: row[7] as? Int64 ?? 0,
                cacheTokens: row[8] as? Int64 ?? 0
            )
        }
    }
}
