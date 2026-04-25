import Foundation

// MARK: - Multi-Frequency Polling Engine

/// 管理不同数据源的轮询调度 + 指数退避
/// AppState 通过此类管理定时器，保持职责单一。
class PollingEngine {

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
        var backoffMultiplier: Int = 1

        mutating func onBackoffReset() { backoffMultiplier = 1 }
        mutating func onBackoffIncrease() { backoffMultiplier = min(backoffMultiplier * 2, 60) }
        var effectiveInterval: TimeInterval { min(interval * Double(backoffMultiplier), 60) }
    }

    private var pollingStates: [PollingDataType: PollingState] = [:]
    private var pollingTimers: [String: Timer] = [:]

    private let onRefreshNeeded: (PollingDataType) -> Void

    init(onRefreshNeeded: @escaping (PollingDataType) -> Void) {
        self.onRefreshNeeded = onRefreshNeeded
    }

    // MARK: - Lifecycle

    func startPolling() {
        for type in PollingDataType.allCases {
            pollingStates[type] = PollingState(interval: type.defaultInterval)
        }
        let timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.tickPolling()
        }
        pollingTimers["tick"] = timer
    }

    func stopPolling() {
        for timer in pollingTimers.values {
            timer.invalidate()
        }
        pollingTimers.removeAll()
    }

    func refreshAll() {
        for type in PollingDataType.allCases {
            guard let state = pollingStates[type] else { continue }
            pollingStates[type]?.elapsed = state.effectiveInterval
            onRefreshNeeded(type)
        }
    }

    func markRefreshed(_ type: PollingDataType) {
        pollingStates[type]?.onBackoffReset()
    }

    func markError(_ type: PollingDataType) {
        pollingStates[type]?.onBackoffIncrease()
    }

    // MARK: - Internal

    private func tickPolling() {
        for type in PollingDataType.allCases {
            guard var state = pollingStates[type] else { continue }
            state.elapsed += 5
            if state.elapsed >= state.effectiveInterval {
                state.elapsed = 0
                onRefreshNeeded(type)
            }
            pollingStates[type] = state
        }
    }
}
