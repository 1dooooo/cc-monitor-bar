import Foundation

// MARK: - Session Usage Reader

/// 会话用量聚合 + 路径解析
class SessionUsageReader {
    let paths: ClaudeDataPaths
    private let indexManager: SQLiteIndexManager
    private let indexedTailProbeBytes: UInt64 = 512
    private let maxIndexedFileRanges = 2000

    private let usageIndexLock = NSLock()
    private var usageIndex: [String: [JsonlRangeKey: FileUsageIndexEntry]] = [:]

    init(paths: ClaudeDataPaths, indexManager: SQLiteIndexManager) {
        self.paths = paths
        self.indexManager = indexManager
    }

    func invalidateUsageIndex() {
        usageIndexLock.lock()
        usageIndex.removeAll()
        usageIndexLock.unlock()
    }

    // MARK: - Active Sessions

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

    func readSessionUsage(cwd: String, sessionId: String) -> SessionUsage {
        guard let basePath = resolveSessionBasePath(cwd: cwd, sessionId: sessionId) else {
            return SessionUsage.zero
        }

        var result = parseJsonlUsage(at: "\(basePath).jsonl")

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

                guard let files = try? FileManager.default.contentsOfDirectory(atPath: projectPath) else { continue }
                let jsonlFiles = files.filter { $0.hasSuffix(".jsonl") }

                for file in jsonlFiles {
                    let filePath = "\(projectPath)/\(file)"

                    let attrs = try? FileManager.default.attributesOfItem(atPath: filePath)
                    let fileSize = (attrs?[.size] as? Int64 ?? 0)
                    let modDate = (attrs?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0

                    var sessionUsage = indexManager.getCachedFileStats(at: filePath, currentMtime: modDate, currentSize: UInt64(fileSize))
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

        return (messageCount, sessionCount, toolCallCount, totalTokens, inputTokens, outputTokens, cacheTokens, breakdown, toolCounts)
    }

    // MARK: - Today Usage by Project

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

                    let attrs = try? FileManager.default.attributesOfItem(atPath: filePath)
                    let fileSize = (attrs?[.size] as? Int64 ?? 0)
                    let modDate = (attrs?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0

                    var sessionUsage = indexManager.getCachedFileStats(at: filePath, currentMtime: modDate, currentSize: UInt64(fileSize))
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

    // MARK: - JSONL Usage Index

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
            if shouldRebuild(existing: existing, at: path, currentFileSize: fileSize) {
                entry = rebuildEntry(at: path, fileSize: fileSize, modifiedAt: modifiedAt, dateRange: dateRange)
            } else if fileSize > existing.offset {
                entry = appendEntry(existing: existing, at: path, fileSize: fileSize, modifiedAt: modifiedAt, dateRange: dateRange)
            } else {
                entry = existing
                entry.fileSize = fileSize
                entry.modifiedAt = modifiedAt
            }
        } else {
            entry = rebuildEntry(at: path, fileSize: fileSize, modifiedAt: modifiedAt, dateRange: dateRange)
        }

        entry.lastAccessAt = nowEpoch
        perFileEntries[rangeKey] = entry
        usageIndex[path] = perFileEntries

        let sessionUsage = entry.accumulator.buildSessionUsage()

        let dedupKeys = entry.accumulator.dedupKeys()
        if !dedupKeys.isEmpty {
            indexManager.persistDedupKeys(dedupKeys, file: path)
        }

        indexManager.persistProcessedFileIndex(path: path, entry: entry, usage: sessionUsage)
        cleanupUsageIndexIfNeeded()

        return sessionUsage
    }

    private func rebuildEntry(
        at path: String,
        fileSize: UInt64,
        modifiedAt: TimeInterval,
        dateRange: DateInterval?
    ) -> FileUsageIndexEntry {
        var accumulator = UsageAccumulator()
        var carry = Data()

        if let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
            carry = JsonlParser.consumeChunk(data, dateRange: dateRange, accumulator: &accumulator)
            carry = JsonlParser.tryConsumeTrailingAsCompleteJson(carry, dateRange: dateRange, accumulator: &accumulator)
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

    private func appendEntry(
        existing: FileUsageIndexEntry,
        at path: String,
        fileSize: UInt64,
        modifiedAt: TimeInterval,
        dateRange: DateInterval?
    ) -> FileUsageIndexEntry {
        var updated = existing
        guard let handle = try? FileHandle(forReadingFrom: URL(fileURLWithPath: path)) else {
            return rebuildEntry(at: path, fileSize: fileSize, modifiedAt: modifiedAt, dateRange: dateRange)
        }
        defer { try? handle.close() }

        do {
            try handle.seek(toOffset: existing.offset)
            let appended = try handle.readToEnd() ?? Data()
            var merged = existing.carry
            merged.append(appended)

            let trailing = JsonlParser.consumeChunk(merged, dateRange: dateRange, accumulator: &updated.accumulator)
            updated.carry = JsonlParser.tryConsumeTrailingAsCompleteJson(trailing, dateRange: dateRange, accumulator: &updated.accumulator)
            updated.offset = fileSize
            updated.fileSize = fileSize
            updated.modifiedAt = modifiedAt
            updated.probeAtOffset = readProbeEnding(at: path, endOffset: fileSize)
            return updated
        } catch {
            return rebuildEntry(at: path, fileSize: fileSize, modifiedAt: modifiedAt, dateRange: dateRange)
        }
    }

    private func shouldRebuild(
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

        indexManager.cleanupIndex()
    }

    // MARK: - Path Resolution

    /// 将 cwd 转换为项目目录名
    private func cwdToProjectDir(_ cwd: String) -> String {
        var result = cwd
        while result.hasSuffix("/") { result.removeLast() }
        result = result.replacingOccurrences(of: "/", with: "-")
        if !result.hasPrefix("-") { result = "-" + result }
        return result
    }

    /// 将编码后的项目目录名转为可读名称
    func projectDirNameToDisplayName(_ dirName: String) -> String {
        let stripped = dirName.hasPrefix("-") ? String(dirName.dropFirst()) : dirName
        return stripped
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
}
