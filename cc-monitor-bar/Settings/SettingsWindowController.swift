import AppKit
import SwiftUI

/// 设置独立窗口控制器
/// 管理 NSWindow 的生命周期：显示/隐藏/位置记忆
final class SettingsWindowController: NSWindowController {

    static let shared = SettingsWindowController()

    private let appState = AppState.shared
    private var hostingView: NSHostingView<AnyView>?

    private init() {
        // 创建窗口
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 440),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "cc-monitor-bar 设置"
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.center()

        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public

    func showWindow() {
        // 重建内容以确保最新状态
        rebuildContent()

        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hideWindow() {
        window?.orderOut(nil)
    }

    func toggleWindow() {
        if window?.isVisible == true {
            hideWindow()
        } else {
            showWindow()
        }
    }

    // MARK: - Private

    private func rebuildContent() {
        let contentView = AnyView(
            SettingsWindowContent(preferences: appState.preferences)
                .environmentObject(appState)
        )

        if let hostingView = hostingView {
            hostingView.rootView = contentView
        } else {
            let frame = window?.contentRect(forFrameRect: window?.frame ?? .zero) ?? NSRect(x: 0, y: 0, width: 560, height: 440)
            let hosting = NSHostingView(rootView: contentView)
            hosting.frame = frame
            hosting.autoresizingMask = [.width, .height]
            window?.contentView = hosting
            self.hostingView = hosting
        }
    }
}
