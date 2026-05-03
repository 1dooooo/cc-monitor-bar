import SwiftUI

struct MonitorView: View {
    @EnvironmentObject var appState: AppState
    @State private var collapsedSections: Set<String> = []

    private var topTools: [(name: String, count: Int)] {
        guard let toolCounts = appState.todayStats?.toolCounts else { return [] }
        return toolCounts
            .sorted { $0.value > $1.value }
            .map { (name: $0.key, count: $0.value) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.spacingMD) {
                CollapsibleSection(title: "Token 摘要", isCollapsed: sectionBinding("tokenSummary")) {
                    TokenSummarySection(
                        stats: appState.todayStats,
                        qualityStatus: appState.dataQualityStatus
                    )
                }

                CollapsibleSection(title: "Burn Rate", isCollapsed: sectionBinding("burnRate")) {
                    BurnRateSection(
                        rate: appState.burnRate,
                        level: appState.burnRateLevel,
                        isActive: appState.isBurnRateActive
                    )
                }

                CollapsibleSection(title: "趋势", isCollapsed: sectionBinding("trend")) {
                    TrendChartSection(
                        weeklyData: appState.weeklyData
                    )
                }

                CollapsibleSection(title: "模型", isCollapsed: sectionBinding("model")) {
                    ModelConsumptionSection(
                        modelBreakdown: appState.todayStats?.modelBreakdown ?? [],
                        totalTokens: appState.todayStats?.totalTokens ?? 0
                    )
                }

                CollapsibleSection(title: "活跃会话", isCollapsed: sectionBinding("sessions")) {
                    ActiveSessionSection(
                        sessions: appState.currentSessions,
                        usages: appState.sessionUsages
                    )
                }

                CollapsibleSection(title: "项目", isCollapsed: sectionBinding("projects")) {
                    ProjectSummarySection(
                        projects: appState.projectSummaries
                    )
                }

                CollapsibleSection(title: "历史", isCollapsed: sectionBinding("history")) {
                    RecentSessionSection(
                        sessions: appState.historySessions,
                        usages: appState.historyUsages
                    )
                }

                CollapsibleSection(title: "工具调用", isCollapsed: sectionBinding("tools")) {
                    ToolCallSection(
                        toolCallCount: appState.todayStats?.toolCallCount ?? 0,
                        topTools: topTools
                    )
                }

                if appState.preferences.enableBudgetWarning {
                    CollapsibleSection(title: "预算进度", isCollapsed: sectionBinding("budget")) {
                        BudgetSection(todayStats: appState.todayStats)
                    }
                }

                CollapsibleSection(title: "会话统计", isCollapsed: sectionBinding("sessionSummary")) {
                    SessionSummarySection(
                        activeSessions: appState.currentSessions,
                        todayStats: appState.todayStats
                    )
                }

                CollapsibleSection(title: "使用量热力图", isCollapsed: sectionBinding("heatmap")) {
                    UsageHeatmapView()
                }
            }
            .padding(DesignTokens.spacingMD)
        }
        .frame(
            width: appState.preferences.densityMode == .compact
                ? DesignTokens.popoverWidthCompact
                : DesignTokens.popoverWidthStandard,
            height: DesignTokens.popoverHeight
        )
        .themed(appState.preferences.colorTheme)
        .environmentObject(appState.preferences)
        .onAppear {
            // 同步折叠状态到 UserDefaults
            syncCollapsedSections()
            if appState.todayStats == nil {
                appState.refreshData()
            }
        }
    }

    // MARK: - Helpers

    private func sectionBinding(_ id: String) -> Binding<Bool> {
        Binding(
            get: { collapsedSections.contains(id) },
            set: { isCollapsed in
                if isCollapsed {
                    collapsedSections.insert(id)
                } else {
                    collapsedSections.remove(id)
                }
                appState.preferences.collapsedSections = collapsedSections
                appState.preferences.save()
            }
        )
    }

    private func syncCollapsedSections() {
        collapsedSections = appState.preferences.collapsedSections
    }
}

#Preview {
    MonitorView()
        .environmentObject(AppState.shared)
        .environmentObject(AppPreferences())
}
