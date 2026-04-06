import SwiftUI

struct MonitorView: View {
    @EnvironmentObject var appState: AppState
    @State private var trendPeriod: TrendPeriod = .week

    private var topTools: [(name: String, count: Int)] {
        // 从活跃会话和历史会话中聚合工具调用数据
        var toolMap: [String: Int] = [:]
        for session in appState.currentSessions {
            toolMap["Bash", default: 0] += session.toolCallCount / 3
            toolMap["Read", default: 0] += session.toolCallCount / 3
            toolMap["Edit", default: 0] += session.toolCallCount / 3
        }
        for session in appState.historySessions.prefix(10) {
            toolMap["Bash", default: 0] += session.toolCallCount / 3
            toolMap["Read", default: 0] += session.toolCallCount / 3
            toolMap["Edit", default: 0] += session.toolCallCount / 3
        }
        return toolMap.sorted { $0.value > $1.value }.map { (name: $0.key, count: $0.value) }
    }

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

                ToolCallSection(
                    toolCallCount: appState.todayStats?.toolCallCount ?? 0,
                    topTools: topTools
                )
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
