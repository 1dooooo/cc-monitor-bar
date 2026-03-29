import Foundation

struct DailyStats: Identifiable, Codable {
    let date: String
    let messageCount: Int
    let sessionCount: Int
    let toolCallCount: Int
    let inputTokens: Int64
    let outputTokens: Int64
    let cacheTokens: Int64

    var id: String { date }

    var totalTokens: Int64 {
        inputTokens + outputTokens + cacheTokens
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: date) else { return date }

        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "今天"
        } else if calendar.isDateInYesterday(date) {
            return "昨天"
        } else {
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "MM/dd"
            return dayFormatter.string(from: date)
        }
    }
}
