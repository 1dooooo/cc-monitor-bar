import Foundation

// MARK: - 默认视图枚举

enum DefaultView: String, CaseIterable, Codable, Identifiable {
    case minimal = "minimal"
    case dashboard = "dashboard"
    case timeline = "timeline"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .minimal: return "极简"
        case .dashboard: return "数据看板"
        case .timeline: return "时间线"
        }
    }
}

// MARK: - 图标样式枚举

enum IconStyle: String, CaseIterable, Codable, Identifiable {
    case `default` = "default"
    case minimal = "minimal"
    case colorful = "colorful"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .default: return "默认"
        case .minimal: return "简约"
        case .colorful: return "彩色"
        }
    }

    var systemSymbol: String {
        switch self {
        case .default: return "chart.bar.fill"
        case .minimal: return "chart.bar"
        case .colorful: return "chart.pie.fill"
        }
    }
}

// MARK: - 外观模式枚举

/// 控制深色/浅色/跟随系统（与配色主题 ColorTheme 独立）
enum AppearanceMode: String, CaseIterable, Codable, Identifiable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }
}

// MARK: - 数据保留期限

enum DataRetentionPolicy: String, CaseIterable, Codable {
    case days7 = "7"
    case days30 = "30"
    case days90 = "90"
    case forever = "forever"

    var displayName: String {
        switch self {
        case .days7: return "7 天"
        case .days30: return "30 天"
        case .days90: return "90 天"
        case .forever: return "永久"
        }
    }

    var days: Int? {
        switch self {
        case .days7: return 7
        case .days30: return 30
        case .days90: return 90
        case .forever: return nil
        }
    }
}
