import Foundation

// MARK: - Data Quality (pure functions)

/// 今日聚合用量（与 ClaudeDataReader.readTodayUsage() 返回类型一致）
typealias UsageTuple = (
    messageCount: Int,
    sessionCount: Int,
    toolCallCount: Int,
    totalTokens: Int64,
    inputTokens: Int64,
    outputTokens: Int64,
    cacheTokens: Int64,
    modelBreakdown: [(name: String, tokens: Int64, inputTokens: Int64, outputTokens: Int64, cacheTokens: Int64)],
    toolCounts: [String: Int]
)

enum DataQualityLevel {
    case healthy
    case warning
    case critical
    case unavailable

    var displayText: String {
        switch self {
        case .healthy: return "正常"
        case .warning: return "偏差"
        case .critical: return "异常"
        case .unavailable: return "未知"
        }
    }
}

enum DataQualityReason: String {
    case normal = "正常"
    case cacheNotYetUpdated = "cache 延迟"
    case jsonlMissingUsage = "JSONL 解析遗漏"
    case dataSourceMismatch = "数据源不一致"
}

struct DataQualityDiffItem {
    let dimension: String
    let jsonlValue: Int64
    let cacheValue: Int64
    let diffRatio: Double
    let reason: DataQualityReason
    let suggestion: String
}

struct DataQualityDiffBreakdown {
    let items: [DataQualityDiffItem]
}

struct DataQualityStatus {
    let level: DataQualityLevel
    let summary: String
    let sourceDate: String?
    let isCacheStale: Bool
    let tokenDiffRatio: Double?
    let messageDiffRatio: Double?
    let sessionDiffRatio: Double?
    let toolDiffRatio: Double?
    let diffBreakdown: DataQualityDiffBreakdown?
}

enum DataQuality {

    static func diffRatio(lhs: Int64, rhs: Int64) -> Double {
        if lhs == rhs { return 0 }
        let baseline = max(max(abs(lhs), abs(rhs)), 1)
        return Double(abs(lhs - rhs)) / Double(baseline)
    }

    static func buildStatus(
        todayUsage: UsageTuple,
        cache: StatsCache,
        todayStr: String
    ) -> DataQualityStatus {
        let todayCacheActivity = cache.dailyActivity.first { $0.date == todayStr }
        let cacheDayTokens = cache.dailyModelTokens.first { $0.date == todayStr }?.tokensByModel.values.reduce(0, +) ?? 0
        let isCacheStale = cache.lastComputedDate < todayStr

        guard let day = todayCacheActivity else {
            let summary = isCacheStale
                ? "stats-cache 尚未更新到今天，已优先使用实时 JSONL"
                : "缺少今日 cache 基线，已使用实时 JSONL"
            return DataQualityStatus(
                level: isCacheStale ? .warning : .unavailable,
                summary: summary,
                sourceDate: cache.lastComputedDate,
                isCacheStale: isCacheStale,
                tokenDiffRatio: nil, messageDiffRatio: nil,
                sessionDiffRatio: nil, toolDiffRatio: nil,
                diffBreakdown: nil
            )
        }

        let cacheTokens = day.totalTokens > 0 ? day.totalTokens : cacheDayTokens
        let tokenDiff = diffRatio(lhs: todayUsage.totalTokens, rhs: cacheTokens)
        let messageDiff = diffRatio(lhs: Int64(todayUsage.messageCount), rhs: Int64(day.messageCount))
        let sessionDiff = diffRatio(lhs: Int64(todayUsage.sessionCount), rhs: Int64(day.sessionCount))
        let toolDiff = diffRatio(lhs: Int64(todayUsage.toolCallCount), rhs: Int64(day.toolCallCount))

        let items = buildDiffBreakdown(
            todayUsage: todayUsage, day: day, cacheTokens: cacheTokens,
            tokenDiff: tokenDiff, messageDiff: messageDiff,
            sessionDiff: sessionDiff, toolDiff: toolDiff, isCacheStale: isCacheStale
        )

        let maxDiff = [tokenDiff, messageDiff, sessionDiff, toolDiff].max() ?? 0
        let level: DataQualityLevel
        let summary: String

        if maxDiff > 0.35 {
            level = .critical
            summary = "实时统计与 cache 偏差较大，建议检查数据源或触发全量重扫"
        } else if maxDiff > 0.15 || isCacheStale {
            level = .warning
            summary = isCacheStale
                ? "实时统计正常，但 cache 存在延迟"
                : "实时统计与 cache 有可见偏差"
        } else {
            level = .healthy
            summary = "实时 JSONL 与 cache 校验一致"
        }

        return DataQualityStatus(
            level: level, summary: summary, sourceDate: day.date,
            isCacheStale: isCacheStale,
            tokenDiffRatio: tokenDiff, messageDiffRatio: messageDiff,
            sessionDiffRatio: sessionDiff, toolDiffRatio: toolDiff,
            diffBreakdown: DataQualityDiffBreakdown(items: items)
        )
    }

    private static func buildDiffBreakdown(
        todayUsage: UsageTuple,
        day: DailyActivity,
        cacheTokens: Int64,
        tokenDiff: Double, messageDiff: Double,
        sessionDiff: Double, toolDiff: Double,
        isCacheStale: Bool
    ) -> [DataQualityDiffItem] {
        func reason(for diff: Double) -> DataQualityReason {
            if diff <= 0.15 { return .normal }
            if isCacheStale { return .cacheNotYetUpdated }
            if todayUsage.totalTokens > 0 && cacheTokens == 0 { return .jsonlMissingUsage }
            return .dataSourceMismatch
        }
        func suggestion(for diff: Double, _ reason: DataQualityReason) -> String {
            if diff <= 0.15 { return "数据一致，无需操作" }
            switch reason {
            case .cacheNotYetUpdated: return "等待 stats-cache 下次刷新（通常间隔 5-15 分钟）"
            case .jsonlMissingUsage: return "检查 JSONL 文件是否包含 assistant usage 记录"
            case .dataSourceMismatch: return "触发全量重扫以同步数据源"
            case .normal: return ""
            }
        }

        return [
            DataQualityDiffItem(dimension: "Token", jsonlValue: todayUsage.totalTokens, cacheValue: cacheTokens, diffRatio: tokenDiff, reason: reason(for: tokenDiff), suggestion: suggestion(for: tokenDiff, reason(for: tokenDiff))),
            DataQualityDiffItem(dimension: "Message", jsonlValue: Int64(todayUsage.messageCount), cacheValue: Int64(day.messageCount), diffRatio: messageDiff, reason: reason(for: messageDiff), suggestion: suggestion(for: messageDiff, reason(for: messageDiff))),
            DataQualityDiffItem(dimension: "Session", jsonlValue: Int64(todayUsage.sessionCount), cacheValue: Int64(day.sessionCount), diffRatio: sessionDiff, reason: reason(for: sessionDiff), suggestion: suggestion(for: sessionDiff, reason(for: sessionDiff))),
            DataQualityDiffItem(dimension: "Tool", jsonlValue: Int64(todayUsage.toolCallCount), cacheValue: Int64(day.toolCallCount), diffRatio: toolDiff, reason: reason(for: toolDiff), suggestion: suggestion(for: toolDiff, reason(for: toolDiff))),
        ]
    }
}
