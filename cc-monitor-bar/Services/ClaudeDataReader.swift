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
    /// 只统计 stop_reason != null 的 assistant 消息（最终汇总），跳过流式片段
    func readSessionUsage(cwd: String, sessionId: String) -> SessionUsage {
        let projectDir = cwdToProjectDir(cwd)
        let basePath = "\(paths.projectsDir)/\(projectDir)/\(sessionId)"

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

    // MARK: - JSONL Parsing

    /// 解析单个 JSONL 文件的 usage，只累加 stop_reason != null 的 assistant 消息
    private func parseJsonlUsage(at path: String) -> SessionUsage {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let text = String(data: data, encoding: .utf8) else {
            return SessionUsage.zero
        }

        var inputTokens: Int64 = 0
        var outputTokens: Int64 = 0
        var cacheReadTokens: Int64 = 0
        var cacheCreationTokens: Int64 = 0
        var messageCount = 0
        var toolCallCount = 0
        var models: [String: Int64] = [:]

        let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
        for line in lines {
            guard let lineData = line.data(using: .utf8),
                  let entry = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else { continue }

            let type = entry["type"] as? String ?? ""

            if type == "user" {
                messageCount += 1
            }

            // 只统计最终汇总消息（stop_reason != null），跳过流式片段
            guard type == "assistant",
                  let message = entry["message"] as? [String: Any],
                  message["stop_reason"] != nil,
                  let usage = message["usage"] as? [String: Any] else { continue }

            let inp = int64(usage["input_tokens"])
            let out = int64(usage["output_tokens"])
            let cacheRead = int64(usage["cache_read_input_tokens"])
            let cacheCreation = int64(usage["cache_creation_input_tokens"])

            inputTokens += inp
            outputTokens += out
            cacheReadTokens += cacheRead
            cacheCreationTokens += cacheCreation

            if let model = message["model"] as? String, (inp + out + cacheRead + cacheCreation) > 0 {
                models[model, default: 0] += inp + out + cacheRead + cacheCreation
            }

            // 统计 tool_use
            if let content = message["content"] as? [[String: Any]] {
                for block in content {
                    if block["type"] as? String == "tool_use" {
                        toolCallCount += 1
                    }
                }
            }
        }

        return SessionUsage(
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cacheReadTokens: cacheReadTokens,
            cacheCreationTokens: cacheCreationTokens,
            messageCount: messageCount,
            toolCallCount: toolCallCount,
            models: models
        )
    }

    // MARK: - Helpers

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

    private func int64(_ value: Any?) -> Int64 {
        guard let v = value else { return 0 }
        if let i = v as? Int { return Int64(i) }
        if let i = v as? Int64 { return i }
        if let d = v as? Double { return Int64(d) }
        return 0
    }
}


