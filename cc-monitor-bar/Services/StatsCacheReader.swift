import Foundation

// MARK: - Stats Cache Reader

/// 读取 stats-cache.json 和备份文件
struct StatsCacheReader {
    let paths: ClaudeDataPaths

    // MARK: - Stats Cache

    func readStatsCache() throws -> StatsCache {
        let data = try Data(contentsOf: URL(fileURLWithPath: paths.statsCache))
        return try JSONDecoder().decode(StatsCache.self, from: data)
    }

    // MARK: - Backup

    /// 读取最新的备份文件，返回每个项目的最后使用数据
    func readLatestBackup() -> [String: ProjectBackupData] {
        var result: [String: ProjectBackupData] = [:]

        guard let files = try? FileManager.default.contentsOfDirectory(atPath: paths.backupsDir) else {
            return result
        }

        let backupFiles = files
            .filter { $0.hasPrefix(".claude.json.backup.") }
            .sorted()
            .suffix(1)

        for file in backupFiles {
            let filePath = "\(paths.backupsDir)/\(file)"
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let projects = json["projects"] as? [String: [String: Any]] else {
                continue
            }

            for (path, info) in projects {
                guard let modelUsage = info["lastModelUsage"] as? [String: [String: Any]] else { continue }

                var models: [String: ModelUsage] = [:]
                for (model, usage) in modelUsage {
                    models[model] = ModelUsage(
                        inputTokens: parseBackupInt64(usage["inputTokens"]),
                        outputTokens: parseBackupInt64(usage["outputTokens"]),
                        cacheReadInputTokens: parseBackupInt64(usage["cacheReadInputTokens"]),
                        cacheCreationInputTokens: parseBackupInt64(usage["cacheCreationInputTokens"]),
                        webSearchRequests: Int(parseBackupInt64(usage["webSearchRequests"])),
                        costUSD: usage["costUSD"] as? Double ?? 0,
                        contextWindow: Int(parseBackupInt64(usage["contextWindow"])),
                        maxOutputTokens: Int(parseBackupInt64(usage["maxOutputTokens"]))
                    )
                }

                if !models.isEmpty {
                    result[path] = ProjectBackupData(
                        path: path,
                        lastModelUsage: models,
                        lastTotalInputTokens: parseBackupInt64(info["lastTotalInputTokens"]),
                        lastTotalOutputTokens: parseBackupInt64(info["lastTotalOutputTokens"]),
                        lastTotalCacheReadInputTokens: parseBackupInt64(info["lastTotalCacheReadInputTokens"]),
                        lastTotalCacheCreationInputTokens: parseBackupInt64(info["lastTotalCacheCreationInputTokens"])
                    )
                }
            }
        }

        return result
    }

    private func parseBackupInt64(_ value: Any?) -> Int64 {
        guard let v = value else { return 0 }
        if let i = v as? Int { return Int64(i) }
        if let i = v as? Int64 { return i }
        if let d = v as? Double { return Int64(d) }
        return 0
    }
}
