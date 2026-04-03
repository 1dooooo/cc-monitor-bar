import Foundation
import SwiftUI
import Combine

/// 全局聚合统计
struct TodayStats {
    let messageCount: Int
    let sessionCount: Int
    let toolCallCount: Int
    let totalTokens: Int64
    let modelBreakdown: [(name: String, tokens: Int64)]
}

class AppState: ObservableObject {
    static let shared = AppState()

    // MARK: - Published Data

    @Published var currentSessions: [Session] = []
    @Published var sessionUsages: [String: SessionUsage] = [:]
    @Published var historySessions: [Session] = []
    @Published var todayStats: TodayStats?
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

            // 3. 全局统计（stats-cache）
            do {
                let cache = try self.reader.readStatsCache()
                let latestDay = cache.dailyActivity.last

                var totalTokens: Int64 = 0
                var breakdown: [(name: String, tokens: Int64)] = []
                for (model, usage) in cache.modelUsage {
                    let t = usage.inputTokens + usage.outputTokens + usage.cacheReadInputTokens + usage.cacheCreationInputTokens
                    totalTokens += t
                    breakdown.append((name: model, tokens: t))
                }
                breakdown.sort { $0.tokens > $1.tokens }

                stats = TodayStats(
                    messageCount: latestDay?.messageCount ?? 0,
                    sessionCount: latestDay?.sessionCount ?? 0,
                    toolCallCount: latestDay?.toolCallCount ?? 0,
                    totalTokens: totalTokens,
                    modelBreakdown: breakdown
                )

                // 填充最近 7 天的 dailyActivity（带 Token 数据）
                let weekly = Self.last7DaysWithTokens(from: cache.dailyActivity, modelUsage: cache.modelUsage)
                weeklyData = weekly
            } catch {
                print("读取 stats-cache 失败: \(error)")
            }

            DispatchQueue.main.async {
                self.currentSessions = active
                self.sessionUsages = usages
                self.historySessions = history
                self.todayStats = stats
                self.weeklyData = weeklyData
                self.isLoading = false
            }
        }
    }

    // MARK: - Weekly Data Helper

    /// 从 dailyActivity 中提取最近 7 天的数据，缺失日期补零
    private static func last7Days(from dailyActivity: [DailyActivity]) -> [DailyActivity] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // 构建日期 → DailyActivity 的查找表
        var activityMap: [String: DailyActivity] = [:]
        for activity in dailyActivity {
            activityMap[activity.date] = activity
        }

        var result: [DailyActivity] = []
        for offset in (0..<7).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let dateStr = dateFormatter.string(from: date)

            if let existing = activityMap[dateStr] {
                result.append(existing)
            } else {
                // 补零
                result.append(DailyActivity(date: dateStr, messageCount: 0, sessionCount: 0, toolCallCount: 0, inputTokens: 0, outputTokens: 0, cacheTokens: 0))
            }
        }

        return result
    }

    /// 从 dailyActivity 和 modelUsage 中提取最近 7 天的数据（带 Token 分解）
    private static func last7DaysWithTokens(from dailyActivity: [DailyActivity], modelUsage: [String: ModelUsage]) -> [DailyActivity] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // 构建日期 → DailyActivity 的查找表
        var activityMap: [String: DailyActivity] = [:]
        for activity in dailyActivity {
            activityMap[activity.date] = activity
        }

        var result: [DailyActivity] = []
        for offset in (0..<7).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let dateStr = dateFormatter.string(from: date)

            if let existing = activityMap[dateStr] {
                // 如果有现成的带 Token 数据，直接用
                result.append(existing)
            } else {
                // 补零
                result.append(DailyActivity(date: dateStr, messageCount: 0, sessionCount: 0, toolCallCount: 0, inputTokens: 0, outputTokens: 0, cacheTokens: 0))
            }
        }

        return result
    }
}
