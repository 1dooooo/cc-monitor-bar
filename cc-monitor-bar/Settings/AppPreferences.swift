import Foundation
import SwiftUI
import Combine

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

// MARK: - 应用偏好设置

class AppPreferences: ObservableObject {
    static let shared = AppPreferences()
    private let defaults: UserDefaults

    // MARK: - 视图设置

    @Published var defaultView: DefaultView = .minimal
    @Published var rememberLastView: Bool = true
    @Published var lastView: DefaultView = .minimal

    // MARK: - 数据设置

    @Published var refreshInterval: TimeInterval = 30.0
    @Published var compactFormat: Bool = true

    // MARK: - Token 设置

    @Published var showCostEstimate: Bool = false
    @Published var enableBudgetWarning: Bool = false
    @Published var budgetAmount: Double = 100.0

    // MARK: - 系统设置

    @Published var launchAtLogin: Bool = false
    @Published var iconStyle: IconStyle = .default
    @Published var appearanceMode: AppearanceMode = .system
    @Published var colorTheme: ColorTheme = .native

    // MARK: - 存储设置

    @Published var dataRetentionPolicy: DataRetentionPolicy = .days30
    @Published var sqlitePath: String = ""

    // UserDefaults 键
    private enum Keys {
        static let defaultView = "defaultView"
        static let rememberLastView = "rememberLastView"
        static let lastView = "lastView"
        static let refreshInterval = "refreshInterval"
        static let compactFormat = "compactFormat"
        static let showCostEstimate = "showCostEstimate"
        static let enableBudgetWarning = "enableBudgetWarning"
        static let budgetAmount = "budgetAmount"
        static let launchAtLogin = "launchAtLogin"
        static let iconStyle = "iconStyle"
        static let appearanceMode = "appearanceMode"
        static let colorTheme = "colorTheme"
        static let dataRetentionPolicy = "dataRetentionPolicy"
        static let sqlitePath = "sqlitePath"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - 初始化

    func load() {
        let libraryPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appPath = libraryPath.appendingPathComponent("ClaudeMonitor", isDirectory: true)
        let defaultPath = appPath.appendingPathComponent("data.db").path

        defaultView = DefaultView(rawValue: defaults.string(forKey: Keys.defaultView) ?? DefaultView.minimal.rawValue) ?? .minimal
        rememberLastView = defaults.object(forKey: Keys.rememberLastView) as? Bool ?? true
        lastView = DefaultView(rawValue: defaults.string(forKey: Keys.lastView) ?? DefaultView.minimal.rawValue) ?? .minimal
        refreshInterval = defaults.object(forKey: Keys.refreshInterval) as? TimeInterval ?? 30.0
        compactFormat = defaults.object(forKey: Keys.compactFormat) as? Bool ?? true
        showCostEstimate = defaults.object(forKey: Keys.showCostEstimate) as? Bool ?? false
        enableBudgetWarning = defaults.object(forKey: Keys.enableBudgetWarning) as? Bool ?? false
        budgetAmount = defaults.object(forKey: Keys.budgetAmount) as? Double ?? 100.0
        launchAtLogin = defaults.object(forKey: Keys.launchAtLogin) as? Bool ?? false
        iconStyle = IconStyle(rawValue: defaults.string(forKey: Keys.iconStyle) ?? IconStyle.default.rawValue) ?? .default
        appearanceMode = AppearanceMode(rawValue: defaults.string(forKey: Keys.appearanceMode) ?? AppearanceMode.system.rawValue) ?? .system
        colorTheme = ColorTheme(rawValue: defaults.string(forKey: Keys.colorTheme) ?? ColorTheme.native.rawValue) ?? .native
        dataRetentionPolicy = DataRetentionPolicy(rawValue: defaults.string(forKey: Keys.dataRetentionPolicy) ?? DataRetentionPolicy.days30.rawValue) ?? .days30
        sqlitePath = defaults.string(forKey: Keys.sqlitePath) ?? defaultPath
    }

    func save() {
        defaults.set(defaultView.rawValue, forKey: Keys.defaultView)
        defaults.set(rememberLastView, forKey: Keys.rememberLastView)
        defaults.set(lastView.rawValue, forKey: Keys.lastView)
        defaults.set(refreshInterval, forKey: Keys.refreshInterval)
        defaults.set(compactFormat, forKey: Keys.compactFormat)
        defaults.set(showCostEstimate, forKey: Keys.showCostEstimate)
        defaults.set(enableBudgetWarning, forKey: Keys.enableBudgetWarning)
        defaults.set(budgetAmount, forKey: Keys.budgetAmount)
        defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
        defaults.set(iconStyle.rawValue, forKey: Keys.iconStyle)
        defaults.set(appearanceMode.rawValue, forKey: Keys.appearanceMode)
        defaults.set(colorTheme.rawValue, forKey: Keys.colorTheme)
        defaults.set(dataRetentionPolicy.rawValue, forKey: Keys.dataRetentionPolicy)
        defaults.set(sqlitePath, forKey: Keys.sqlitePath)
    }

    // MARK: - 视图切换辅助方法

    func getCurrentView() -> DefaultView {
        if rememberLastView {
            return lastView
        } else {
            return defaultView
        }
    }

    func setCurrentView(_ view: DefaultView) {
        if rememberLastView {
            lastView = view
        }
    }
}
