import SwiftUI

/// 趋势图 — 单色柱状图（每日 Token 总量）
struct TrendChartSection: View {
    let weeklyData: [DailyActivity]
    @Binding var period: TrendPeriod

    private var maxValue: Int64 {
        guard !weeklyData.isEmpty else { return 1 }
        return weeklyData.map { $0.totalTokens }.max() ?? 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            HStack {
                Text("趋势")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Picker("", selection: $period) {
                    Text("周").tag(TrendPeriod.week)
                    Text("月").tag(TrendPeriod.month)
                }
                .pickerStyle(.segmented)
                .frame(width: 60)
            }

            // 单色柱状图
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(weeklyData.prefix(7), id: \.date) { day in
                    if day.totalTokens == 0 {
                        // 无数据的天显示空占位
                        VStack(spacing: 0) {
                            if isToday(day.date) {
                                Circle()
                                    .fill(.orange)
                                    .frame(width: 4, height: 4)
                                    .padding(.bottom, 2)
                            }
                            Rectangle()
                                .fill(Color.secondary.opacity(0.05))
                                .frame(height: 2)
                                .cornerRadius(2)
                        }
                    } else {
                        SingleBarDay(tokens: day.totalTokens, maxValue: maxValue, isToday: isToday(day.date))
                    }
                }
            }
            .frame(height: 60)

            // 日期标签
            HStack(spacing: 4) {
                ForEach(weeklyData.prefix(7), id: \.date) { day in
                    Text(dayLabel(for: day.date))
                        .font(.system(size: 8))
                        .foregroundColor(isToday(day.date) ? .orange : .secondary)
                }
            }
        }
        .padding(DesignTokens.spacingMD)
        .background(GlassBackground().opacity(0.04))
        .cornerRadius(DesignTokens.radiusMD)
    }

    private func isToday(_ dateStr: String) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateStr) else { return false }
        return Calendar.current.isDateInToday(date)
    }

    private func dayLabel(for dateStr: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateStr) else { return dateStr }

        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        let weekdays = ["一", "二", "三", "四", "五", "六", "日"]
        return calendar.isDateInToday(date) ? "今" : weekdays[(weekday + 5) % 7]
    }
}

struct SingleBarDay: View {
    let tokens: Int64
    let maxValue: Int64
    let isToday: Bool

    private var barHeight: CGFloat {
        guard maxValue > 0 else { return 0 }
        return CGFloat(tokens) / CGFloat(maxValue) * 50
    }

    var body: some View {
        VStack(spacing: 0) {
            if isToday {
                Circle()
                    .fill(.orange)
                    .frame(width: 4, height: 4)
                    .padding(.bottom, 2)
            }
            Rectangle()
                .fill(Color.blue)
                .frame(height: max(barHeight, 2))
                .cornerRadius(2)
        }
    }
}

#Preview {
    TrendChartSection(
        weeklyData: [
            DailyActivity(date: "2026-03-28", messageCount: 50, sessionCount: 3, toolCallCount: 200, inputTokens: 30000, outputTokens: 15000, cacheTokens: 5000),
            DailyActivity(date: "2026-03-29", messageCount: 80, sessionCount: 5, toolCallCount: 350, inputTokens: 48000, outputTokens: 24000, cacheTokens: 8000),
            DailyActivity(date: "2026-03-30", messageCount: 60, sessionCount: 4, toolCallCount: 280, inputTokens: 36000, outputTokens: 18000, cacheTokens: 6000),
            DailyActivity(date: "2026-03-31", messageCount: 100, sessionCount: 6, toolCallCount: 450, inputTokens: 60000, outputTokens: 30000, cacheTokens: 10000),
            DailyActivity(date: "2026-04-01", messageCount: 120, sessionCount: 7, toolCallCount: 520, inputTokens: 72000, outputTokens: 36000, cacheTokens: 12000),
            DailyActivity(date: "2026-04-02", messageCount: 40, sessionCount: 2, toolCallCount: 180, inputTokens: 24000, outputTokens: 12000, cacheTokens: 4000),
            DailyActivity(date: "2026-04-03", messageCount: 90, sessionCount: 5, toolCallCount: 400, inputTokens: 54000, outputTokens: 27000, cacheTokens: 9000),
        ],
        period: .constant(.week)
    )
    .frame(width: 300)
    .padding()
}
