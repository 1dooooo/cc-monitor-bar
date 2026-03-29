import SwiftUI

struct TimelineView: View {
    @ObservedObject var preferences: AppPreferences
    @EnvironmentObject var appState: AppState
    @Environment(\.colorTheme) private var theme

    @State private var selectedScope: TimelineScope = .day
    @State private var currentDate = Date()

    enum TimelineScope: String, CaseIterable {
        case day = "日"
        case week = "周"
        case month = "月"
    }

    init(preferences: AppPreferences = .shared) {
        self.preferences = preferences
    }

    var body: some View {
        VStack(spacing: 0) {
            dateNavigation

            Divider()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: DesignTokens.spacingSM) {
                    let events = buildEvents()
                    if events.isEmpty {
                        noEventsView
                    } else {
                        ForEach(events) { event in
                            TimelineEventRow(event: event)
                        }
                    }
                }
                .padding(DesignTokens.spacingMD)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ThemeColors.background(theme))
    }

    private var dateNavigation: some View {
        HStack(spacing: DesignTokens.spacingSM) {
            Button(action: previousPeriod) {
                Image(systemName: "chevron.left")
                    .font(.caption)
            }
            .buttonStyle(.borderless)

            Text(formattedDate)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .lineLimit(1)

            Button(action: nextPeriod) {
                Image(systemName: "chevron.right")
                    .font(.caption)
            }
            .buttonStyle(.borderless)

            Picker("范围", selection: $selectedScope) {
                ForEach(TimelineScope.allCases, id: \.self) { scope in
                    Text(scope.rawValue).tag(scope)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 150)
        }
        .padding(.horizontal, DesignTokens.spacingMD)
        .padding(.vertical, DesignTokens.spacingSM)
    }

    private var noEventsView: some View {
        VStack(spacing: DesignTokens.spacingMD) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.system(size: 36))
                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
            Text("暂无事件")
                .font(.subheadline)
                .foregroundColor(Color(nsColor: .secondaryLabelColor))
            Text("选定日期内没有会话记录")
                .font(.caption)
                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignTokens.spacingXL)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: currentDate)
    }

    // MARK: - Build Events

    private func buildEvents() -> [TimelineEvent] {
        var events: [TimelineEvent] = []

        for session in appState.currentSessions {
            let usage = appState.sessionUsages[session.id]
            events.append(TimelineEvent(
                id: "active-\(session.id)",
                time: session.startedAt,
                type: .sessionStart,
                title: "会话启动",
                project: URL(fileURLWithPath: session.projectPath).lastPathComponent,
                tokens: usage?.totalTokens
            ))
        }

        for session in appState.historySessions {
            if isDateInRange(session.startedAt) {
                events.append(TimelineEvent(
                    id: "history-\(session.id)",
                    time: session.startedAt,
                    type: .sessionEnd,
                    title: "会话结束",
                    project: URL(fileURLWithPath: session.projectPath).lastPathComponent,
                    tokens: nil
                ))
            }
        }

        if let stats = appState.todayStats, stats.toolCallCount > 0 {
            events.append(TimelineEvent(
                id: "tool-peak",
                time: Date().addingTimeInterval(-1800),
                type: .toolPeak,
                title: "工具调用统计",
                details: "共 \(stats.toolCallCount) 次工具调用"
            ))
        }

        events.sort { $0.time > $1.time }
        return events
    }

    private func isDateInRange(_ date: Date) -> Bool {
        let calendar = Calendar.current
        switch selectedScope {
        case .day:   return calendar.isDate(date, inSameDayAs: currentDate)
        case .week:  return calendar.isDate(date, equalTo: currentDate, toGranularity: .weekOfYear)
        case .month: return calendar.isDate(date, equalTo: currentDate, toGranularity: .month)
        }
    }

    private func previousPeriod() {
        let cal = Calendar.current
        let component: Calendar.Component = selectedScope == .day ? .day : selectedScope == .week ? .weekOfYear : .month
        withAnimation { currentDate = cal.date(byAdding: component, value: -1, to: currentDate) ?? currentDate }
    }

    private func nextPeriod() {
        let cal = Calendar.current
        let component: Calendar.Component = selectedScope == .day ? .day : selectedScope == .week ? .weekOfYear : .month
        withAnimation { currentDate = cal.date(byAdding: component, value: 1, to: currentDate) ?? currentDate }
    }
}
