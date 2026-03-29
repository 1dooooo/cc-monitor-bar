import Foundation

struct SessionUsage {
    let inputTokens: Int64
    let outputTokens: Int64
    let cacheReadTokens: Int64
    let cacheCreationTokens: Int64
    let messageCount: Int
    let toolCallCount: Int
    let models: [String: Int64]  // model → total tokens

    var totalTokens: Int64 {
        inputTokens + outputTokens + cacheReadTokens + cacheCreationTokens
    }

    static let zero = SessionUsage(
        inputTokens: 0, outputTokens: 0, cacheReadTokens: 0, cacheCreationTokens: 0,
        messageCount: 0, toolCallCount: 0, models: [:]
    )

    func merging(_ other: SessionUsage) -> SessionUsage {
        var mergedModels = models
        for (model, tokens) in other.models {
            mergedModels[model, default: 0] += tokens
        }
        return SessionUsage(
            inputTokens: inputTokens + other.inputTokens,
            outputTokens: outputTokens + other.outputTokens,
            cacheReadTokens: cacheReadTokens + other.cacheReadTokens,
            cacheCreationTokens: cacheCreationTokens + other.cacheCreationTokens,
            messageCount: messageCount + other.messageCount,
            toolCallCount: toolCallCount + other.toolCallCount,
            models: mergedModels
        )
    }
}
