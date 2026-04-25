import Foundation
import SwiftUI
import Combine

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

    // MARK: - UI 模式设置

    /// 密度模式: compact = 紧凑, standard = 标准
    @Published var densityMode: DensityMode = .standard

    /// 用户折叠的区块 ID 列表
    @Published var collapsedSections: Set<String> = []

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
        static let densityMode = "densityMode"
        static let collapsedSections = "collapsedSections"
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
        densityMode = DensityMode(rawValue: defaults.string(forKey: Keys.densityMode) ?? DensityMode.standard.rawValue) ?? .standard
        if let saved = defaults.array(forKey: Keys.collapsedSections) as? [String] {
            collapsedSections = Set(saved)
        }
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
        defaults.set(densityMode.rawValue, forKey: Keys.densityMode)
        defaults.set(Array(collapsedSections), forKey: Keys.collapsedSections)
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
