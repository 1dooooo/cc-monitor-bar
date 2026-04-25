import Foundation
import SQLite

enum Schema {
    static func migrate(_ db: Connection) throws {
        try createToolCallsTable(db)
        try createProcessedFilesTable(db)
        try createSessionTables(db)
    }

    // MARK: - tool_calls

    /// 工具调用去重键表，UNIQUE INDEX ON dedup_key
    private static func createToolCallsTable(_ db: Connection) throws {
        try db.run("""
            CREATE TABLE IF NOT EXISTS tool_calls (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                dedup_key TEXT NOT NULL,
                tool_name TEXT NOT NULL DEFAULT '',
                session_id TEXT NOT NULL DEFAULT '',
                inserted_at REAL NOT NULL
            )
            """)
        try db.run("""
            CREATE UNIQUE INDEX IF NOT EXISTS idx_tool_calls_dedup_key
            ON tool_calls(dedup_key)
            """)
    }

    // MARK: - processed_files

    /// 增量解析文件索引表（跨重启持久化）
    private static func createProcessedFilesTable(_ db: Connection) throws {
        try db.run("""
            CREATE TABLE IF NOT EXISTS processed_files (
                path TEXT PRIMARY KEY,
                mtime REAL NOT NULL,
                file_size INTEGER NOT NULL,
                offset INTEGER NOT NULL DEFAULT 0,
                message_count INTEGER NOT NULL DEFAULT 0,
                tool_call_count INTEGER NOT NULL DEFAULT 0,
                total_tokens INTEGER NOT NULL DEFAULT 0,
                last_accessed REAL NOT NULL
            )
            """)
        try db.run("""
            CREATE INDEX IF NOT EXISTS idx_pf_mtime
            ON processed_files(mtime)
            """)
        try db.run("""
            CREATE INDEX IF NOT EXISTS idx_pf_last_accessed
            ON processed_files(last_accessed)
            """)
    }

    // MARK: - sessions / session_token_usage / daily_stats / daily_model_usage

    private static func createSessionTables(_ db: Connection) throws {
        try db.run("""
            CREATE TABLE IF NOT EXISTS sessions (
                id TEXT PRIMARY KEY,
                pid INTEGER NOT NULL DEFAULT 0,
                project_path TEXT NOT NULL DEFAULT '',
                project_id TEXT NOT NULL DEFAULT '',
                started_at REAL NOT NULL,
                ended_at REAL,
                duration_ms INTEGER NOT NULL DEFAULT 0,
                message_count INTEGER NOT NULL DEFAULT 0,
                tool_call_count INTEGER NOT NULL DEFAULT 0,
                entrypoint TEXT NOT NULL DEFAULT '',
                updated_at REAL NOT NULL
            )
            """)

        try db.run("""
            CREATE TABLE IF NOT EXISTS session_token_usage (
                session_id TEXT PRIMARY KEY,
                input_tokens INTEGER NOT NULL DEFAULT 0,
                output_tokens INTEGER NOT NULL DEFAULT 0,
                cache_read_tokens INTEGER NOT NULL DEFAULT 0,
                cache_creation_tokens INTEGER NOT NULL DEFAULT 0,
                context_tokens INTEGER NOT NULL DEFAULT 0,
                FOREIGN KEY (session_id) REFERENCES sessions(id)
            )
            """)

        try db.run("""
            CREATE TABLE IF NOT EXISTS daily_stats (
                date TEXT NOT NULL,
                project_id TEXT NOT NULL DEFAULT '',
                message_count INTEGER NOT NULL DEFAULT 0,
                session_count INTEGER NOT NULL DEFAULT 0,
                tool_call_count INTEGER NOT NULL DEFAULT 0,
                total_tokens INTEGER NOT NULL DEFAULT 0,
                input_tokens INTEGER NOT NULL DEFAULT 0,
                output_tokens INTEGER NOT NULL DEFAULT 0,
                cache_tokens INTEGER NOT NULL DEFAULT 0,
                PRIMARY KEY (date, project_id)
            )
            """)

        try db.run("""
            CREATE TABLE IF NOT EXISTS daily_model_usage (
                date TEXT NOT NULL,
                model TEXT NOT NULL,
                input_tokens INTEGER NOT NULL DEFAULT 0,
                output_tokens INTEGER NOT NULL DEFAULT 0,
                cache_tokens INTEGER NOT NULL DEFAULT 0,
                total_tokens INTEGER NOT NULL DEFAULT 0,
                PRIMARY KEY (date, model)
            )
            """)
    }
}
