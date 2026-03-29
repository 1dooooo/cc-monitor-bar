import SwiftUI
import TipKit

@main
struct CCMonitorBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        if #available(macOS 14, *) {
            try? Tips.configure()
        }
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
