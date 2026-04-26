import Foundation
import SQLite

// MARK: - SQLite Index Persistence

/// 管理 processed_files 表的索引持久化和清理
class SQLiteIndexManager {
    private let db: Connection
    private let maxIndexedFileRanges = 2000

    init(db: Connection) {
        self.db = db
    }

    /// 从 SQLite 加载已处理文件索引到内存
    /// 注意：不执行加载 — getCachedFileStats() 直接查 SQLite，
    /// parseJsonlUsage() 会重新构建正确的 UsageAccumulator
    func loadIndex() {
        // No-op: kept for API compatibility
    }

    /// UPSERT 已处理文件索引到 SQLite
    func persistProcessedFileIndex(path: String, entry: FileUsageIndexEntry, usage: SessionUsage) {
        do {
            _ = try db.run("""
                INSERT INTO processed_files (path, mtime, file_size, offset, message_count, tool_call_count, total_tokens, input_tokens, output_tokens, cache_read_tokens, cache_creation_tokens, last_accessed)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(path) DO UPDATE SET
                    mtime = excluded.mtime,
                    file_size = excluded.file_size,
                    offset = excluded.offset,
                    message_count = excluded.message_count,
                    tool_call_count = excluded.tool_call_count,
                    total_tokens = excluded.total_tokens,
                    input_tokens = excluded.input_tokens,
                    output_tokens = excluded.output_tokens,
                    cache_read_tokens = excluded.cache_read_tokens,
                    cache_creation_tokens = excluded.cache_creation_tokens,
                    last_accessed = excluded.last_accessed
                """,
                path, entry.modifiedAt, Int64(entry.fileSize), Int64(entry.offset),
                Int64(entry.accumulator.messageCount),
                Int64(entry.accumulator.toolUseIds.count + entry.accumulator.anonymousToolUseFingerprints.count),
                Int64(usage.totalTokens),
                Int64(usage.inputTokens),
                Int64(usage.outputTokens),
                Int64(usage.cacheReadTokens),
                Int64(usage.cacheCreationTokens),
                entry.lastAccessAt
            )
        } catch {
            // Ignore write errors
        }
    }

    /// 清理 SQLite 中过旧的索引条目（超过 maxIndexedFileRanges 时按 last_accessed 淘汰）
    func cleanupIndex() {
        do {
            let countValue: Int64 = try db.scalar("SELECT COUNT(*) FROM processed_files") as? Int64 ?? 0
            if countValue > Int64(maxIndexedFileRanges) {
                let removeCount = countValue - Int64(maxIndexedFileRanges)
                _ = try db.run("""
                    DELETE FROM processed_files
                    WHERE path IN (
                        SELECT path FROM processed_files
                        ORDER BY last_accessed ASC
                        LIMIT ?
                    )
                    """, removeCount)
            }
        } catch {
            // Ignore cleanup errors
        }
    }

    /// 持久化工具调用去重键
    func persistDedupKeys(_ keys: [String], file: String) {
        for key in keys {
            do {
                _ = try db.run(
                    "INSERT OR IGNORE INTO tool_calls (dedup_key, tool_name, session_id, inserted_at) VALUES (?, ?, ?, ?)",
                    key, "", file, Date().timeIntervalSince1970
                )
            } catch {
                // Ignore insert errors
            }
        }
    }

    /// 检查 processed_files 表，如果文件未变更则返回缓存的统计数据
    func getCachedFileStats(at filePath: String, currentMtime: TimeInterval, currentSize: UInt64) -> SessionUsage? {
        do {
            let rows = try db.prepare("""
                SELECT mtime, file_size, offset, message_count, tool_call_count,
                       total_tokens, input_tokens, output_tokens, cache_read_tokens, cache_creation_tokens
                FROM processed_files WHERE path = ?
                """, filePath)
            for row in rows {
                let cachedMtime: Double = row[0] as? Double ?? 0
                let cachedSize: Int64 = row[1] as? Int64 ?? 0
                let offset: Int64 = row[2] as? Int64 ?? 0

                if cachedMtime == currentMtime && UInt64(cachedSize) == currentSize && offset > 0 {
                    let messageCount: Int = row[3] as? Int ?? 0
                    let toolCallCount: Int = row[4] as? Int ?? 0
                    let inputTokens: Int64 = row[6] as? Int64 ?? 0
                    let outputTokens: Int64 = row[7] as? Int64 ?? 0
                    let cacheReadTokens: Int64 = row[8] as? Int64 ?? 0
                    let cacheCreationTokens: Int64 = row[9] as? Int64 ?? 0
                    let totalTokens = inputTokens + outputTokens + cacheReadTokens + cacheCreationTokens
                    return SessionUsage(
                        inputTokens: inputTokens, outputTokens: outputTokens,
                        cacheReadTokens: cacheReadTokens, cacheCreationTokens: cacheCreationTokens,
                        messageCount: messageCount, toolCallCount: toolCallCount,
                        models: [:], modelBreakdowns: [:], toolCounts: [:],
                        contextTokens: totalTokens
                    )
                }
            }
        } catch {
            // Ignore query errors
        }
        return nil
    }
}
