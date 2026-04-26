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

class AppState: ObservableObject {
    static let shared = AppState()

    // MARK: - Published Data

    @Published var currentSessions: [Session] = []
    @Published var sessionUsages: [String: SessionUsage] = [:]
    @Published var historySessions: [Session] = []
    @Published var historyUsages: [String: SessionUsage] = [:]
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
    private let fileWatcher = FileWatcher()
    private let hookServer = HookServer()
    private lazy var pollingEngine: PollingEngine = {
        let engine = PollingEngine { [weak self] type in
            self?.loadDataType(type)
        }
        return engine
    }()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init() {
        preferences.load()
        pollingEngine.startPolling()

        // 立即执行全量加载
        refreshData()

        // 设置文件监听：活跃会话 JSONL 文件变更时立即刷新
        fileWatcher.setOnChangeHandler { [weak self] _ in
            self?.loadSessions()
            self?.loadTodayStats()
        }

        // 设置 hooks 监听：Claude Code 工具调用事件到达时立即刷新
        hookServer?.setEventHandler { [weak self] event in
            guard event.isPostTool else { return }
            self?.loadSessions()
            self?.loadTodayStats()
        }
        hookServer?.start()

        // 监听刷新间隔变更，重建定时器（兼容旧偏好设置）
        preferences.$refreshInterval
            .dropFirst()
            .sink { [weak self] _ in
                self?.refreshData()
            }
            .store(in: &cancellables)
    }

    deinit {
        pollingEngine.stopPolling()
        fileWatcher.stopAll()
        hookServer?.stop()
    }

    // MARK: - Data Loading

    private func loadDataType(_ type: PollingEngine.PollingDataType) {
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
                var jsonlPaths: Set<String> = []
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
                    if let basePath = self.reader.resolveSessionBasePath(cwd: info.cwd, sessionId: info.sessionId) {
                        jsonlPaths.insert("\(basePath).jsonl")
                    }
                }
                let tuples = active.map { ($0.id, $0.pid, $0.projectPath, $0.projectId, $0.startedAt, $0.messageCount, $0.toolCallCount, $0.entrypoint) }
                self.reader.persistSessions(tuples, usages: usages)
                self.fileWatcher.watch(paths: jsonlPaths)
                DispatchQueue.main.async {
                    self.currentSessions = active
                    self.sessionUsages = usages
                }
                self.pollingEngine.markRefreshed(.sessions)
            } catch {
                print("读取活跃会话失败: \(error)")
                self.pollingEngine.markError(.sessions)
            }
        }
    }

    private func loadHistory() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            do {
                let historyEntries = try self.reader.readHistory(limit: 200)
                var history: [Session] = []
                var usages: [String: SessionUsage] = [:]
                var seenIds = Set<String>()
                for entry in historyEntries.reversed() {
                    guard let sid = entry.sessionId,
                          let project = entry.project,
                          !seenIds.contains(sid) else { continue }
                    seenIds.insert(sid)
                    let projectId = self.resolver.resolveProjectId(from: project)
                    let startedAt = Date(timeIntervalSince1970: Double(entry.timestamp) / 1000.0)
                    let usage = self.reader.readSessionUsage(cwd: project, sessionId: sid)
                    usages[sid] = usage
                    let endedAt: Date? = usage.lastMessageTimestamp ?? startedAt
                    let durationSec: TimeInterval = if let ended = endedAt {
                        max(ended.timeIntervalSince(startedAt), 1)
                    } else {
                        Date().timeIntervalSince(startedAt)
                    }
                    let durationMs = Int64(durationSec * 1000)
                    history.append(Session(
                        id: sid, pid: 0, projectPath: project, projectId: projectId,
                        startedAt: startedAt, endedAt: endedAt,
                        durationMs: durationMs,
                        messageCount: usage.messageCount, toolCallCount: usage.toolCallCount,
                        entrypoint: "cli"
                    ))
                }
                DispatchQueue.main.async {
                    self.historySessions = history
                    self.historyUsages = usages
                }
                self.pollingEngine.markRefreshed(.history)
            } catch {
                print("读取历史失败: \(error)")
                self.pollingEngine.markError(.history)
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

                qualityStatus = DataQuality.buildStatus(
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

                self.reader.persistDailyStats(
                    date: todayStr, projectId: "_global",
                    messageCount: messageCount, sessionCount: sessionCount,
                    toolCallCount: toolCallCount, totalTokens: totalTokens,
                    inputTokens: totalInputTokens, outputTokens: totalOutputTokens,
                    cacheTokens: totalCacheTokens, modelBreakdown: breakdown
                )

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
                    self.loadWeeklyData(todayStats: stats)
                }
                self.pollingEngine.markRefreshed(.todayStats)
            } catch {
                print("读取今日统计失败: \(error)")
                self.pollingEngine.markError(.todayStats)
            }
        }
    }

    private func loadWeeklyData(todayStats: TodayStats? = nil) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            do {
                let cache = try self.reader.readStatsCache()
                let weeklyData = Self.last7Days(
                    from: cache.dailyActivity,
                    dailyModelTokens: cache.dailyModelTokens,
                    todayStats: todayStats ?? self.todayStats
                )
                DispatchQueue.main.async { self.weeklyData = weeklyData }
                self.pollingEngine.markRefreshed(.weeklyData)
            } catch {
                print("读取周数据失败: \(error)")
                self.pollingEngine.markError(.weeklyData)
            }
        }
    }

    /// 手动全量刷新（覆盖正常间隔立即加载）
    func refreshData() {
        pollingEngine.refreshAll()
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

    /// 从 dailyActivity 和 dailyModelTokens 中提取最近 7 天的数据
    private static func last7Days(
        from dailyActivity: [DailyActivity],
        dailyModelTokens: [DailyModelTokens],
        todayStats: TodayStats?
    ) -> [DailyActivity] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todayStr = dateFormatter.string(from: today)

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

            if offset == 0, let jsonl = todayStats {
                result.append(DailyActivity(
                    date: dateStr,
                    messageCount: jsonl.messageCount,
                    sessionCount: jsonl.sessionCount,
                    toolCallCount: jsonl.toolCallCount,
                    inputTokens: jsonl.inputTokens,
                    outputTokens: jsonl.outputTokens,
                    cacheTokens: jsonl.cacheTokens
                ))
                continue
            }

            if let existing = activityMap[dateStr] {
                // 直接使用 DailyActivity 已有的 input/output/cache 值（不再用 modelRatios 拆分）
                let updated = DailyActivity(
                    date: existing.date,
                    messageCount: existing.messageCount,
                    sessionCount: existing.sessionCount,
                    toolCallCount: existing.toolCallCount,
                    inputTokens: existing.inputTokens,
                    outputTokens: existing.outputTokens,
                    cacheTokens: existing.cacheTokens
                )
                result.append(updated)
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
