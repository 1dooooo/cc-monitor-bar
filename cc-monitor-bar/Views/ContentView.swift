import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentView: DefaultView = .minimal
    @State private var hasLoaded = false

    var body: some View {
        Group {
            switch currentView {
            case .minimal:
                MinimalView()
            case .dashboard:
                DashboardView(preferences: appState.preferences)
            case .timeline:
                TimelineView(preferences: appState.preferences)
            }
        }
        .frame(width: DesignTokens.popoverWidthStandard, height: DesignTokens.popoverHeight)
        .themed(appState.preferences.colorTheme)
        .onAppear {
            guard !hasLoaded else { return }
            hasLoaded = true
            currentView = appState.preferences.getCurrentView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchView)) { notification in
            if let view = notification.object as? DefaultView {
                withAnimation(.easeInOut(duration: DesignTokens.animationNormal)) {
                    currentView = view
                }
            }
        }
    }
}
