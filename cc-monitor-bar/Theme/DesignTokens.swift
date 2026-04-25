import SwiftUI

/// 密度模式全局访问器
enum DensityMode: String, CaseIterable, Codable, Identifiable {
    case compact = "compact"
    case standard = "standard"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .compact: return "紧凑"
        case .standard: return "标准"
        }
    }

    /// 当前活动的密度模式（由 AppState 同步）
    static var current: DensityMode = .standard
}

/// 设计系统 Token — 间距、圆角、尺寸、动画常量
/// 所有 UI 组件应通过此结构体引用设计参数，而非硬编码数值
enum DesignTokens {

    // MARK: - 间距

    /// 行内间距、紧凑元素内边距
    static var spacingXS: CGFloat { DensityMode.current == .compact ? 2 : 4 }
    /// 卡片内边距、同组元素间距
    static var spacingSM: CGFloat { DensityMode.current == .compact ? 4 : 8 }
    /// 区块间距、卡片间距
    static var spacingMD: CGFloat { DensityMode.current == .compact ? 6 : 12 }
    /// 外边距、大区块间距
    static var spacingLG: CGFloat { DensityMode.current == .compact ? 8 : 16 }
    /// 页面级间距、大标题上方
    static var spacingXL: CGFloat { DensityMode.current == .compact ? 12 : 20 }

    // MARK: - 圆角

    /// 徽章、标签、小按钮
    static let radiusSM: CGFloat = 4
    /// 卡片、输入框、下拉框、会话行
    static let radiusMD: CGFloat = 8
    /// 区块容器、模态面板、浮动导航
    static let radiusLG: CGFloat = 12

    /// 全圆角（50%），用于状态指示点、头像、药丸按钮
    static func radiusFull(height: CGFloat) -> CGFloat { height / 2 }

    // MARK: - Popover 尺寸

    static let popoverWidthCompact: CGFloat = 280
    static let popoverWidthStandard: CGFloat = 320
    static let popoverWidthWide: CGFloat = 360
    static let popoverHeight: CGFloat = 480
    static let popoverCornerRadius: CGFloat = 10

    // MARK: - 组件尺寸

    static let statusDotSize: CGFloat = 8
    static let badgePaddingV: CGFloat = 3
    static let badgePaddingH: CGFloat = 10
    static let cardPadding: CGFloat = 14
    static let sessionRowHeight: CGFloat = 44

    // MARK: - 动画

    static let animationFast: TimeInterval = 0.15
    static let animationNormal: TimeInterval = 0.25
    static let animationSlow: TimeInterval = 0.3

    // MARK: - FloatingNav

    static let floatingNavCollapseDelay: TimeInterval = 1.5
    static let floatingNavDotSize: CGFloat = 8
    static let floatingNavExpandedItemHeight: CGFloat = 28
}
