import Foundation

// MARK: - Stats Cache

struct StatsCache: Codable {
    let version: Int
    let lastComputedDate: String
    let dailyActivity: [DailyActivity]
    let dailyModelTokens: [DailyModelTokens]
    let modelUsage: [String: ModelUsage]
}

struct DailyActivity: Codable {
    let date: String
    let messageCount: Int
    let sessionCount: Int
    let toolCallCount: Int
    let inputTokens: Int64
    let outputTokens: Int64
    let cacheTokens: Int64

    var totalTokens: Int64 {
        inputTokens + outputTokens + cacheTokens
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
