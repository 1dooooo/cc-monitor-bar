import Foundation

struct ProjectSummary {
    let name: String
    let messageCount: Int
    let sessionCount: Int
    let toolCallCount: Int
    let totalTokens: Int64
    let inputTokens: Int64
    let outputTokens: Int64
    let cacheTokens: Int64
    let toolCounts: [String: Int]
}
