import Foundation
import SwiftUI
import Combine

/// 全局聚合统计
struct TodayStats {
    let messageCount: Int
    let sessionCount: Int
    let toolCallCount: Int
    let totalTokens: Int64
    let inputTokens: Int64
    let outputTokens: Int64
    let cacheTokens: Int64
    let modelBreakdown: [(name: String, tokens: Int64, inputTokens: Int64, outputTokens: Int64, cacheTokens: Int64)]
    let toolCounts: [String: Int]
}

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

/// 数据质量校验原因分类
enum DataQualityReason: String {
    case normal = "正常"
    case cacheNotYetUpdated = "cache 延迟"
    case jsonlMissingUsage = "JSONL 解析遗漏"
    case dataSourceMismatch = "数据源不一致"
}

/// 单个维度的差异对比详情
struct DataQualityDiffItem {
    let dimension: String  // "Token" / "Message" / "Session" / "Tool"
    let jsonlValue: Int64
    let cacheValue: Int64
    let diffRatio: Double
    let reason: DataQualityReason
    let suggestion: String
}

/// diffBreakdown 聚合，四个维度各一条
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

class AppState: ObservableObject {
    static let shared = AppState()

    // MARK: - Published Data

    @Published var currentSessions: [Session] = []
    @Published var sessionUsages: [String: SessionUsage] = [:]
    @Published var historySessions: [Session] = []
    @Published var todayStats: TodayStats?
    @Published var dataQualityStatus: DataQualityStatus?
    @Published var weeklyData: [DailyActivity] = []
    @Published var projectSummaries: [ProjectSummary] = []

    // MARK: - Burn Rate

    private let burnRateTracker = BurnRateTracker()
    @Published var burnRate: Double = 0
    @Published var burnRateLevel: BurnRateTracker.RateLevel = .idle
    @Published var isBurnRateActive: Bool = false

    // MARK: - Dependencies

    let preferences = AppPreferences.shared
    private let reader = ClaudeDataReader()
    private let resolver = ProjectResolver()
    private var pollingTimers: [PollingDataType: Timer] = [:]
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Per-Type Polling State

    /// 不同数据源的轮询频率（秒）
    enum PollingDataType: String, CaseIterable {
        case sessions    // 活跃会话 + 用量：10s
        case todayStats  // 今日统计：30s
        case history     // 历史会话：60s
        case weeklyData  // 周数据：60s

        var defaultInterval: TimeInterval {
            switch self {
            case .sessions: return 10
            case .todayStats: return 30
            case .history: return 60
            case .weeklyData: return 60
            }
        }
    }

    private struct PollingState {
        var elapsed: TimeInterval = 0
        var interval: TimeInterval
        var backoffMultiplier: Int = 1  // 指数退避乘数

        mutating func onBackoffReset() {
            backoffMultiplier = 1
        }

        mutating func onBackoffIncrease() {
            backoffMultiplier = min(backoffMultiplier * 2, 60)
        }

        var effectiveInterval: TimeInterval {
            min(interval * Double(backoffMultiplier), 60)
        }
    }

    private var pollingStates: [PollingDataType: PollingState] = [:]

    // MARK: - Init

    init() {
        preferences.load()
        startPolling()
    }

    deinit {
        for timer in pollingTimers.values {
            timer.invalidate()
        }
    }

    // MARK: - Multi-Frequency Polling

    private func startPolling() {
        // 初始化各数据类型的轮询状态
        for type in PollingDataType.allCases {
            pollingStates[type] = PollingState(interval: type.defaultInterval)
        }

        // 立即执行全量加载
        refreshData()

        // 创建定时器：每 5 秒 tick 一次，按各自间隔调度
        let timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.tickPolling()
        }
        pollingTimers[.sessions] = timer  // 只需一个 tick 定时器

        // 监听刷新间隔变更，重建定时器（兼容旧偏好设置）
        preferences.$refreshInterval
            .dropFirst()
            .sink { [weak self] _ in
                self?.refreshData()  // 偏好变更时触发全量刷新
            }
            .store(in: &cancellables)
    }

    private func tickPolling() {
        for type in PollingDataType.allCases {
            guard var state = pollingStates[type] else { continue }
            state.elapsed += 5

            if state.elapsed >= state.effectiveInterval {
                state.elapsed = 0
                loadDataType(type)
            }

            pollingStates[type] = state
        }
    }

    private func loadDataType(_ type: PollingDataType) {
        switch type {
        case .sessions: loadSessions()
        case .todayStats: loadTodayStats()
        case .history: loadHistory()
        case .weeklyData: loadWeeklyData()
        }
    }

    private func loadSessions() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            do {
                let sessionInfos = try self.reader.readActiveSessions()
                var active: [Session] = []
                var usages: [String: SessionUsage] = [:]
                for info in sessionInfos {
                    let projectId = self.resolver.resolveProjectId(from: info.cwd)
                    let usage = self.reader.readSessionUsage(cwd: info.cwd, sessionId: info.sessionId)
                    usages[info.sessionId] = usage
                    active.append(Session(
                        id: info.sessionId, pid: info.pid, projectPath: info.cwd,
                        projectId: projectId,
                        startedAt: Date(timeIntervalSince1970: Double(info.startedAt) / 1000.0),
                        endedAt: nil,
                        durationMs: Int64(Date().timeIntervalSince1970 * 1000) - info.startedAt,
                        messageCount: usage.messageCount,
                        toolCallCount: usage.toolCallCount,
                        entrypoint: info.entrypoint
                    ))
                }
                // 持久化到 SQLite
                let tuples = active.map { ($0.id, $0.pid, $0.projectPath, $0.projectId, $0.startedAt, $0.messageCount, $0.toolCallCount, $0.entrypoint) }
                self.reader.persistSessions(tuples, usages: usages)
                DispatchQueue.main.async {
                    self.currentSessions = active
                    self.sessionUsages = usages
                }
                self.pollingStates[.sessions]?.onBackoffReset()
            } catch {
                print("读取活跃会话失败: \(error)")
                self.pollingStates[.sessions]?.onBackoffIncrease()
            }
        }
    }

    private func loadHistory() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            do {
                let historyEntries = try self.reader.readHistory(limit: 200)
                var history: [Session] = []
                var seenIds = Set<String>()
                for entry in historyEntries.reversed() {
                    guard let sid = entry.sessionId,
                          let project = entry.project,
                          !seenIds.contains(sid) else { continue }
                    seenIds.insert(sid)
                    let projectId = self.resolver.resolveProjectId(from: project)
                    history.append(Session(
                        id: sid, pid: 0, projectPath: project, projectId: projectId,
                        startedAt: Date(timeIntervalSince1970: Double(entry.timestamp) / 1000.0),
                        endedAt: Date(timeIntervalSince1970: Double(entry.timestamp) / 1000.0 + 3600),
                        durationMs: 3600000,
                        messageCount: 0, toolCallCount: 0, entrypoint: "cli"
                    ))
                }
                DispatchQueue.main.async { self.historySessions = history }
                self.pollingStates[.history]?.onBackoffReset()
            } catch {
                print("读取历史失败: \(error)")
                self.pollingStates[.history]?.onBackoffIncrease()
            }
        }
    }

    private func loadTodayStats() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            do {
                let todayUsage = self.reader.readTodayUsage()
                var messageCount = todayUsage.messageCount
                var sessionCount = todayUsage.sessionCount
                var toolCallCount = todayUsage.toolCallCount
                var totalTokens = todayUsage.totalTokens
                var totalInputTokens = todayUsage.inputTokens
                var totalOutputTokens = todayUsage.outputTokens
                var totalCacheTokens = todayUsage.cacheTokens
                var breakdown = todayUsage.modelBreakdown
                let toolCounts = todayUsage.toolCounts
                var qualityStatus: DataQualityStatus?

                let cache = try self.reader.readStatsCache()
                let todayStr = Self.todayDateString()
                let todayActivity = cache.dailyActivity.first { $0.date == todayStr }
                let latestDay = cache.dailyActivity.last
                let modelRatios = Self.modelRatios(from: cache.modelUsage)

                qualityStatus = Self.buildDataQualityStatus(
                    todayUsage: todayUsage, cache: cache, todayStr: todayStr
                )

                let cacheDayForCounts = todayActivity ?? latestDay
                if let day = cacheDayForCounts {
                    messageCount = max(messageCount, day.messageCount)
                    sessionCount = max(sessionCount, day.sessionCount)
                    toolCallCount = max(toolCallCount, day.toolCallCount)
                }

                if totalTokens == 0,
                   let dayTokens = cache.dailyModelTokens.first(where: { $0.date == todayStr }) {
                    for (model, tokens) in dayTokens.tokensByModel {
                        if let ratio = modelRatios[model] {
                            let inp = Int64(Double(tokens) * ratio.input)
                            let out = Int64(Double(tokens) * ratio.output)
                            let cacheVal = Int64(Double(tokens) * ratio.cache)
                            totalTokens += tokens
                            totalInputTokens += inp
                            totalOutputTokens += out
                            totalCacheTokens += cacheVal
                            breakdown.append((name: model, tokens: tokens, inputTokens: inp, outputTokens: out, cacheTokens: cacheVal))
                        } else {
                            totalTokens += tokens
                            totalInputTokens += tokens
                            breakdown.append((name: model, tokens: tokens, inputTokens: tokens, outputTokens: 0, cacheTokens: 0))
                        }
                    }
                }

                breakdown.sort { $0.tokens > $1.tokens }
                let stats = TodayStats(
                    messageCount: messageCount, sessionCount: sessionCount,
                    toolCallCount: toolCallCount, totalTokens: totalTokens,
                    inputTokens: totalInputTokens, outputTokens: totalOutputTokens,
                    cacheTokens: totalCacheTokens, modelBreakdown: breakdown,
                    toolCounts: toolCounts
                )

                // 持久化
                self.reader.persistDailyStats(
                    date: todayStr, projectId: "_global",
                    messageCount: messageCount, sessionCount: sessionCount,
                    toolCallCount: toolCallCount, totalTokens: totalTokens,
                    inputTokens: totalInputTokens, outputTokens: totalOutputTokens,
                    cacheTokens: totalCacheTokens, modelBreakdown: breakdown
                )

                // 项目级聚合 + 持久化
                let projectSummaries = self.reader.readTodayUsageByProject()
                for project in projectSummaries {
                    self.reader.persistDailyStats(
                        date: todayStr, projectId: project.name,
                        messageCount: project.messageCount, sessionCount: project.sessionCount,
                        toolCallCount: project.toolCallCount, totalTokens: project.totalTokens,
                        inputTokens: project.inputTokens, outputTokens: project.outputTokens,
                        cacheTokens: project.cacheTokens, modelBreakdown: []
                    )
                }

                self.burnRateTracker.update(totalTokens: totalTokens)

                DispatchQueue.main.async {
                    self.todayStats = stats
                    self.dataQualityStatus = qualityStatus
                    self.projectSummaries = projectSummaries
                    self.burnRate = self.burnRateTracker.currentRate
                    self.burnRateLevel = self.burnRateTracker.rateLevel
                    self.isBurnRateActive = self.burnRateTracker.isActive
                }
                self.pollingStates[.todayStats]?.onBackoffReset()
            } catch {
                print("读取今日统计失败: \(error)")
                self.pollingStates[.todayStats]?.onBackoffIncrease()
            }
        }
    }

    private func loadWeeklyData() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            do {
                let cache = try self.reader.readStatsCache()
                let modelRatios = Self.modelRatios(from: cache.modelUsage)
                let weeklyData = Self.last7Days(
                    from: cache.dailyActivity,
                    dailyModelTokens: cache.dailyModelTokens,
                    modelRatios: modelRatios
                )
                DispatchQueue.main.async { self.weeklyData = weeklyData }
                self.pollingStates[.weeklyData]?.onBackoffReset()
            } catch {
                print("读取周数据失败: \(error)")
                self.pollingStates[.weeklyData]?.onBackoffIncrease()
            }
        }
    }

    /// 手动全量刷新（覆盖正常间隔立即加载）
    func refreshData() {
        for type in PollingDataType.allCases {
            pollingStates[type]?.elapsed = pollingStates[type]?.effectiveInterval ?? type.defaultInterval
            loadDataType(type)
        }
    }

    // MARK: - Weekly Data Helper

    private static func modelRatios(from modelUsage: [String: ModelUsage]) -> [String: (input: Double, output: Double, cache: Double)] {
        var modelRatios: [String: (input: Double, output: Double, cache: Double)] = [:]
        for (model, usage) in modelUsage {
            let input = Double(usage.inputTokens)
            let output = Double(usage.outputTokens)
            let cache = Double(usage.cacheReadInputTokens + usage.cacheCreationInputTokens)
            let total = input + output + cache
            guard total > 0 else { continue }
            modelRatios[model] = (
                input: input / total,
                output: output / total,
                cache: cache / total
            )
        }
        return modelRatios
    }

    static func buildDataQualityStatus(
        todayUsage: (
            messageCount: Int,
            sessionCount: Int,
            toolCallCount: Int,
            totalTokens: Int64,
            inputTokens: Int64,
            outputTokens: Int64,
            cacheTokens: Int64,
            modelBreakdown: [(name: String, tokens: Int64, inputTokens: Int64, outputTokens: Int64, cacheTokens: Int64)],
            toolCounts: [String: Int]
        ),
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
                tokenDiffRatio: nil,
                messageDiffRatio: nil,
                sessionDiffRatio: nil,
                toolDiffRatio: nil,
                diffBreakdown: nil
            )
        }

        let cacheTokens = day.totalTokens > 0 ? day.totalTokens : cacheDayTokens

        let tokenDiff = diffRatio(lhs: todayUsage.totalTokens, rhs: cacheTokens)
        let messageDiff = diffRatio(lhs: Int64(todayUsage.messageCount), rhs: Int64(day.messageCount))
        let sessionDiff = diffRatio(lhs: Int64(todayUsage.sessionCount), rhs: Int64(day.sessionCount))
        let toolDiff = diffRatio(lhs: Int64(todayUsage.toolCallCount), rhs: Int64(day.toolCallCount))

        // 构建 diffBreakdown — 每个维度提供详细对比
        let items = buildDiffBreakdown(
            todayUsage: todayUsage,
            day: day,
            cacheTokens: cacheTokens,
            tokenDiff: tokenDiff,
            messageDiff: messageDiff,
            sessionDiff: sessionDiff,
            toolDiff: toolDiff,
            isCacheStale: isCacheStale
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
            level: level,
            summary: summary,
            sourceDate: day.date,
            isCacheStale: isCacheStale,
            tokenDiffRatio: tokenDiff,
            messageDiffRatio: messageDiff,
            sessionDiffRatio: sessionDiff,
            toolDiffRatio: toolDiff,
            diffBreakdown: DataQualityDiffBreakdown(items: items)
        )
    }

    private static func buildDiffBreakdown(
        todayUsage: (
            messageCount: Int, sessionCount: Int, toolCallCount: Int,
            totalTokens: Int64, inputTokens: Int64, outputTokens: Int64,
            cacheTokens: Int64, modelBreakdown: [(name: String, tokens: Int64, inputTokens: Int64, outputTokens: Int64, cacheTokens: Int64)],
            toolCounts: [String: Int]
        ),
        day: DailyActivity,
        cacheTokens: Int64,
        tokenDiff: Double,
        messageDiff: Double,
        sessionDiff: Double,
        toolDiff: Double,
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
            DataQualityDiffItem(
                dimension: "Token",
                jsonlValue: todayUsage.totalTokens,
                cacheValue: cacheTokens,
                diffRatio: tokenDiff,
                reason: reason(for: tokenDiff),
                suggestion: suggestion(for: tokenDiff, reason(for: tokenDiff))
            ),
            DataQualityDiffItem(
                dimension: "Message",
                jsonlValue: Int64(todayUsage.messageCount),
                cacheValue: Int64(day.messageCount),
                diffRatio: messageDiff,
                reason: reason(for: messageDiff),
                suggestion: suggestion(for: messageDiff, reason(for: messageDiff))
            ),
            DataQualityDiffItem(
                dimension: "Session",
                jsonlValue: Int64(todayUsage.sessionCount),
                cacheValue: Int64(day.sessionCount),
                diffRatio: sessionDiff,
                reason: reason(for: sessionDiff),
                suggestion: suggestion(for: sessionDiff, reason(for: sessionDiff))
            ),
            DataQualityDiffItem(
                dimension: "Tool",
                jsonlValue: Int64(todayUsage.toolCallCount),
                cacheValue: Int64(day.toolCallCount),
                diffRatio: toolDiff,
                reason: reason(for: toolDiff),
                suggestion: suggestion(for: toolDiff, reason(for: toolDiff))
            ),
        ]
    }

    static func diffRatio(lhs: Int64, rhs: Int64) -> Double {
        if lhs == rhs {
            return 0
        }
        let baseline = max(max(abs(lhs), abs(rhs)), 1)
        return Double(abs(lhs - rhs)) / Double(baseline)
    }

    /// 从 dailyActivity 和 dailyModelTokens 中提取最近 7 天的数据
    private static func last7Days(from dailyActivity: [DailyActivity], dailyModelTokens: [DailyModelTokens], modelRatios: [String: (input: Double, output: Double, cache: Double)]) -> [DailyActivity] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var activityMap: [String: DailyActivity] = [:]
        for activity in dailyActivity {
            activityMap[activity.date] = activity
        }

        var tokensMap: [String: Int64] = [:]
        for day in dailyModelTokens {
            let total = day.tokensByModel.values.reduce(0, +)
            tokensMap[day.date] = total
        }

        var result: [DailyActivity] = []
        for offset in (0..<7).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let dateStr = dateFormatter.string(from: date)

            if let existing = activityMap[dateStr] {
                var inp: Int64 = 0, out: Int64 = 0, cache: Int64 = 0

                if let dayTokens = dailyModelTokens.first(where: { $0.date == dateStr }) {
                    for (model, tokens) in dayTokens.tokensByModel {
                        if let ratio = modelRatios[model] {
                            inp += Int64(Double(tokens) * ratio.input)
                            out += Int64(Double(tokens) * ratio.output)
                            cache += Int64(Double(tokens) * ratio.cache)
                        } else {
                            inp += tokens
                        }
                    }
                }

                let updated = DailyActivity(
                    date: existing.date,
                    messageCount: existing.messageCount,
                    sessionCount: existing.sessionCount,
                    toolCallCount: existing.toolCallCount,
                    inputTokens: existing.inputTokens ?? inp,
                    outputTokens: existing.outputTokens ?? out,
                    cacheTokens: existing.cacheTokens ?? cache
                )
                result.append(updated)
            } else {
                result.append(DailyActivity(date: dateStr, messageCount: 0, sessionCount: 0, toolCallCount: 0, inputTokens: tokensMap[dateStr], outputTokens: nil, cacheTokens: nil))
            }
        }

        return result
    }

    static func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
