import SwiftUI

struct MonitorView: View {
    @EnvironmentObject var appState: AppState
    @State private var trendPeriod: TrendPeriod = .week

    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.spacingMD) {
                TokenSummarySection(stats: appState.todayStats)

                TrendChartSection(
                    weeklyData: appState.weeklyData,
                    period: $trendPeriod
                )

                ModelConsumptionSection(modelBreakdown: appState.todayStats?.modelBreakdown ?? [])

                ActiveSessionSection(
                    sessions: appState.currentSessions,
                    usages: appState.sessionUsages
                )

                RecentSessionSection(
                    sessions: appState.historySessions,
                    usages: appState.sessionUsages
                )

                ToolCallSection(toolCallCount: appState.todayStats?.toolCallCount ?? 0)
            }
            .padding(DesignTokens.spacingMD)
        }
        .frame(
            width: DesignTokens.popoverWidthStandard,
            height: DesignTokens.popoverHeight
        )
        .themed(appState.preferences.colorTheme)
        .onAppear {
            if appState.todayStats == nil {
                appState.refreshData()
            }
        }
    }
}

enum TrendPeriod: String, CaseIterable {
    case week = "周"
    case month = "月"
}

#Preview {
    MonitorView()
        .environmentObject(AppState.shared)
}
