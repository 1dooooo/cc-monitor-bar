import Foundation
import SQLite

/// SQLite 连接管理器，WAL 模式，单例
final class DatabaseManager {
    static let shared = DatabaseManager()

    let db: Connection

    private init() {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("cc-monitor-bar")
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let dbURL = dir.appendingPathComponent("monitor.db")
        db = try! Connection(dbURL.path)
        try! db.execute("PRAGMA journal_mode = WAL")
        try! db.execute("PRAGMA foreign_keys = ON")
    }
}
