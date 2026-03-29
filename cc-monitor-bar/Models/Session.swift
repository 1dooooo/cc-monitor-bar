import Foundation

struct Session: Identifiable, Codable {
    let id: String
    let pid: Int32
    let projectPath: String
    let projectId: String
    let startedAt: Date
    var endedAt: Date?
    var durationMs: Int64
    var messageCount: Int
    var toolCallCount: Int
    let entrypoint: String

    var isRunning: Bool {
        endedAt == nil
    }

    var durationFormatted: String {
        let seconds = Int(durationMs / 1000)
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
