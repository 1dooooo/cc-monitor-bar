import AppKit
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    let appState = AppState.shared
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // 应用初始外观
        applyAppearance(appState.preferences.appearanceMode)

        // 监听外观模式变化
        appState.preferences.$appearanceMode
            .receive(on: RunLoop.main)
            .sink { [weak self] mode in
                self?.applyAppearance(mode)
            }
            .store(in: &cancellables)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "chart.bar.fill", accessibilityDescription: "CC Monitor")
            button.target = self
            button.action = #selector(togglePopover)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // 4.1 动态菜单栏图标 — 根据活跃会话数和 Burn Rate 更新状态栏
        setupDynamicStatusBarIcon()

        // 4.2 监听图标样式变化
        appState.preferences.$iconStyle
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, let button = statusItem?.button else { return }
                let sessionCount = appState.currentSessions.count
                updateStatusBarIcon(sessionCount: sessionCount)
            }
            .store(in: &cancellables)

        popover = NSPopover()
        popover?.contentSize = NSSize(width: DesignTokens.popoverWidthStandard, height: DesignTokens.popoverHeight)
        popover?.contentViewController = NSHostingController(
            rootView: MonitorView()
                .environmentObject(appState)
        )
        popover?.behavior = .transient
        popover?.animates = true

        // 注册全局快捷键
        let shortcuts = KeyboardShortcuts.shared
        shortcuts.onOpenSettings = { [weak self] in
            self?.openSettingsItem()
        }
        shortcuts.onRefreshData = { [weak self] in
            self?.appState.refreshData()
        }
        shortcuts.start()
    }

    @objc func togglePopover() {
        guard let button = statusItem?.button else { return }

        let event = NSApp.currentEvent

        if event?.type == .rightMouseUp || event?.type == .otherMouseUp {
            showContextMenu(button: button)
            return
        }

        if popover?.isShown == true {
            popover?.performClose(nil)
        } else {
            appState.refreshData()
            popover?.contentViewController = NSHostingController(
                rootView: MonitorView()
                    .environmentObject(appState)
            )
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func showContextMenu(button: NSStatusBarButton) {
        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: "设置", action: #selector(openSettingsItem), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q"))

        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.maxY + 4), in: button)
    }

    @objc private func openSettingsItem() {
        // 关闭 Popover，打开独立设置窗口
        popover?.performClose(nil)
        SettingsWindowController.shared.showWindow()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - 外观模式

    private func applyAppearance(_ mode: AppearanceMode) {
        switch mode {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    // MARK: - 4.1 动态菜单栏图标

    private func setupDynamicStatusBarIcon() {
        // 监听活跃会话数变化
        appState.$currentSessions
            .receive(on: RunLoop.main)
            .sink { [weak self] sessions in
                self?.updateStatusBarIcon(sessionCount: sessions.count)
            }
            .store(in: &cancellables)

        // 监听 Burn Rate 变化
        appState.$burnRateLevel
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, let button = statusItem?.button else { return }
                let sessionCount = appState.currentSessions.count
                updateStatusBarIcon(sessionCount: sessionCount)
            }
            .store(in: &cancellables)
    }

    private func updateStatusBarIcon(sessionCount: Int) {
        guard let button = statusItem?.button else { return }

        let rateLevel = appState.burnRateLevel
        let isActive = sessionCount > 0
        let iconStyle = appState.preferences.iconStyle

        let color: NSColor
        switch rateLevel {
        case .idle:
            color = .systemGray
        case .active:
            color = .systemOrange
        case .heavy:
            color = .systemRed
        }

        let baseSymbolName = iconStyle.systemSymbol
        let finalSymbolName = isActive ? baseSymbolName : baseSymbolName.replacingOccurrences(of: ".fill", with: "")

        if let image = NSImage(systemSymbolName: finalSymbolName, accessibilityDescription: "CC Monitor") {
            image.setTintColor(color)
            button.image = image
        }

        if isActive {
            button.title = " \(sessionCount)"
        } else {
            button.title = ""
        }
    }
}

// MARK: - NSImage Extension

extension NSImage {
    func setTintColor(_ color: NSColor) {
        self.lockFocus()
        color.set()
        let imageRect = NSRect(origin: .zero, size: self.size)
        imageRect.fill(using: .sourceIn)
        self.unlockFocus()
    }
}
