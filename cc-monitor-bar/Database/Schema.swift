import Foundation
import SQLite

enum Schema {
    static func migrate(_ db: Connection) throws {
        try createToolCallsTable(db)
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
}
