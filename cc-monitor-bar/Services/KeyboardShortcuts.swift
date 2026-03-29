import AppKit

/// 全局快捷键管理器
/// ⌘1/2/3 切换视图、⌘, 打开设置、⌘R 刷新数据
final class KeyboardShortcuts {
    static let shared = KeyboardShortcuts()

    private var globalMonitor: Any?
    private var localMonitor: Any?

    // 回调
    var onSwitchToMinimal: (() -> Void)?
    var onSwitchToDashboard: (() -> Void)?
    var onSwitchToTimeline: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onRefreshData: (() -> Void)?

    private init() {}

    func start() {
        // 全局监听（应用在后台时）
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            _ = self?.handleKeyEvent(event)
        }

        // 本地监听（应用在前台时）
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if let self, self.handleKeyEvent(event) {
                return nil
            }
            return event
        }
    }

    func stop() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    @discardableResult
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let key = event.charactersIgnoringModifiers?.lowercased()

        guard flags.contains(.command), flags.subtracting(.command).isEmpty else { return false }

        switch key {
        case "1": onSwitchToMinimal?(); return true
        case "2": onSwitchToDashboard?(); return true
        case "3": onSwitchToTimeline?(); return true
        case ",": onOpenSettings?(); return true
        case "r": onRefreshData?(); return true
        default: return false
        }
    }
}

// MARK: - 视图切换通知

extension Notification.Name {
    static let switchView = Notification.Name("cc-monitor-bar.switchView")
}
