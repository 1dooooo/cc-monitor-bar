import Foundation
import SQLite

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

class ClaudeDataReader {
    let paths: ClaudeDataPaths
    private static let iso8601WithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601Basic: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private let usageIndexLock = NSLock()
    private var usageIndex: [String: [JsonlRangeKey: FileUsageIndexEntry]] = [:]
    private let indexedTailProbeBytes: UInt64 = 512
    private let maxIndexedFileRanges = 2000

    init(paths: ClaudeDataPaths = .init()) {
        self.paths = paths
        try? Schema.migrate(db)
        loadIndexFromSQLite()
    }

    func invalidateUsageIndex() {
        usageIndexLock.lock()
        usageIndex.removeAll()
        usageIndexLock.unlock()
    }

    // MARK: - Stats Cache

    func readStatsCache() throws -> StatsCache {
        let data = try Data(contentsOf: URL(fileURLWithPath: paths.statsCache))
        return try JSONDecoder().decode(StatsCache.self, from: data)
    }

    // MARK: - Persistence

    /// 持久化活跃会话到 SQLite
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
                // 忽略写入错误
            }
        }
    }

    /// 持久化每日统计到 SQLite
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
            // 忽略写入错误
        }
    }

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
                        inputTokens: int642(usage["inputTokens"]),
                        outputTokens: int642(usage["outputTokens"]),
                        cacheReadInputTokens: int642(usage["cacheReadInputTokens"]),
                        cacheCreationInputTokens: int642(usage["cacheCreationInputTokens"]),
                        webSearchRequests: Int(int642(usage["webSearchRequests"])),
                        costUSD: usage["costUSD"] as? Double ?? 0,
                        contextWindow: Int(int642(usage["contextWindow"])),
                        maxOutputTokens: Int(int642(usage["maxOutputTokens"]))
                    )
                }

                if !models.isEmpty {
                    result[path] = ProjectBackupData(
                        path: path,
                        lastModelUsage: models,
                        lastTotalInputTokens: int642(info["lastTotalInputTokens"]),
                        lastTotalOutputTokens: int642(info["lastTotalOutputTokens"]),
                        lastTotalCacheReadInputTokens: int642(info["lastTotalCacheReadInputTokens"]),
                        lastTotalCacheCreationInputTokens: int642(info["lastTotalCacheCreationInputTokens"])
                    )
                }
            }
        }

        return result
    }

    private func int642(_ value: Any?) -> Int64 {
        guard let v = value else { return 0 }
        if let i = v as? Int { return Int64(i) }
        if let i = v as? Int64 { return i }
        if let d = v as? Double { return Int64(d) }
        return 0
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
            .filter { !$0.isEmpty } ?? []

        var entries: [HistoryEntry] = []
        for line in lines.suffix(limit) {
            if let entry = try? JSONDecoder().decode(HistoryEntry.self, from: Data(line.utf8)) {
                entries.append(entry)
            }
        }

        return entries
    }

    // MARK: - Per-Session Usage

    /// 从项目 jsonl 文件中读取指定会话的 token/message/tool 用量
    /// 对流式 assistant 片段按 message.id(+requestId) 去重并合并 usage
    func readSessionUsage(cwd: String, sessionId: String) -> SessionUsage {
        guard let basePath = resolveSessionBasePath(cwd: cwd, sessionId: sessionId) else {
            return SessionUsage.zero
        }

        var result = parseJsonlUsage(at: "\(basePath).jsonl")

        // 纳入子代理数据
        let subagentsDir = "\(basePath)/subagents"
        if let agentFiles = try? FileManager.default.contentsOfDirectory(atPath: subagentsDir)
            .filter({ $0.hasSuffix(".jsonl") }) {
            for file in agentFiles {
                let sub = parseJsonlUsage(at: "\(subagentsDir)/\(file)")
                result = result.merging(sub)
            }
        }

        return result
    }

    // MARK: - Today Usage from JSONL

    /// 检查 processed_files 表，如果文件未变更则返回缓存的统计数据
    /// 用于避免重复解析未修改的文件
    private func getCachedFileStats(at filePath: String, currentMtime: TimeInterval, currentSize: UInt64) -> SessionUsage? {
        do {
            let rows = try db.prepare("SELECT mtime, file_size, offset, message_count, tool_call_count, total_tokens FROM processed_files WHERE path = ?", filePath)
            for row in rows {
                let cachedMtime: Double = row[0] as? Double ?? 0
                let cachedSize: Int64 = row[1] as? Int64 ?? 0
                let offset: Int64 = row[2] as? Int64 ?? 0

                // 文件未变更且已有解析数据（offset > 0），直接使用缓存
                if cachedMtime == currentMtime && UInt64(cachedSize) == currentSize && offset > 0 {
                    let messageCount: Int = row[3] as? Int ?? 0
                    let toolCallCount: Int = row[4] as? Int ?? 0
                    let totalTokens: Int64 = row[5] as? Int64 ?? 0
                    return SessionUsage(
                        inputTokens: totalTokens, outputTokens: 0,
                        cacheReadTokens: 0, cacheCreationTokens: 0,
                        messageCount: messageCount, toolCallCount: toolCallCount,
                        models: [:], modelBreakdowns: [:], toolCounts: [:],
                        contextTokens: totalTokens
                    )
                }
            }
        } catch {
            // 忽略查询错误
        }
        return nil
    }

    /// 从今日会话的 jsonl 文件聚合 token 统计
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
        var messageCount = 0
        var sessionCount = 0
        var toolCallCount = 0
        var totalTokens: Int64 = 0
        var inputTokens: Int64 = 0
        var outputTokens: Int64 = 0
        var cacheTokens: Int64 = 0
        var modelTokens: [String: Int64] = [:]
        var modelInput: [String: Int64] = [:]
        var modelOutput: [String: Int64] = [:]
        var modelCache: [String: Int64] = [:]
        var toolCounts: [String: Int] = [:]

        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? Date.distantFuture
        let todayRange = DateInterval(start: todayStart, end: tomorrowStart)

        let projectRoots = availableProjectRoots()
        guard !projectRoots.isEmpty else {
            return (0, 0, 0, 0, 0, 0, 0, [], [:])
        }

        for projectRoot in projectRoots {
            guard let projectDirs = try? FileManager.default.contentsOfDirectory(atPath: projectRoot) else { continue }

            for projectDir in projectDirs {
                let projectPath = "\(projectRoot)/\(projectDir)"

                // 遍历项目中的 jsonl 文件
                guard let files = try? FileManager.default.contentsOfDirectory(atPath: projectPath) else { continue }
                let jsonlFiles = files.filter { $0.hasSuffix(".jsonl") }

                for file in jsonlFiles {
                    let filePath = "\(projectPath)/\(file)"
                    guard let attrs = try? FileManager.default.attributesOfItem(atPath: filePath),
                          let modDate = attrs[.modificationDate] as? Date,
                          modDate >= todayStart else { continue }

                    let fileSize = attrs[.size] as? Int64 ?? 0

                    // 增量扫描优化：检查 SQLite 缓存，文件未变更时直接读取缓存统计
                    var sessionUsage = getCachedFileStats(at: filePath, currentMtime: modDate.timeIntervalSince1970, currentSize: UInt64(fileSize))
                        ?? parseJsonlUsage(at: filePath, within: todayRange)

                    // 纳入子代理数据
                    let sessionId = file.replacingOccurrences(of: ".jsonl", with: "")
                    let subagentsDir = "\(projectPath)/\(sessionId)/subagents"
                    if let agentFiles = try? FileManager.default.contentsOfDirectory(atPath: subagentsDir)
                        .filter({ $0.hasSuffix(".jsonl") }) {
                        for agentFile in agentFiles {
                            let sub = parseJsonlUsage(at: "\(subagentsDir)/\(agentFile)", within: todayRange)
                            sessionUsage = sessionUsage.merging(sub)
                        }
                    }

                    if sessionUsage.totalTokens > 0 || sessionUsage.messageCount > 0 || sessionUsage.toolCallCount > 0 {
                        sessionCount += 1
                    }

                    messageCount += sessionUsage.messageCount
                    toolCallCount += sessionUsage.toolCallCount
                    inputTokens += sessionUsage.inputTokens
                    outputTokens += sessionUsage.outputTokens
                    cacheTokens += sessionUsage.cacheReadTokens + sessionUsage.cacheCreationTokens

                    if !sessionUsage.modelBreakdowns.isEmpty {
                        for (model, breakdownItem) in sessionUsage.modelBreakdowns {
                            modelTokens[model, default: 0] += breakdownItem.totalTokens
                            modelInput[model, default: 0] += breakdownItem.inputTokens
                            modelOutput[model, default: 0] += breakdownItem.outputTokens
                            modelCache[model, default: 0] += breakdownItem.cacheReadTokens + breakdownItem.cacheCreationTokens
                        }
                    } else {
                        // 回退：当旧数据缺少 modelBreakdowns 时，用该会话比例近似分摊
                        let sessionTotal = max(sessionUsage.totalTokens, 1)
                        for (model, tokens) in sessionUsage.models {
                            let ratio = Double(tokens) / Double(sessionTotal)
                            modelTokens[model, default: 0] += tokens
                            modelInput[model, default: 0] += Int64(Double(sessionUsage.inputTokens) * ratio)
                            modelOutput[model, default: 0] += Int64(Double(sessionUsage.outputTokens) * ratio)
                            modelCache[model, default: 0] += Int64(Double(sessionUsage.cacheReadTokens + sessionUsage.cacheCreationTokens) * ratio)
                        }
                    }

                    for (tool, count) in sessionUsage.toolCounts {
                        toolCounts[tool, default: 0] += count
                    }
                }
            }
        }

        totalTokens = inputTokens + outputTokens + cacheTokens

        var breakdown: [(name: String, tokens: Int64, inputTokens: Int64, outputTokens: Int64, cacheTokens: Int64)] = []
        for model in modelTokens.keys.sorted(by: { modelTokens[$0]! > modelTokens[$1]! }) {
            breakdown.append((
                name: model,
                tokens: modelTokens[model]!,
                inputTokens: modelInput[model]!,
                outputTokens: modelOutput[model]!,
                cacheTokens: modelCache[model]!
            ))
        }

        return (
            messageCount,
            sessionCount,
            toolCallCount,
            totalTokens,
            inputTokens,
            outputTokens,
            cacheTokens,
            breakdown,
            toolCounts
        )
    }

    // MARK: - Today Usage by Project

    /// 按项目聚合 token/session 统计，返回按 token 用量降序排列的项目列表
    func readTodayUsageByProject() -> [ProjectSummary] {
        var projectData: [String: (
            name: String,
            messageCount: Int,
            sessionCount: Int,
            toolCallCount: Int,
            totalTokens: Int64,
            inputTokens: Int64,
            outputTokens: Int64,
            cacheTokens: Int64,
            toolCounts: [String: Int]
        )] = [:]

        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? Date.distantFuture
        let todayRange = DateInterval(start: todayStart, end: tomorrowStart)

        let projectRoots = availableProjectRoots()
        guard !projectRoots.isEmpty else { return [] }

        for projectRoot in projectRoots {
            guard let projectDirs = try? FileManager.default.contentsOfDirectory(atPath: projectRoot) else { continue }

            for projectDir in projectDirs {
                let projectPath = "\(projectRoot)/\(projectDir)"
                let displayName = projectDirNameToDisplayName(projectDir)

                guard let files = try? FileManager.default.contentsOfDirectory(atPath: projectPath) else { continue }
                let jsonlFiles = files.filter { $0.hasSuffix(".jsonl") }

                for file in jsonlFiles {
                    let filePath = "\(projectPath)/\(file)"
                    guard let attrs = try? FileManager.default.attributesOfItem(atPath: filePath),
                          let modDate = attrs[.modificationDate] as? Date,
                          modDate >= todayStart else { continue }

                    let fileSize = attrs[.size] as? Int64 ?? 0

                    // 增量扫描优化：检查 SQLite 缓存，文件未变更时直接读取缓存统计
                    var sessionUsage = getCachedFileStats(at: filePath, currentMtime: modDate.timeIntervalSince1970, currentSize: UInt64(fileSize))
                        ?? parseJsonlUsage(at: filePath, within: todayRange)

                    let sessionId = file.replacingOccurrences(of: ".jsonl", with: "")
                    let subagentsDir = "\(projectPath)/\(sessionId)/subagents"
                    if let agentFiles = try? FileManager.default.contentsOfDirectory(atPath: subagentsDir)
                        .filter({ $0.hasSuffix(".jsonl") }) {
                        for agentFile in agentFiles {
                            let sub = parseJsonlUsage(at: "\(subagentsDir)/\(agentFile)", within: todayRange)
                            sessionUsage = sessionUsage.merging(sub)
                        }
                    }

                    if sessionUsage.totalTokens > 0 || sessionUsage.messageCount > 0 || sessionUsage.toolCallCount > 0 {
                        var data = projectData[projectDir] ?? (
                            name: displayName,
                            messageCount: 0, sessionCount: 0, toolCallCount: 0,
                            totalTokens: 0, inputTokens: 0, outputTokens: 0,
                            cacheTokens: 0, toolCounts: [:]
                        )
                        data.sessionCount += 1
                        data.messageCount += sessionUsage.messageCount
                        data.toolCallCount += sessionUsage.toolCallCount
                        data.totalTokens += sessionUsage.totalTokens
                        data.inputTokens += sessionUsage.inputTokens
                        data.outputTokens += sessionUsage.outputTokens
                        data.cacheTokens += sessionUsage.cacheReadTokens + sessionUsage.cacheCreationTokens
                        for (tool, count) in sessionUsage.toolCounts {
                            data.toolCounts[tool, default: 0] += count
                        }
                        projectData[projectDir] = data
                    }
                }
            }
        }

        return projectData.values
            .filter { $0.totalTokens > 0 || $0.messageCount > 0 }
            .map {
                ProjectSummary(
                    name: $0.name,
                    messageCount: $0.messageCount,
                    sessionCount: $0.sessionCount,
                    toolCallCount: $0.toolCallCount,
                    totalTokens: $0.totalTokens,
                    inputTokens: $0.inputTokens,
                    outputTokens: $0.outputTokens,
                    cacheTokens: $0.cacheTokens,
                    toolCounts: $0.toolCounts
                )
            }
            .sorted { $0.totalTokens > $1.totalTokens }
    }

    /// 将编码后的项目目录名转为可读名称
    private func projectDirNameToDisplayName(_ dirName: String) -> String {
        // 去除前导 `-`
        let stripped = dirName.hasPrefix("-") ? String(dirName.dropFirst()) : dirName
        // 尝试从原始路径中提取项目名 (最后一段路径)
        // 由于编码会丢失信息，这里使用 heuristic: 查找已知的 cwd 映射
        return stripped
    }

    // MARK: - JSONL Parsing

    private struct JsonlRangeKey: Hashable {
        let startEpochSecond: Int64?
        let endEpochSecond: Int64?

        init(dateRange: DateInterval?) {
            if let dateRange {
                startEpochSecond = Int64(dateRange.start.timeIntervalSince1970)
                endEpochSecond = Int64(dateRange.end.timeIntervalSince1970)
            } else {
                startEpochSecond = nil
                endEpochSecond = nil
            }
        }
    }

    private struct IndexedMessageUsage {
        var model: String
        var input: Int64
        var output: Int64
        var cacheRead: Int64
        var cacheCreate: Int64
    }

    private struct UsageAccumulator {
        var messageCount = 0
        var toolUseIds = Set<String>()
        var anonymousToolUseFingerprints = Set<String>()
        var toolCounts: [String: Int] = [:]
        var contextTokens: Int64 = 0  // 累计 context 使用量
        var messages: [String: IndexedMessageUsage] = [:]

        /// 返回所有去重键 (tool_use.id 或匿名指纹)
        func dedupKeys() -> [String] {
            var result = toolUseIds.map { "id:\($0)" }
            result.append(contentsOf: anonymousToolUseFingerprints.map { "fp:\($0)" })
            return result
        }

        func buildSessionUsage() -> SessionUsage {
            var totalInput: Int64 = 0
            var totalOutput: Int64 = 0
            var totalCacheRead: Int64 = 0
            var totalCacheCreate: Int64 = 0
            var modelTokens: [String: Int64] = [:]
            var modelBreakdowns: [String: ModelTokenBreakdown] = [:]

            for (_, msg) in messages {
                totalInput += msg.input
                totalOutput += msg.output
                totalCacheRead += msg.cacheRead
                totalCacheCreate += msg.cacheCreate

                let tokens = msg.input + msg.output + msg.cacheRead + msg.cacheCreate
                modelTokens[msg.model, default: 0] += tokens

                let existing = modelBreakdowns[msg.model] ?? .zero
                modelBreakdowns[msg.model] = existing.merging(
                    ModelTokenBreakdown(
                        inputTokens: msg.input,
                        outputTokens: msg.output,
                        cacheReadTokens: msg.cacheRead,
                        cacheCreationTokens: msg.cacheCreate
                    )
                )
            }

            return SessionUsage(
                inputTokens: totalInput,
                outputTokens: totalOutput,
                cacheReadTokens: totalCacheRead,
                cacheCreationTokens: totalCacheCreate,
                messageCount: messageCount,
                toolCallCount: toolUseIds.count + anonymousToolUseFingerprints.count,
                models: modelTokens,
                modelBreakdowns: modelBreakdowns,
                toolCounts: toolCounts,
                contextTokens: contextTokens
            )
        }
    }

    private struct FileUsageIndexEntry {
        var offset: UInt64
        var carry: Data
        var probeAtOffset: Data
        var fileSize: UInt64
        var modifiedAt: TimeInterval
        var lastAccessAt: TimeInterval
        var accumulator: UsageAccumulator
    }

    /// 解析单个 JSONL 文件的 usage
    /// 基于 path + range + mtime + offset 的增量索引，优先增量解析 append 的新内容
    private func parseJsonlUsage(at path: String, within dateRange: DateInterval? = nil) -> SessionUsage {
        usageIndexLock.lock()
        defer { usageIndexLock.unlock() }

        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let fileSizeNumber = attributes[.size] as? NSNumber else {
            usageIndex[path] = nil
            return .zero
        }

        let fileSize = fileSizeNumber.uint64Value
        let modifiedAt = (attributes[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        let rangeKey = JsonlRangeKey(dateRange: dateRange)
        let nowEpoch = Date().timeIntervalSince1970

        var perFileEntries = usageIndex[path] ?? [:]
        var entry: FileUsageIndexEntry

        if let existing = perFileEntries[rangeKey] {
            if shouldRebuildUsageIndexEntry(existing: existing, at: path, currentFileSize: fileSize) {
                entry = rebuildUsageIndexEntry(
                    at: path,
                    fileSize: fileSize,
                    modifiedAt: modifiedAt,
                    dateRange: dateRange
                )
            } else if fileSize > existing.offset {
                entry = appendUsageIndexEntry(
                    existing: existing,
                    at: path,
                    fileSize: fileSize,
                    modifiedAt: modifiedAt,
                    dateRange: dateRange
                )
            } else {
                entry = existing
                entry.fileSize = fileSize
                entry.modifiedAt = modifiedAt
            }
        } else {
            entry = rebuildUsageIndexEntry(
                at: path,
                fileSize: fileSize,
                modifiedAt: modifiedAt,
                dateRange: dateRange
            )
        }

        entry.lastAccessAt = nowEpoch
        perFileEntries[rangeKey] = entry
        usageIndex[path] = perFileEntries

        let sessionUsage = entry.accumulator.buildSessionUsage()

        // 持久化工具调用去重键到 SQLite
        let dedupKeys = entry.accumulator.dedupKeys()
        if !dedupKeys.isEmpty {
            persistDedupKeys(dedupKeys, file: path)
        }

        // 持久化文件索引到 SQLite（跨重启生效）
        persistProcessedFileIndex(path: path, entry: entry)
        cleanupUsageIndexIfNeeded()

        return sessionUsage
    }

    // MARK: - SQLite Dedup Key Persistence

    private let db: Connection = DatabaseManager.shared.db

    /// 持久化工具调用去重键，使用 INSERT OR IGNORE 实现精确去重
    /// 返回受影响的行数（可用于统计去重命中率）
    private func persistDedupKeys(_ keys: [String], file: String) {
        for key in keys {
            // 提取 tool_name（从 key 前缀后的内容无法直接获取，这里记录空字符串）
            // 实际 tool name 可以从 SessionUsage.toolCounts 中获得
            do {
                _ = try db.run(
                    "INSERT OR IGNORE INTO tool_calls (dedup_key, tool_name, session_id, inserted_at) VALUES (?, ?, ?, ?)",
                    key, "", file, Date().timeIntervalSince1970
                )
            } catch {
                // 忽略插入错误（可能是并发或磁盘问题）
            }
        }
    }

    // MARK: - SQLite Index Persistence

    /// 从 SQLite 加载已处理文件索引到内存
    private func loadIndexFromSQLite() {
        do {
            let rows = try db.prepare("SELECT path, mtime, file_size, offset, message_count, tool_call_count, total_tokens, last_accessed FROM processed_files")
            for row in rows {
                let path: String = row[0] as? String ?? ""
                let mtime: Double = row[1] as? Double ?? 0
                let fileSize: Int64 = row[2] as? Int64 ?? 0
                let offset: Int64 = row[3] as? Int64 ?? 0
                let messageCount: Int64 = row[4] as? Int64 ?? 0
                let _: Int64 = row[5] as? Int64 ?? 0
                let totalTokens: Int64 = row[6] as? Int64 ?? 0
                let lastAccessed: Double = row[7] as? Double ?? 0

                let accumulator = UsageAccumulator(
                    messageCount: Int(messageCount),
                    toolUseIds: [],
                    anonymousToolUseFingerprints: [],
                    toolCounts: [:],
                    contextTokens: totalTokens,
                    messages: [:]
                )

                let key = JsonlRangeKey(dateRange: nil)
                let entry = FileUsageIndexEntry(
                    offset: UInt64(offset),
                    carry: Data(),
                    probeAtOffset: Data(),
                    fileSize: UInt64(fileSize),
                    modifiedAt: mtime,
                    lastAccessAt: lastAccessed,
                    accumulator: accumulator
                )

                if usageIndex[path] == nil {
                    usageIndex[path] = [:]
                }
                usageIndex[path]![key] = entry
            }
        } catch {
            // 忽略加载错误
        }
    }

    /// UPSERT 已处理文件索引到 SQLite
    private func persistProcessedFileIndex(path: String, entry: FileUsageIndexEntry) {
        let sessionUsage = entry.accumulator.buildSessionUsage()
        do {
            _ = try db.run("""
                INSERT INTO processed_files (path, mtime, file_size, offset, message_count, tool_call_count, total_tokens, last_accessed)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(path) DO UPDATE SET
                    mtime = excluded.mtime,
                    file_size = excluded.file_size,
                    offset = excluded.offset,
                    message_count = excluded.message_count,
                    tool_call_count = excluded.tool_call_count,
                    total_tokens = excluded.total_tokens,
                    last_accessed = excluded.last_accessed
                """,
                path, entry.modifiedAt, Int64(entry.fileSize), Int64(entry.offset),
                Int64(entry.accumulator.messageCount),
                Int64(entry.accumulator.toolUseIds.count + entry.accumulator.anonymousToolUseFingerprints.count),
                Int64(sessionUsage.totalTokens),
                entry.lastAccessAt
            )
        } catch {
            // 忽略写入错误
        }
    }

    /// 清理 SQLite 中过旧的索引条目（超过 2000 时按 last_accessed 淘汰）
    private func cleanupSQLiteIndex() {
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
            // 忽略清理错误
        }
    }

    private func rebuildUsageIndexEntry(
        at path: String,
        fileSize: UInt64,
        modifiedAt: TimeInterval,
        dateRange: DateInterval?
    ) -> FileUsageIndexEntry {
        var accumulator = UsageAccumulator()
        var carry = Data()

        if let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
            carry = consumeJsonlChunk(data, dateRange: dateRange, accumulator: &accumulator)
            carry = tryConsumeTrailingAsCompleteJson(carry, dateRange: dateRange, accumulator: &accumulator)
        }

        return FileUsageIndexEntry(
            offset: fileSize,
            carry: carry,
            probeAtOffset: readProbeEnding(at: path, endOffset: fileSize),
            fileSize: fileSize,
            modifiedAt: modifiedAt,
            lastAccessAt: Date().timeIntervalSince1970,
            accumulator: accumulator
        )
    }

    private func appendUsageIndexEntry(
        existing: FileUsageIndexEntry,
        at path: String,
        fileSize: UInt64,
        modifiedAt: TimeInterval,
        dateRange: DateInterval?
    ) -> FileUsageIndexEntry {
        var updated = existing
        guard let handle = try? FileHandle(forReadingFrom: URL(fileURLWithPath: path)) else {
            return rebuildUsageIndexEntry(at: path, fileSize: fileSize, modifiedAt: modifiedAt, dateRange: dateRange)
        }
        defer { try? handle.close() }

        do {
            try handle.seek(toOffset: existing.offset)
            let appended = try handle.readToEnd() ?? Data()
            var merged = existing.carry
            merged.append(appended)

            let trailing = consumeJsonlChunk(merged, dateRange: dateRange, accumulator: &updated.accumulator)
            updated.carry = tryConsumeTrailingAsCompleteJson(trailing, dateRange: dateRange, accumulator: &updated.accumulator)
            updated.offset = fileSize
            updated.fileSize = fileSize
            updated.modifiedAt = modifiedAt
            updated.probeAtOffset = readProbeEnding(at: path, endOffset: fileSize)
            return updated
        } catch {
            return rebuildUsageIndexEntry(at: path, fileSize: fileSize, modifiedAt: modifiedAt, dateRange: dateRange)
        }
    }

    private func shouldRebuildUsageIndexEntry(
        existing: FileUsageIndexEntry,
        at path: String,
        currentFileSize: UInt64
    ) -> Bool {
        if currentFileSize < existing.offset {
            return true
        }
        if existing.offset == 0 {
            return false
        }

        let currentProbe = readProbeEnding(at: path, endOffset: existing.offset)
        return currentProbe != existing.probeAtOffset
    }

    private func cleanupUsageIndexIfNeeded() {
        let totalEntries = usageIndex.values.reduce(0) { $0 + $1.count }
        guard totalEntries > maxIndexedFileRanges else { return }

        var flattened: [(path: String, key: JsonlRangeKey, accessAt: TimeInterval)] = []
        flattened.reserveCapacity(totalEntries)

        for (path, keyed) in usageIndex {
            for (key, entry) in keyed {
                flattened.append((path: path, key: key, accessAt: entry.lastAccessAt))
            }
        }

        flattened.sort { $0.accessAt < $1.accessAt }
        let removeCount = totalEntries - maxIndexedFileRanges

        for item in flattened.prefix(removeCount) {
            usageIndex[item.path]?[item.key] = nil
            if usageIndex[item.path]?.isEmpty == true {
                usageIndex[item.path] = nil
            }
        }

        // 同步清理 SQLite 中的旧索引
        cleanupSQLiteIndex()
    }

    private func readProbeEnding(at path: String, endOffset: UInt64) -> Data {
        guard endOffset > 0,
              let handle = try? FileHandle(forReadingFrom: URL(fileURLWithPath: path)) else {
            return Data()
        }
        defer { try? handle.close() }

        let count = min(indexedTailProbeBytes, endOffset)
        let start = endOffset - count
        do {
            try handle.seek(toOffset: start)
            return try handle.read(upToCount: Int(count)) ?? Data()
        } catch {
            return Data()
        }
    }

    private func consumeJsonlChunk(
        _ data: Data,
        dateRange: DateInterval?,
        accumulator: inout UsageAccumulator
    ) -> Data {
        guard !data.isEmpty else { return Data() }

        var lineStart = data.startIndex
        var idx = data.startIndex
        while idx < data.endIndex {
            if data[idx] == 0x0A {
                var lineData = data[lineStart..<idx]
                if lineData.last == 0x0D {
                    lineData = lineData.dropLast()
                }
                consumeJsonlLine(Data(lineData), dateRange: dateRange, accumulator: &accumulator)
                lineStart = data.index(after: idx)
            }
            idx = data.index(after: idx)
        }

        if lineStart < data.endIndex {
            return Data(data[lineStart..<data.endIndex])
        }
        return Data()
    }

    private func tryConsumeTrailingAsCompleteJson(
        _ trailing: Data,
        dateRange: DateInterval?,
        accumulator: inout UsageAccumulator
    ) -> Data {
        guard !trailing.isEmpty else { return Data() }
        guard (try? JSONSerialization.jsonObject(with: trailing)) != nil else {
            return trailing
        }

        consumeJsonlLine(trailing, dateRange: dateRange, accumulator: &accumulator)
        return Data()
    }

    private func consumeJsonlLine(
        _ lineData: Data,
        dateRange: DateInterval?,
        accumulator: inout UsageAccumulator
    ) {
        guard !lineData.isEmpty,
              let entry = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
            return
        }

        if let dateRange {
            guard let timestamp = parseTimestamp(from: entry), dateRange.contains(timestamp) else {
                return
            }
        }

        let type = entry["type"] as? String ?? ""
        if type == "user", isHumanUserMessage(entry: entry) {
            accumulator.messageCount += 1
        }

        guard type == "assistant",
              let message = entry["message"] as? [String: Any],
              let usage = message["usage"] as? [String: Any] else {
            return
        }

        let input = int64(usage["input_tokens"])
        let output = int64(usage["output_tokens"])
        let cacheRead = int64(usage["cache_read_input_tokens"])
        let cacheCreate = int64(usage["cache_creation_input_tokens"])
        let model = message["model"] as? String ?? "unknown"
        let messageKey = messageDedupKey(entry: entry, message: message)

        if model == "<synthetic>" || messageKey.isEmpty {
            return
        }

        if let existing = accumulator.messages[messageKey] {
            accumulator.messages[messageKey] = IndexedMessageUsage(
                model: existing.model == "unknown" ? model : existing.model,
                input: max(existing.input, input),
                output: max(existing.output, output),
                cacheRead: max(existing.cacheRead, cacheRead),
                cacheCreate: max(existing.cacheCreate, cacheCreate)
            )
        } else {
            accumulator.messages[messageKey] = IndexedMessageUsage(
                model: model,
                input: input,
                output: output,
                cacheRead: cacheRead,
                cacheCreate: cacheCreate
            )
            // 新消息时累加 context tokens
            accumulator.contextTokens += input
        }

        if let content = message["content"] as? [[String: Any]] {
            for block in content where block["type"] as? String == "tool_use" {
                let toolName = block["name"] as? String ?? "unknown"
                if let toolId = block["id"] as? String, !toolId.isEmpty {
                    accumulator.toolUseIds.insert(toolId)
                    accumulator.toolCounts[toolName, default: 0] += 1
                } else {
                    accumulator.anonymousToolUseFingerprints.insert(
                        anonymousToolUseFingerprint(block: block, entry: entry, message: message)
                    )
                    accumulator.toolCounts[toolName, default: 0] += 1
                }
            }
        }
    }

    // MARK: - Helpers

    private func parseTimestamp(from entry: [String: Any]) -> Date? {
        if let date = date(fromRawTimestamp: entry["timestamp"]) {
            return date
        }
        if let message = entry["message"] as? [String: Any],
           let date = date(fromRawTimestamp: message["timestamp"]) {
            return date
        }
        if let snapshot = entry["snapshot"] as? [String: Any],
           let date = date(fromRawTimestamp: snapshot["timestamp"]) {
            return date
        }
        return nil
    }

    private func isHumanUserMessage(entry: [String: Any]) -> Bool {
        guard let message = entry["message"] as? [String: Any] else { return false }
        let content = message["content"]
        if let text = content as? String {
            return isVisibleText(text)
        }
        if let blocks = content as? [Any] {
            for block in blocks {
                if let text = block as? String, isVisibleText(text) {
                    return true
                }
                guard let dict = block as? [String: Any] else { continue }
                let type = dict["type"] as? String

                if type == "tool_result" || type == "thinking" || type == "redacted_thinking" {
                    continue
                }
                if type == "text", let blockText = dict["text"] as? String, isVisibleText(blockText) {
                    return true
                }
                if type == "image" || type == "image_url" || type == "file" || type == "input_text" {
                    return true
                }
                if let blockText = dict["text"] as? String, isVisibleText(blockText) {
                    return true
                }
            }
        }
        return false
    }

    private func messageDedupKey(entry: [String: Any], message: [String: Any]) -> String {
        if let messageId = message["id"] as? String, !messageId.isEmpty {
            if let requestId = entry["requestId"] as? String, !requestId.isEmpty {
                return "\(messageId):\(requestId)"
            }
            return messageId
        }
        if let requestId = entry["requestId"] as? String, !requestId.isEmpty {
            return requestId
        }
        return (entry["uuid"] as? String) ?? ""
    }

    private func anonymousToolUseFingerprint(
        block: [String: Any],
        entry: [String: Any],
        message: [String: Any]
    ) -> String {
        var components: [String] = []
        if let name = block["name"] as? String {
            components.append("name=\(name)")
        }

        if let input = block["input"] {
            if JSONSerialization.isValidJSONObject(input),
               let data = try? JSONSerialization.data(withJSONObject: input, options: [.sortedKeys]),
               let json = String(data: data, encoding: .utf8) {
                components.append("input=\(json)")
            } else {
                components.append("input=\(String(describing: input))")
            }
        }

        components.append("msg=\(messageDedupKey(entry: entry, message: message))")
        return components.joined(separator: "|")
    }

    /// 将 cwd 转换为项目目录名
    /// /Users/username/project/my-app → -Users-username-project-my-app
    private func cwdToProjectDir(_ cwd: String) -> String {
        var result = cwd
        // 去除末尾 /
        while result.hasSuffix("/") { result.removeLast() }
        // 替换 / 为 -
        result = result.replacingOccurrences(of: "/", with: "-")
        // 开头加 -
        if !result.hasPrefix("-") { result = "-" + result }
        return result
    }

    private func availableProjectRoots() -> [String] {
        var roots: [String] = []
        var seen = Set<String>()

        for root in paths.projectRoots {
            let canonical = URL(fileURLWithPath: root).resolvingSymlinksInPath().standardizedFileURL.path
            guard seen.insert(canonical).inserted else { continue }
            var isDir = ObjCBool(false)
            if FileManager.default.fileExists(atPath: canonical, isDirectory: &isDir), isDir.boolValue {
                roots.append(canonical)
            }
        }

        return roots
    }

    func resolveSessionBasePath(cwd: String, sessionId: String) -> String? {
        let projectDir = cwdToProjectDir(cwd)
        let roots = availableProjectRoots()

        for root in roots {
            let basePath = "\(root)/\(projectDir)/\(sessionId)"
            if FileManager.default.fileExists(atPath: "\(basePath).jsonl") {
                return basePath
            }
        }

        for root in roots {
            guard let projectDirs = try? FileManager.default.contentsOfDirectory(atPath: root) else { continue }
            for dir in projectDirs {
                let basePath = "\(root)/\(dir)/\(sessionId)"
                if FileManager.default.fileExists(atPath: "\(basePath).jsonl") {
                    return basePath
                }
            }
        }

        return nil
    }

    private func date(fromRawTimestamp raw: Any?) -> Date? {
        guard let raw else { return nil }
        if let string = raw as? String {
            if let parsed = Self.iso8601WithFractionalSeconds.date(from: string) {
                return parsed
            }
            return Self.iso8601Basic.date(from: string)
        }

        let seconds: TimeInterval?
        if let value = raw as? Int64 {
            seconds = value > 1_000_000_000_000 ? TimeInterval(value) / 1000.0 : TimeInterval(value)
        } else if let value = raw as? Int {
            seconds = value > 1_000_000_000_000 ? TimeInterval(value) / 1000.0 : TimeInterval(value)
        } else if let value = raw as? Double {
            seconds = value > 1_000_000_000_000 ? value / 1000.0 : value
        } else if let value = raw as? NSNumber {
            let doubleValue = value.doubleValue
            seconds = doubleValue > 1_000_000_000_000 ? doubleValue / 1000.0 : doubleValue
        } else {
            seconds = nil
        }

        guard let seconds else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }

    private func isVisibleText(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && !trimmed.hasPrefix("<")
    }

    private func int64(_ value: Any?) -> Int64 {
        guard let v = value else { return 0 }
        if let i = v as? Int { return Int64(i) }
        if let i = v as? Int64 { return i }
        if let d = v as? Double { return Int64(d) }
        return 0
    }
}
