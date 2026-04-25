import Foundation

/// Claude Code Hook 事件模型
struct HookEvent: Codable {
    let tool: String           // 工具名 (e.g. "Bash", "Read", "Edit")
    let sessionId: String      // 当前会话 ID
    let timestamp: Date        // 事件时间
    let status: String         // "preToolUse" / "postToolUse"
    let input: String?         // 工具输入 (可选)

    enum CodingKeys: String, CodingKey {
        case tool, session, timestamp, status, input
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tool = try container.decode(String.self, forKey: .tool)
        sessionId = try container.decode(String.self, forKey: .session)
        timestamp = Date()
        status = try container.decode(String.self, forKey: .status)
        input = try container.decodeIfPresent(String.self, forKey: .input)
    }

    init(tool: String, sessionId: String, timestamp: Date, status: String, input: String? = nil) {
        self.tool = tool
        self.sessionId = sessionId
        self.timestamp = timestamp
        self.status = status
        self.input = input
    }

    var isPreTool: Bool { status == "preToolUse" }
    var isPostTool: Bool { status == "postToolUse" }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(tool, forKey: .tool)
        try container.encode(sessionId, forKey: .session)
        try container.encode(status, forKey: .status)
        try container.encode(input, forKey: .input)
    }
}
