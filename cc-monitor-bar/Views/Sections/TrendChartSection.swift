import SwiftUI

/// 趋势图 — 堆叠柱状图（input/output/cache 三色）
struct TrendChartSection: View {
    let weeklyData: [DailyActivity]
    @EnvironmentObject var preferences: AppPreferences
    @State private var hoveredIndex: Int? = nil

    private var maxValue: Int64 {
        guard !weeklyData.isEmpty else { return 1 }
        return weeklyData.map { $0.totalTokens }.max() ?? 1
    }

    private var barWidth: CGFloat {
        let totalWidth = DesignTokens.popoverWidthStandard - DesignTokens.spacingMD * 2
        let totalSpacing: CGFloat = 4 * 6
        return max((totalWidth - totalSpacing) / 7, 10)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            Text("趋势")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(weeklyData.prefix(7).enumerated()), id: \.element.date) { index, day in
                    StackedBarDay(day: day, maxValue: maxValue, barWidth: barWidth)
                        .onHover { isHovered in
                            hoveredIndex = isHovered ? index : nil
                        }
                        .overlay(alignment: .top) {
                            if hoveredIndex == index && day.totalTokens > 0 {
                                TrendTooltip(day: day)
                                    .transition(.opacity)
                            }
                        }
                }
            }
            .frame(height: 80)

            HStack(spacing: 4) {
                ForEach(weeklyData.prefix(7), id: \.date) { day in
                    Text(dateLabel(for: day.date))
                        .font(.system(size: 8))
                        .foregroundColor(isToday(day.date) ? .orange : .secondary)
                        .frame(width: barWidth)
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

    private func dateLabel(for dateStr: String) -> String {
        if isToday(dateStr) { return "今天" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateStr) else { return dateStr }
        let mf = DateFormatter()
        mf.dateFormat = "MM/dd"
        return mf.string(from: date)
    }
}

struct StackedBarDay: View {
    let day: DailyActivity
    let maxValue: Int64
    let barWidth: CGFloat

    private var inputHeight: CGFloat {
        guard maxValue > 0 else { return 0 }
        return CGFloat(day.inputTokens ?? 0) / CGFloat(maxValue) * 50
    }

    private var outputHeight: CGFloat {
        guard maxValue > 0 else { return 0 }
        return CGFloat(day.outputTokens ?? 0) / CGFloat(maxValue) * 50
    }

    private var cacheHeight: CGFloat {
        guard maxValue > 0 else { return 0 }
        return CGFloat(day.cacheTokens ?? 0) / CGFloat(maxValue) * 50
    }

    private var hasBreakdown: Bool {
        let inp = day.inputTokens ?? 0
        let out = day.outputTokens ?? 0
        let cache = day.cacheTokens ?? 0
        return inp > 0 || out > 0 || cache > 0
    }

    var body: some View {
        VStack(spacing: 0) {
            if day.totalTokens == 0 {
                Rectangle()
                    .fill(Color.secondary.opacity(0.05))
                    .frame(width: barWidth, height: 2)
                    .cornerRadius(2)
            } else if !hasBreakdown {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.blue.opacity(0.6))
                        .frame(width: barWidth, height: max(CGFloat(day.totalTokens) / CGFloat(maxValue) * 50, 2))
                        .cornerRadius(2)
                    Text("估")
                        .font(.system(size: 6))
                        .foregroundColor(.orange)
                        .frame(width: barWidth)
                }
            } else {
                VStack(spacing: 1) {
                    if cacheHeight > 0 {
                        Rectangle()
                            .fill(Color.teal)
                            .frame(width: barWidth, height: max(cacheHeight, 1))
                            .cornerRadius(1)
                    }
                    if outputHeight > 0 {
                        Rectangle()
                            .fill(Color.green)
                            .frame(width: barWidth, height: max(outputHeight, 1))
                            .cornerRadius(1)
                    }
                    if inputHeight > 0 {
                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: barWidth, height: max(inputHeight, 1))
                            .cornerRadius(1)
                    }
                }
            }
        }
    }
}

struct TrendTooltip: View {
    let day: DailyActivity

    private var estimatedCost: Double {
        let breakdown: [(name: String, tokens: Int64, inputTokens: Int64, outputTokens: Int64, cacheTokens: Int64)] = [
            ("claude-sonnet-4", day.totalTokens, day.inputTokens ?? 0, day.outputTokens ?? 0, day.cacheTokens ?? 0)
        ]
        return PricingTable.estimateTotalCost(breakdown: breakdown)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(day.date)
                .font(.system(size: 10, weight: .semibold))
            Divider()
            HStack {
                Text("输入")
                    .font(.system(size: 9))
                    .foregroundColor(.blue)
                Spacer()
                Text((day.inputTokens ?? 0).formattedTokens)
                    .font(.system(size: 9, design: .monospaced))
            }
            HStack {
                Text("输出")
                    .font(.system(size: 9))
                    .foregroundColor(.green)
                Spacer()
                Text((day.outputTokens ?? 0).formattedTokens)
                    .font(.system(size: 9, design: .monospaced))
            }
            HStack {
                Text("缓存")
                    .font(.system(size: 9))
                    .foregroundColor(.teal)
                Spacer()
                Text((day.cacheTokens ?? 0).formattedTokens)
                    .font(.system(size: 9, design: .monospaced))
            }
            Divider()
            HStack {
                Text("估算")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                Spacer()
                Text(String(format: "$%.2f", estimatedCost))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.orange)
            }
        }
        .padding(8)
        .background(Color.primary.opacity(0.9))
        .cornerRadius(6)
        .shadow(radius: 4)
        .offset(y: -4)
    }
}

#Preview {
    TrendChartSection(
        weeklyData: [
            DailyActivity(date: "2026-04-27", messageCount: 50, sessionCount: 3, toolCallCount: 200, inputTokens: 30000, outputTokens: 15000, cacheTokens: 5000),
            DailyActivity(date: "2026-04-28", messageCount: 80, sessionCount: 5, toolCallCount: 350, inputTokens: 48000, outputTokens: 24000, cacheTokens: 8000),
            DailyActivity(date: "2026-04-29", messageCount: 60, sessionCount: 4, toolCallCount: 280, inputTokens: 36000, outputTokens: 18000, cacheTokens: 6000),
            DailyActivity(date: "2026-04-30", messageCount: 100, sessionCount: 6, toolCallCount: 450, inputTokens: 60000, outputTokens: 30000, cacheTokens: 10000),
            DailyActivity(date: "2026-05-01", messageCount: 120, sessionCount: 7, toolCallCount: 520, inputTokens: 72000, outputTokens: 36000, cacheTokens: 12000),
            DailyActivity(date: "2026-05-02", messageCount: 40, sessionCount: 2, toolCallCount: 180, inputTokens: 24000, outputTokens: 12000, cacheTokens: 4000),
            DailyActivity(date: "2026-05-03", messageCount: 90, sessionCount: 5, toolCallCount: 400, inputTokens: 54000, outputTokens: 27000, cacheTokens: 9000),
        ]
    )
    .environmentObject(AppPreferences())
    .frame(width: 300)
    .padding()
}
