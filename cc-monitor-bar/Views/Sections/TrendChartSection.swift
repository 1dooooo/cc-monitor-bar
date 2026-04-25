import SwiftUI

/// 趋势图 — 堆叠柱状图（输入/输出/缓存）
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

            // 堆叠柱状图
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(weeklyData.prefix(7), id: \.date) { day in
                    if day.inputTokens == nil && day.outputTokens == nil && day.cacheTokens == nil {
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
                        StackedBarDay(
                            inputTokens: day.inputTokens ?? 0,
                            outputTokens: day.outputTokens ?? 0,
                            cacheTokens: day.cacheTokens ?? 0,
                            maxValue: maxValue,
                            isToday: isToday(day.date)
                        )
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

            // 图例
            HStack(spacing: DesignTokens.spacingSM) {
                LegendItem(color: .blue, label: "输入")
                LegendItem(color: .green, label: "输出")
                LegendItem(color: .teal, label: "缓存")
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

struct StackedBarDay: View {
    let inputTokens: Int64
    let outputTokens: Int64
    let cacheTokens: Int64
    let maxValue: Int64
    let isToday: Bool

    private var totalTokens: Int64 {
        inputTokens + outputTokens + cacheTokens
    }

    private var inputRatio: CGFloat {
        guard totalTokens > 0 else { return 0 }
        return CGFloat(inputTokens) / CGFloat(totalTokens)
    }

    private var outputRatio: CGFloat {
        guard totalTokens > 0 else { return 0 }
        return CGFloat(outputTokens) / CGFloat(totalTokens)
    }

    private var cacheRatio: CGFloat {
        guard totalTokens > 0 else { return 0 }
        return CGFloat(cacheTokens) / CGFloat(totalTokens)
    }

    var body: some View {
        VStack(spacing: 0) {
            if isToday {
                Circle()
                    .fill(.orange)
                    .frame(width: 4, height: 4)
                    .padding(.bottom, 2)
            }
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.teal)
                    .frame(height: max(barHeight * cacheRatio, 2))
                Rectangle()
                    .fill(Color.green)
                    .frame(height: max(barHeight * outputRatio, 2))
                Rectangle()
                    .fill(Color.blue)
                    .frame(height: max(barHeight * inputRatio, 2))
            }
            .cornerRadius(2)
        }
    }

    private var barHeight: CGFloat {
        guard maxValue > 0 else { return 0 }
        return CGFloat(totalTokens) / CGFloat(maxValue) * 50
    }
}

struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 3) {
            Rectangle()
                .fill(color)
                .frame(width: 8, height: 3)
                .cornerRadius(1)
            Text(label)
                .font(.system(size: 8))
                .foregroundColor(.secondary)
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
