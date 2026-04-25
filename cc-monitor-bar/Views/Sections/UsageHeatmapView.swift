import SwiftUI

/// 使用量热力图 — 按日期展示 Token 使用强度
struct UsageHeatmapView: View {
    @State private var dailyStats: [DailyStatsRecord] = []
    @State private var isLoaded = false

    private var maxTokens: Int64 {
        dailyStats.map { $0.totalTokens }.max() ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            HStack {
                Text("使用量热力图")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if !dailyStats.isEmpty {
                    Text("最高: \(maxTokens.formattedTokens)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            if !dailyStats.isEmpty {
                HeatmapGrid(stats: dailyStats, maxTokens: maxTokens)
            } else {
                Text("暂无数据")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(height: 100)
            }
        }
        .onAppear { loadStats() }
    }

    private func loadStats() {
        guard !isLoaded else { return }
        Task {
            do {
                dailyStats = try Repository().fetchDailyStats(days: 30)
                isLoaded = true
            } catch {
                print("加载热力图数据失败: \(error)")
            }
        }
    }
}

/// 热力图网格 — 按日期展示 Token 使用强度
struct HeatmapGrid: View {
    let stats: [DailyStatsRecord]
    let maxTokens: Int64

    private var groupedByMonth: [(month: String, days: [(date: String, tokens: Int64)])] {
        var result: [(month: String, days: [(date: String, tokens: Int64)])] = []
        var currentMonth = ""

        let sorted = stats.sorted { $0.date < $1.date }
        for stat in sorted {
            let month = String(stat.date.prefix(7)) // "2026-04"
            if month != currentMonth {
                result.append((month: month, days: []))
                currentMonth = month
            }
            result[result.count - 1].days.append((date: stat.date, tokens: stat.totalTokens))
        }
        return result
    }

    private func intensityColor(_ tokens: Int64) -> Color {
        guard maxTokens > 0 else { return Color.secondary.opacity(0.1) }
        let ratio = Double(tokens) / Double(maxTokens)
        if ratio > 0.75 { return .red }
        if ratio > 0.5 { return .orange }
        if ratio > 0.25 { return .yellow }
        if ratio > 0.05 { return .green }
        return Color.secondary.opacity(0.1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(groupedByMonth, id: \.month) { monthGroup in
                VStack(alignment: .leading, spacing: 2) {
                    Text(monthGroup.month)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    HStack(spacing: 2) {
                        ForEach(Array(monthGroup.days.enumerated()), id: \.offset) { _, day in
                            DayCell(date: day.date, tokens: day.tokens, color: intensityColor(day.tokens))
                        }
                    }
                }
            }
        }
    }
}

/// 单个日期色块
struct DayCell: View {
    let date: String
    let tokens: Int64
    let color: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: 12, height: 12)
            .overlay(
                Text(date.isEmpty ? "" : String(date.suffix(2)))
                    .font(.system(size: 7))
                    .foregroundColor(.white)
                    .opacity(tokens > 0 ? 1 : 0)
            )
    }
}

#Preview {
    UsageHeatmapView()
        .frame(width: 300)
        .padding()
}
