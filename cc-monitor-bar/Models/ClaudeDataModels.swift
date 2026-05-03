import Foundation

// MARK: - Stats Cache

struct StatsCache: Codable {
    let version: Int
    let lastComputedDate: String
    let dailyActivity: [DailyActivity]
    let dailyModelTokens: [DailyModelTokens]
    let modelUsage: [String: ModelUsage]
}

/// 每日模型拆分（持久化到 stats-cache.json 时的 Codable 结构）
struct DailyActivityModelEntry: Codable {
    let name: String
    let tokens: Int64
    let inputTokens: Int64
    let outputTokens: Int64
    let cacheTokens: Int64
}

struct DailyActivity: Codable {
    let date: String
    let messageCount: Int
    let sessionCount: Int
    let toolCallCount: Int
    let inputTokens: Int64?
    let outputTokens: Int64?
    let cacheTokens: Int64?
    let modelBreakdown: [DailyActivityModelEntry]?

    var totalTokens: Int64 {
        (inputTokens ?? 0) + (outputTokens ?? 0) + (cacheTokens ?? 0)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try container.decode(String.self, forKey: .date)
        messageCount = try container.decodeIfPresent(Int.self, forKey: .messageCount) ?? 0
        sessionCount = try container.decodeIfPresent(Int.self, forKey: .sessionCount) ?? 0
        toolCallCount = try container.decodeIfPresent(Int.self, forKey: .toolCallCount) ?? 0
        inputTokens = try container.decodeIfPresent(Int64.self, forKey: .inputTokens)
        outputTokens = try container.decodeIfPresent(Int64.self, forKey: .outputTokens)
        cacheTokens = try container.decodeIfPresent(Int64.self, forKey: .cacheTokens)
        modelBreakdown = try container.decodeIfPresent([DailyActivityModelEntry].self, forKey: .modelBreakdown)
    }

    init(date: String, messageCount: Int, sessionCount: Int, toolCallCount: Int, inputTokens: Int64?, outputTokens: Int64?, cacheTokens: Int64?, modelBreakdown: [DailyActivityModelEntry]? = nil) {
        self.date = date
        self.messageCount = messageCount
        self.sessionCount = sessionCount
        self.toolCallCount = toolCallCount
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheTokens = cacheTokens
        self.modelBreakdown = modelBreakdown
    }
}

struct DailyModelTokens: Codable {
    let date: String
    let tokensByModel: [String: Int64]
}

/// 模型用量详情（输入/输出/缓存）
struct ModelUsageDetail: Codable {
    let inputTokens: Int64
    let outputTokens: Int64
    let cacheTokens: Int64

    var totalTokens: Int64 {
        inputTokens + outputTokens + cacheTokens
    }
}

struct ModelUsage: Codable {
    let inputTokens: Int64
    let outputTokens: Int64
    let cacheReadInputTokens: Int64
    let cacheCreationInputTokens: Int64
    let webSearchRequests: Int
    let costUSD: Double
    let contextWindow: Int
    let maxOutputTokens: Int

    enum CodingKeys: String, CodingKey {
        case inputTokens, outputTokens, cacheReadInputTokens, cacheCreationInputTokens
        case webSearchRequests, costUSD, contextWindow, maxOutputTokens
    }
}

// MARK: - Session Info

struct ActiveSessionInfo: Codable {
    let pid: Int32
    let sessionId: String
    let cwd: String
    let startedAt: Int64
    let kind: String
    let entrypoint: String
}

// MARK: - History

struct HistoryEntry: Codable {
    let display: String?
    let timestamp: Int64
    let project: String?
    let sessionId: String?
}

// MARK: - Backup Data

struct ProjectBackupData {
    let path: String
    let lastModelUsage: [String: ModelUsage]
    let lastTotalInputTokens: Int64
    let lastTotalOutputTokens: Int64
    let lastTotalCacheReadInputTokens: Int64
    let lastTotalCacheCreationInputTokens: Int64

    var totalTokens: Int64 {
        lastTotalInputTokens + lastTotalOutputTokens + lastTotalCacheReadInputTokens + lastTotalCacheCreationInputTokens
    }
}
