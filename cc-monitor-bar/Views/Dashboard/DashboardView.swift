import SwiftUI

/// 数据看板 — 单页滚动 + FloatingNav 浮动锚点导航
struct DashboardView: View {
    @ObservedObject var preferences: AppPreferences
    @EnvironmentObject var appState: AppState
    @Environment(\.colorTheme) private var theme

    @State private var activeSection: String = "overview"
    @State private var floatingNavExpanded: Bool = true

    private let sectionDefs: [FloatingNav.SectionDef] = [
        .init(id: "overview", icon: "chart.bar.fill", label: "概览"),
        .init(id: "models",   icon: "cpu",            label: "模型"),
        .init(id: "sessions", icon: "bubble.left.and.bubble.right", label: "会话"),
        .init(id: "tools",    icon: "wrench.and.screwdriver", label: "工具"),
    ]

    init(preferences: AppPreferences = .shared) {
        self.preferences = preferences
    }

    var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .topTrailing) {
                // 主滚动内容
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        headerBar

                        overviewSection
                            .id("overview")
                            .trackSection("overview")
                        sectionDivider

                        modelsSection
                            .id("models")
                            .trackSection("models")
                        sectionDivider

                        sessionsSection
                            .id("sessions")
                            .trackSection("sessions")
                        sectionDivider

                        toolsSection
                            .id("tools")
                            .trackSection("tools")
                    }
                    .padding(.horizontal, DesignTokens.spacingLG)
                    .padding(.bottom, DesignTokens.spacingXL)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: ScrollOffsetPreferenceKey.self,
                                value: geo.frame(in: .named("dashboardScroll")).minY
                            )
                        }
                    )
                    .dashboardNavTip()
                }
                .coordinateSpace(name: "dashboardScroll")
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { _ in
                    floatingNavExpanded = true
                }
                .onPreferenceChange(SectionFramePreferenceKey.self) { frames in
                    // 找到 minY 最接近顶部的 section（阈值：顶部附近且已滚过）
                    let visibleSections = frames.filter { $0.value <= 100 }
                    if let closest = visibleSections.max(by: { $0.value < $1.value }) {
                        if activeSection != closest.key {
                            activeSection = closest.key
                        }
                    }
                    floatingNavExpanded = true
                }

                // FloatingNav 右内侧悬浮
                VStack {
                    Spacer().frame(height: 56)
                    FloatingNav(
                        sections: sectionDefs,
                        activeSection: $activeSection,
                        onSectionTap: { sectionId in
                            withAnimation(.easeInOut(duration: DesignTokens.animationNormal)) {
                                proxy.scrollTo(sectionId, anchor: .top)
                            }
                        },
                        isExpanded: $floatingNavExpanded
                    )
                    Spacer()
                }
                .padding(.trailing, DesignTokens.spacingSM)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GlassBackground())
    }

    // MARK: - 顶栏

    private var headerBar: some View {
        HStack {
            Text("数据看板")
                .font(.headline)
            Spacer()
            Text(Date.now, style: .date)
                .font(.caption)
                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
        }
        .padding(.vertical, DesignTokens.spacingMD)
    }

    // MARK: - 概览区块

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            sectionHeader("概览", icon: "chart.bar.fill")

            if let stats = appState.todayStats {
                StatCard(title: "累计 Token", rawValue: stats.totalTokens)

                HStack(spacing: DesignTokens.spacingSM) {
                    StatCard(title: "消息数", rawValue: Int64(stats.messageCount))
                    StatCard(title: "会话数", rawValue: Int64(stats.sessionCount))
                }
                HStack(spacing: DesignTokens.spacingSM) {
                    StatCard(title: "工具调用", rawValue: Int64(stats.toolCallCount))
                    StatCard(title: "活跃会话", rawValue: Int64(appState.currentSessions.count))
                }

                if !stats.modelBreakdown.isEmpty {
                    Divider()
                    modelMiniChart
                }

                // 7 日趋势迷你柱状图
                if !appState.weeklyData.isEmpty {
                    Divider()
                    weeklyMiniChart
                }
            } else {
                Text("暂无统计数据")
                    .font(.caption)
                    .foregroundColor(Color(nsColor: .secondaryLabelColor))
                    .padding()
            }
        }
    }

    private var modelMiniChart: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            Text("模型分布")
                .font(.caption)
                .fontWeight(.semibold)

            let total = appState.todayStats?.modelBreakdown.map(\.tokens).reduce(Int64(0), +) ?? 0
            MultiSegmentBar(
                segments: (appState.todayStats?.modelBreakdown ?? []).prefix(4).map { item in
                    let fraction = total > 0 ? Double(item.tokens) / Double(total) : 0
                    return (label: item.name, value: fraction, color: ModelColors.color(for: item.name))
                }
            )
        }
    }

    // MARK: - 7 日趋势迷你柱状图

    private var weeklyMiniChart: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            Text("7 日趋势")
                .font(.caption)
                .fontWeight(.semibold)

            let data = appState.weeklyData
            let maxVal = data.map(\.messageCount).max() ?? 1

            HStack(alignment: .bottom, spacing: 3) {
                ForEach(Array(data.enumerated()), id: \.offset) { index, day in
                    let ratio = maxVal > 0 ? CGFloat(day.messageCount) / CGFloat(maxVal) : 0
                    let isToday = index == data.count - 1

                    VStack(spacing: 2) {
                        // 日期标签（短格式）
                        Text(shortWeekday(from: day.date))
                            .font(.system(size: 8))
                            .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                            .lineLimit(1)

                        // 柱状条
                        RoundedRectangle(cornerRadius: 2)
                            .fill(isToday
                                ? ThemeColors.accent(theme)
                                : ThemeColors.accent(theme).opacity(0.3 + ratio * 0.4))
                            .frame(height: max(4, ratio * 32))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 48)
        }
    }

    /// 从 "yyyy-MM-dd" 字符串提取短星期名
    private func shortWeekday(from dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return "" }
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    // MARK: - 模型区块

    private var modelsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            sectionHeader("模型", icon: "cpu")

            if let stats = appState.todayStats, !stats.modelBreakdown.isEmpty {
                ModelUsageList(breakdown: stats.modelBreakdown)
            } else {
                Text("暂无模型数据")
                    .font(.caption)
                    .foregroundColor(Color(nsColor: .secondaryLabelColor))
            }
        }
    }

    // MARK: - 会话区块

    private var sessionsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            sectionHeader("会话", icon: "bubble.left.and.bubble.right")

            if !appState.currentSessions.isEmpty {
                ForEach(appState.currentSessions) { session in
                    SessionRow(
                        session: session,
                        tokenUsage: sessionUsage(for: session.id),
                        toolCalls: nil
                    )
                }
            } else if !appState.historySessions.isEmpty {
                ForEach(appState.historySessions.prefix(5)) { session in
                    SessionRow(
                        session: session,
                        tokenUsage: sessionUsage(for: session.id),
                        toolCalls: nil
                    )
                }
            } else {
                Text("暂无会话")
                    .font(.caption)
                    .foregroundColor(Color(nsColor: .secondaryLabelColor))
            }
        }
    }

    // MARK: - 工具区块

    private var toolsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            sectionHeader("工具", icon: "wrench.and.screwdriver")

            if let stats = appState.todayStats, stats.toolCallCount > 0 {
                StatCard(title: "工具调用总数", rawValue: Int64(stats.toolCallCount))
            } else {
                Text("暂无工具调用数据")
                    .font(.caption)
                    .foregroundColor(Color(nsColor: .secondaryLabelColor))
            }
        }
    }

    // MARK: - 辅助

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(Color(nsColor: .secondaryLabelColor))
        }
    }

    private var sectionDivider: some View {
        Divider()
            .padding(.vertical, DesignTokens.spacingSM)
    }

    private func sessionUsage(for sessionId: String) -> SessionUsage? {
        return appState.sessionUsages[sessionId]
    }
}

// MARK: - Scroll Offset PreferenceKey

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Section Frame PreferenceKey (Scroll Spy)

private struct SectionFramePreferenceKey: PreferenceKey {
    static let defaultValue: [String: CGFloat] = [:]
    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue()) { $1 }
    }
}

// MARK: - Section Tracking ViewModifier

private struct SectionTracker: ViewModifier {
    let sectionId: String

    func body(content: Content) -> some View {
        content.background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: SectionFramePreferenceKey.self,
                    value: [sectionId: geo.frame(in: .named("dashboardScroll")).minY]
                )
            }
        )
    }
}

extension View {
    func trackSection(_ id: String) -> some View {
        modifier(SectionTracker(sectionId: id))
    }
}
