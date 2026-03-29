import Foundation

struct ToolCall: Identifiable, Codable {
    let id: Int64
    let sessionId: String
    let timestamp: Date
    let toolName: String
    let durationMs: Int64?
    let success: Bool

    var toolIcon: String {
        switch toolName {
        case "Bash": return "terminal"
        case "Read": return "doc.text"
        case "Write": return "pencil.and.list"
        case "Glob": return "folder"
        case "Grep": return "magnifyingglass"
        case "Edit": return "pencil"
        default: return "wrench"
        }
    }
}
