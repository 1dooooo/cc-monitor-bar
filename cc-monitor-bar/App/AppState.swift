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

struct DataQualityStatus {
    let level: DataQualityLevel
    let summary: String
    let sourceDate: String?
    let isCacheStale: Bool
    let tokenDiffRatio: Double?
    let messageDiffRatio: Double?
    let sessionDiffRatio: Double?
    let toolDiffRatio: Double?
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
    @Published var isLoading = false

    // MARK: - Dependencies

    let preferences = AppPreferences.shared
    private let reader = ClaudeDataReader()
    private let resolver = ProjectResolver()
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init() {
        preferences.load()
        startPolling()
    }

    deinit {
        timer?.invalidate()
    }

    // MARK: - Polling

    private func startPolling() {
        scheduleTimer()
        refreshData()

        // 监听刷新间隔变更，重建 Timer
        preferences.$refreshInterval
            .dropFirst()
            .sink { [weak self] _ in
                self?.scheduleTimer()
            }
            .store(in: &cancellables)
    }

    private func scheduleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: preferences.refreshInterval, repeats: true) { [weak self] _ in
            self?.refreshData()
        }
    }

    // MARK: - Data Loading

    func refreshData() {
        isLoading = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            var active: [Session] = []
            var usages: [String: SessionUsage] = [:]
            var history: [Session] = []
            var stats: TodayStats?
            var qualityStatus: DataQualityStatus?
            var weeklyData: [DailyActivity] = []

            // 1. 活跃会话 + per-session usage
            do {
                let sessionInfos = try self.reader.readActiveSessions()
                for info in sessionInfos {
                    let projectId = self.resolver.resolveProjectId(from: info.cwd)

                    // 读取该会话的 token 用量
                    let usage = self.reader.readSessionUsage(cwd: info.cwd, sessionId: info.sessionId)
                    usages[info.sessionId] = usage

                    let session = Session(
                        id: info.sessionId,
                        pid: info.pid,
                        projectPath: info.cwd,
                        projectId: projectId,
                        startedAt: Date(timeIntervalSince1970: Double(info.startedAt) / 1000.0),
                        endedAt: nil,
                        durationMs: Int64(Date().timeIntervalSince1970 * 1000) - info.startedAt,
                        messageCount: usage.messageCount,
                        toolCallCount: usage.toolCallCount,
                        entrypoint: info.entrypoint
                    )
                    active.append(session)
                }
            } catch {
                print("读取活跃会话失败: \(error)")
            }

            // 2. 历史记录
            do {
                let historyEntries = try self.reader.readHistory(limit: 200)
                var seenIds = Set<String>()
                for entry in historyEntries.reversed() {
                    guard let sid = entry.sessionId,
                          let project = entry.project,
                          !seenIds.contains(sid) else { continue }
                    seenIds.insert(sid)

                    let projectId = self.resolver.resolveProjectId(from: project)
                    let session = Session(
                        id: sid,
                        pid: 0,
                        projectPath: project,
                        projectId: projectId,
                        startedAt: Date(timeIntervalSince1970: Double(entry.timestamp) / 1000.0),
                        endedAt: Date(timeIntervalSince1970: Double(entry.timestamp) / 1000.0 + 3600),
                        durationMs: 3600000,
                        messageCount: 0,
                        toolCallCount: 0,
                        entrypoint: "cli"
                    )
                    history.append(session)
                }
            } catch {
                print("读取历史失败: \(error)")
            }

            // 3. 今日统计（优先实时 JSONL 聚合，stats-cache 兜底/补充）
            let todayUsage = self.reader.readTodayUsage()
            var messageCount = todayUsage.messageCount
            var sessionCount = todayUsage.sessionCount
            var toolCallCount = todayUsage.toolCallCount
            var totalTokens = todayUsage.totalTokens
            var totalInputTokens = todayUsage.inputTokens
            var totalOutputTokens = todayUsage.outputTokens
            var totalCacheTokens = todayUsage.cacheTokens
            var breakdown = todayUsage.modelBreakdown

            do {
                let cache = try self.reader.readStatsCache()
                let todayStr = Self.todayDateString()
                let todayActivity = cache.dailyActivity.first { $0.date == todayStr }
                let latestDay = cache.dailyActivity.last
                let modelRatios = Self.modelRatios(from: cache.modelUsage)

                qualityStatus = Self.buildDataQualityStatus(
                    todayUsage: todayUsage,
                    cache: cache,
                    todayStr: todayStr
                )

                // 今日 message/session/tool 次数：用实时值和缓存值取较大，减少缓存延迟影响
                let cacheDayForCounts = todayActivity ?? latestDay
                if let day = cacheDayForCounts {
                    messageCount = max(messageCount, day.messageCount)
                    sessionCount = max(sessionCount, day.sessionCount)
                    toolCallCount = max(toolCallCount, day.toolCallCount)
                }

                // 若实时解析暂无 token，再退回 stats-cache 的 dailyModelTokens
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

                weeklyData = Self.last7Days(
                    from: cache.dailyActivity,
                    dailyModelTokens: cache.dailyModelTokens,
                    modelRatios: modelRatios
                )
            } catch {
                print("读取 stats-cache 失败: \(error)")
                qualityStatus = DataQualityStatus(
                    level: .unavailable,
                    summary: "stats-cache 不可用，已仅使用实时 JSONL",
                    sourceDate: nil,
                    isCacheStale: false,
                    tokenDiffRatio: nil,
                    messageDiffRatio: nil,
                    sessionDiffRatio: nil,
                    toolDiffRatio: nil
                )
                weeklyData = []
            }

            breakdown.sort { $0.tokens > $1.tokens }

            stats = TodayStats(
                messageCount: messageCount,
                sessionCount: sessionCount,
                toolCallCount: toolCallCount,
                totalTokens: totalTokens,
                inputTokens: totalInputTokens,
                outputTokens: totalOutputTokens,
                cacheTokens: totalCacheTokens,
                modelBreakdown: breakdown
            )

            DispatchQueue.main.async {
                self.currentSessions = active
                self.sessionUsages = usages
                self.historySessions = history
                self.todayStats = stats
                self.dataQualityStatus = qualityStatus
                self.weeklyData = weeklyData
                self.isLoading = false
            }
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
            modelBreakdown: [(name: String, tokens: Int64, inputTokens: Int64, outputTokens: Int64, cacheTokens: Int64)]
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
                toolDiffRatio: nil
            )
        }

        let cacheTokens = day.totalTokens > 0 ? day.totalTokens : cacheDayTokens

        let tokenDiff = diffRatio(lhs: todayUsage.totalTokens, rhs: cacheTokens)
        let messageDiff = diffRatio(lhs: Int64(todayUsage.messageCount), rhs: Int64(day.messageCount))
        let sessionDiff = diffRatio(lhs: Int64(todayUsage.sessionCount), rhs: Int64(day.sessionCount))
        let toolDiff = diffRatio(lhs: Int64(todayUsage.toolCallCount), rhs: Int64(day.toolCallCount))

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
            toolDiffRatio: toolDiff
        )
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
