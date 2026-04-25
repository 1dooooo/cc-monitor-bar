import Foundation

struct Session: Identifiable, Codable {
    let id: String
    let pid: Int32
    let projectPath: String
    let projectId: String
    let startedAt: Date
    var endedAt: Date?
    var durationMs: Int64
    var messageCount: Int
    var toolCallCount: Int
    let entrypoint: String

    // Token usage fields (populated from session_token_usage)
    let inputTokens: Int64
    let outputTokens: Int64
    let cacheReadTokens: Int64
    let cacheCreationTokens: Int64
    let contextTokens: Int64

    var isRunning: Bool {
        endedAt == nil
    }

    var totalTokens: Int64 {
        inputTokens + outputTokens + cacheReadTokens + cacheCreationTokens
    }

    var durationFormatted: String {
        let seconds = Int(durationMs / 1000)
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    /// 活跃会话 — 无 token 数据时使用零值
    init(
        id: String, pid: Int32, projectPath: String, projectId: String,
        startedAt: Date, endedAt: Date?, durationMs: Int64,
        messageCount: Int, toolCallCount: Int, entrypoint: String
    ) {
        self.id = id
        self.pid = pid
        self.projectPath = projectPath
        self.projectId = projectId
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.durationMs = durationMs
        self.messageCount = messageCount
        self.toolCallCount = toolCallCount
        self.entrypoint = entrypoint
        self.inputTokens = 0
        self.outputTokens = 0
        self.cacheReadTokens = 0
        self.cacheCreationTokens = 0
        self.contextTokens = 0
    }

    /// 完整数据 — 含 token用量（Repository 查询、Preview）
    init(
        id: String, pid: Int32, projectPath: String, projectId: String,
        startedAt: Date, endedAt: Date?, durationMs: Int64,
        messageCount: Int, toolCallCount: Int, entrypoint: String,
        inputTokens: Int64, outputTokens: Int64,
        cacheReadTokens: Int64, cacheCreationTokens: Int64,
        contextTokens: Int64
    ) {
        self.id = id
        self.pid = pid
        self.projectPath = projectPath
        self.projectId = projectId
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.durationMs = durationMs
        self.messageCount = messageCount
        self.toolCallCount = toolCallCount
        self.entrypoint = entrypoint
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheReadTokens = cacheReadTokens
        self.cacheCreationTokens = cacheCreationTokens
        self.contextTokens = contextTokens
    }
}
