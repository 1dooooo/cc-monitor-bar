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
}
