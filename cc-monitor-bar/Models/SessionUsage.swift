import Foundation

struct ModelTokenBreakdown {
    let inputTokens: Int64
    let outputTokens: Int64
    let cacheReadTokens: Int64
    let cacheCreationTokens: Int64

    var totalTokens: Int64 {
        inputTokens + outputTokens + cacheReadTokens + cacheCreationTokens
    }

    static let zero = ModelTokenBreakdown(
        inputTokens: 0,
        outputTokens: 0,
        cacheReadTokens: 0,
        cacheCreationTokens: 0
    )

    func merging(_ other: ModelTokenBreakdown) -> ModelTokenBreakdown {
        ModelTokenBreakdown(
            inputTokens: inputTokens + other.inputTokens,
            outputTokens: outputTokens + other.outputTokens,
            cacheReadTokens: cacheReadTokens + other.cacheReadTokens,
            cacheCreationTokens: cacheCreationTokens + other.cacheCreationTokens
        )
    }
}

struct SessionUsage {
    let inputTokens: Int64
    let outputTokens: Int64
    let cacheReadTokens: Int64
    let cacheCreationTokens: Int64
    let messageCount: Int
    let toolCallCount: Int
    let models: [String: Int64]  // model → total tokens
    let modelBreakdowns: [String: ModelTokenBreakdown]  // model → breakdown
    let toolCounts: [String: Int]  // tool name → call count

    var totalTokens: Int64 {
        inputTokens + outputTokens + cacheReadTokens + cacheCreationTokens
    }

    init(
        inputTokens: Int64,
        outputTokens: Int64,
        cacheReadTokens: Int64,
        cacheCreationTokens: Int64,
        messageCount: Int,
        toolCallCount: Int,
        models: [String: Int64],
        modelBreakdowns: [String: ModelTokenBreakdown] = [:],
        toolCounts: [String: Int] = [:]
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheReadTokens = cacheReadTokens
        self.cacheCreationTokens = cacheCreationTokens
        self.messageCount = messageCount
        self.toolCallCount = toolCallCount
        self.models = models
        self.modelBreakdowns = modelBreakdowns
        self.toolCounts = toolCounts
    }

    static let zero = SessionUsage(
        inputTokens: 0, outputTokens: 0, cacheReadTokens: 0, cacheCreationTokens: 0,
        messageCount: 0, toolCallCount: 0, models: [:], modelBreakdowns: [:], toolCounts: [:]
    )

    func merging(_ other: SessionUsage) -> SessionUsage {
        var mergedModels = models
        for (model, tokens) in other.models {
            mergedModels[model, default: 0] += tokens
        }

        var mergedModelBreakdowns = modelBreakdowns
        for (model, breakdown) in other.modelBreakdowns {
            let existing = mergedModelBreakdowns[model] ?? .zero
            mergedModelBreakdowns[model] = existing.merging(breakdown)
        }

        var mergedToolCounts = toolCounts
        for (tool, count) in other.toolCounts {
            mergedToolCounts[tool, default: 0] += count
        }

        return SessionUsage(
            inputTokens: inputTokens + other.inputTokens,
            outputTokens: outputTokens + other.outputTokens,
            cacheReadTokens: cacheReadTokens + other.cacheReadTokens,
            cacheCreationTokens: cacheCreationTokens + other.cacheCreationTokens,
            messageCount: messageCount + other.messageCount,
            toolCallCount: toolCallCount + other.toolCallCount,
            models: mergedModels,
            modelBreakdowns: mergedModelBreakdowns,
            toolCounts: mergedToolCounts
        )
    }
}
