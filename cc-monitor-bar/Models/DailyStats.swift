import Foundation

struct DailyStats: Identifiable, Codable {
    let date: String
    let projectId: String  // 用于项目级聚合查询
    let messageCount: Int
    let sessionCount: Int
    let toolCallCount: Int
    let inputTokens: Int64
    let outputTokens: Int64
    let cacheTokens: Int64

    var id: String { "\(date)-\(projectId)" }

    /// 注意：totalTokens 始终非负（init 保证 input/output/cache 为 Int64 非可选）
    var totalTokens: Int64 {
        inputTokens + outputTokens + cacheTokens
    }

    /// 有 project 的场景（项目级聚合查询）
    init(date: String, projectId: String, messageCount: Int, sessionCount: Int, toolCallCount: Int, inputTokens: Int64, outputTokens: Int64, cacheTokens: Int64) {
        self.date = date
        self.projectId = projectId
        self.messageCount = messageCount
        self.sessionCount = sessionCount
        self.toolCallCount = toolCallCount
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheTokens = cacheTokens
    }

    /// 无 project 的场景 — 默认 "_global"
    init(date: String, messageCount: Int, sessionCount: Int, toolCallCount: Int, inputTokens: Int64, outputTokens: Int64, cacheTokens: Int64) {
        self.init(date: date, projectId: "_global", messageCount: messageCount, sessionCount: sessionCount, toolCallCount: toolCallCount, inputTokens: inputTokens, outputTokens: outputTokens, cacheTokens: cacheTokens)
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
