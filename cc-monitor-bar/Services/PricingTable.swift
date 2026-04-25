import Foundation

/// 费用估算 — 基于 Token 用量和模型定价表
struct PricingTable {
    /// 模型定价 (USD per 1M tokens)
    struct ModelPricing {
        let inputPrice: Double    // 每百万 input tokens 的价格
        let outputPrice: Double   // 每百万 output tokens 的价格
        let cachePrice: Double    // 每百万 cache tokens 的价格
    }

    // MARK: - Pricing Data (2025-04 Anthropic 定价)

    static let models: [String: ModelPricing] = [
        "claude-opus-4": ModelPricing(inputPrice: 75.0, outputPrice: 375.0, cachePrice: 7.5),
        "claude-sonnet-4": ModelPricing(inputPrice: 3.0, outputPrice: 15.0, cachePrice: 0.3),
        "claude-3-5-sonnet": ModelPricing(inputPrice: 3.0, outputPrice: 15.0, cachePrice: 0.3),
        "claude-3-haiku": ModelPricing(inputPrice: 0.25, outputPrice: 1.25, cachePrice: 0.03),
        "claude-3.5-haiku": ModelPricing(inputPrice: 0.8, outputPrice: 4.0, cachePrice: 0.08),
    ]

    /// 计算指定模型的费用
    static func estimateCost(inputTokens: Int64, outputTokens: Int64, cacheTokens: Int64, model: String) -> Double {
        let pricing = models.first { key, _ in model.hasPrefix(key) }?.value ?? defaultPricing(for: model)
        let inputCost = Double(inputTokens) / 1_000_000.0 * pricing.inputPrice
        let outputCost = Double(outputTokens) / 1_000_000.0 * pricing.outputPrice
        let cacheCost = Double(cacheTokens) / 1_000_000.0 * pricing.cachePrice
        return inputCost + outputCost + cacheCost
    }

    /// 获取所有模型的默认定价
    static func defaultPricing(for model: String) -> ModelPricing {
        if model.contains("opus") {
            return ModelPricing(inputPrice: 75.0, outputPrice: 375.0, cachePrice: 7.5)
        } else if model.contains("haiku") {
            return ModelPricing(inputPrice: 0.25, outputPrice: 1.25, cachePrice: 0.03)
        } else {
            return ModelPricing(inputPrice: 3.0, outputPrice: 15.0, cachePrice: 0.3)
        }
    }

    /// 批量计算费用
    static func estimateTotalCost(breakdown: [(name: String, tokens: Int64, inputTokens: Int64, outputTokens: Int64, cacheTokens: Int64)]) -> Double {
        breakdown.reduce(0) { total, item in
            total + estimateCost(
                inputTokens: item.inputTokens,
                outputTokens: item.outputTokens,
                cacheTokens: item.cacheTokens,
                model: item.name
            )
        }
    }
}
