import Foundation

/// Burn Rate 追踪器 — 5 分钟 token 消耗 EMA 平滑速率
///
/// 算法：
/// - 每次 update(totalTokens:) 计算距离上次采样的瞬时速率 (tokens/min)
/// - EMA 平滑: ema_new = α * currentRate + (1 - α) * ema_old
/// - 颜色编码: 🟢 < 300 / 🟡 300-700 / 🔴 > 700 tokens/min
final class BurnRateTracker {
    /// tokens/min 阈值
    enum RateLevel: String {
        case idle      // 🟢 < 300
        case active    // 🟡 300-700
        case heavy     // 🔴 > 700

        var displayText: String {
            switch self {
            case .idle: return "空闲"
            case .active: return "活跃"
            case .heavy: return "高负载"
            }
        }

        var emoji: String {
            switch self {
            case .idle: return "🟢"
            case .active: return "🟡"
            case .heavy: return "🔴"
            }
        }
    }

    /// EMA 平滑系数
    private let alpha: Double = 0.3

    private var lastTotalTokens: Int64?
    private var lastTimestamp: Date?
    private var emaRate: Double = 0
    private var sampleCount = 0

    /// 当前 EMA 平滑后的速率 (tokens/min)
    var currentRate: Double { emaRate }

    /// 当前速率等级
    var rateLevel: RateLevel {
        if emaRate < 300 { return .idle }
        if emaRate < 700 { return .active }
        return .heavy
    }

    /// 是否已有数据
    var isActive: Bool { sampleCount > 0 }

    /// 更新速率（每次 refreshData 调用）
    /// - Parameter totalTokens: 当前累计 token 总量
    func update(totalTokens: Int64) {
        let now = Date()

        if let lastTokens = lastTotalTokens, let lastTime = lastTimestamp {
            let elapsedMin = now.timeIntervalSince(lastTime) / 60.0
            guard elapsedMin > 0 else { return }

            let deltaTokens = max(totalTokens - lastTokens, 0)
            let instantaneousRate = Double(deltaTokens) / elapsedMin

            sampleCount += 1
            if sampleCount == 1 {
                // 首次采样：直接取瞬时值
                emaRate = instantaneousRate
            } else {
                // EMA 平滑
                emaRate = alpha * instantaneousRate + (1 - alpha) * emaRate
            }
        } else {
            // 首次调用：仅记录基线
            sampleCount = 0
        }

        lastTotalTokens = totalTokens
        lastTimestamp = now
    }

    /// 重置追踪器（如切换会话或长时间空闲后）
    func reset() {
        lastTotalTokens = nil
        lastTimestamp = nil
        emaRate = 0
        sampleCount = 0
    }
}
