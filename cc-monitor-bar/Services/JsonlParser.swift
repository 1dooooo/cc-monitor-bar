import Foundation

// MARK: - JSONL Parsing Internals

// MARK: - Key structs

/// JSONL 增量索引的日期范围键
struct JsonlRangeKey: Hashable {
    let startEpochSecond: Int64?
    let endEpochSecond: Int64?

    init(dateRange: DateInterval?) {
        if let dateRange {
            startEpochSecond = Int64(dateRange.start.timeIntervalSince1970)
            endEpochSecond = Int64(dateRange.end.timeIntervalSince1970)
        } else {
            startEpochSecond = nil
            endEpochSecond = nil
        }
    }
}

struct IndexedMessageUsage {
    var model: String
    var input: Int64
    var output: Int64
    var cacheRead: Int64
    var cacheCreate: Int64
}

struct UsageAccumulator {
    var messageCount = 0
    var toolUseIds = Set<String>()
    var anonymousToolUseFingerprints = Set<String>()
    var toolCounts: [String: Int] = [:]
    var contextTokens: Int64 = 0
    var messages: [String: IndexedMessageUsage] = [:]
    var lastMessageTimestamp: Date?

    func dedupKeys() -> [String] {
        var result = toolUseIds.map { "id:\($0)" }
        result.append(contentsOf: anonymousToolUseFingerprints.map { "fp:\($0)" })
        return result
    }

    func buildSessionUsage() -> SessionUsage {
        var totalInput: Int64 = 0
        var totalOutput: Int64 = 0
        var totalCacheRead: Int64 = 0
        var totalCacheCreate: Int64 = 0
        var modelTokens: [String: Int64] = [:]
        var modelBreakdowns: [String: ModelTokenBreakdown] = [:]

        for (_, msg) in messages {
            totalInput += msg.input
            totalOutput += msg.output
            totalCacheRead += msg.cacheRead
            totalCacheCreate += msg.cacheCreate

            let tokens = msg.input + msg.output + msg.cacheRead + msg.cacheCreate
            modelTokens[msg.model, default: 0] += tokens

            let existing = modelBreakdowns[msg.model] ?? .zero
            modelBreakdowns[msg.model] = existing.merging(
                ModelTokenBreakdown(
                    inputTokens: msg.input,
                    outputTokens: msg.output,
                    cacheReadTokens: msg.cacheRead,
                    cacheCreationTokens: msg.cacheCreate
                )
            )
        }

        return SessionUsage(
            inputTokens: totalInput,
            outputTokens: totalOutput,
            cacheReadTokens: totalCacheRead,
            cacheCreationTokens: totalCacheCreate,
            messageCount: messageCount,
            toolCallCount: toolUseIds.count + anonymousToolUseFingerprints.count,
            models: modelTokens,
            modelBreakdowns: modelBreakdowns,
            toolCounts: toolCounts,
            contextTokens: contextTokens,
            lastMessageTimestamp: lastMessageTimestamp
        )
    }
}

/// SQLite 持久化的文件索引条目
struct FileUsageIndexEntry {
    var offset: UInt64
    var carry: Data
    var probeAtOffset: Data
    var fileSize: UInt64
    var modifiedAt: TimeInterval
    var lastAccessAt: TimeInterval
    var accumulator: UsageAccumulator
}

// MARK: - JSONL Parser

/// 纯 JSONL 解析逻辑 — 不依赖任何文件系统或数据库
struct JsonlParser {

    private static let iso8601WithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601Basic: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    // MARK: - Line-level parsing

    /// 按行拆分 JSONL，逐行消费；返回未完成的数据碎片
    static func consumeChunk(
        _ data: Data,
        dateRange: DateInterval?,
        accumulator: inout UsageAccumulator
    ) -> Data {
        guard !data.isEmpty else { return Data() }

        var lineStart = data.startIndex
        var idx = data.startIndex
        while idx < data.endIndex {
            if data[idx] == 0x0A {
                var lineData = data[lineStart..<idx]
                if lineData.last == 0x0D {
                    lineData = lineData.dropLast()
                }
                consumeLine(Data(lineData), dateRange: dateRange, accumulator: &accumulator)
                lineStart = data.index(after: idx)
            }
            idx = data.index(after: idx)
        }

        if lineStart < data.endIndex {
            return Data(data[lineStart..<data.endIndex])
        }
        return Data()
    }

    /// 尝试将尾部数据作为完整 JSON 解析
    static func tryConsumeTrailingAsCompleteJson(
        _ trailing: Data,
        dateRange: DateInterval?,
        accumulator: inout UsageAccumulator
    ) -> Data {
        guard !trailing.isEmpty else { return Data() }
        guard (try? JSONSerialization.jsonObject(with: trailing)) != nil else {
            return trailing
        }
        consumeLine(trailing, dateRange: dateRange, accumulator: &accumulator)
        return Data()
    }

    /// 消费单行 JSONL
    static func consumeLine(
        _ lineData: Data,
        dateRange: DateInterval?,
        accumulator: inout UsageAccumulator
    ) {
        guard !lineData.isEmpty,
              let entry = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
            return
        }

        let timestamp = parseTimestamp(from: entry)
        if let ts = timestamp {
            if accumulator.lastMessageTimestamp == nil || ts > accumulator.lastMessageTimestamp! {
                accumulator.lastMessageTimestamp = ts
            }
        }

        if let dateRange {
            guard let ts = timestamp, dateRange.contains(ts) else {
                return
            }
        }

        let type = entry["type"] as? String ?? ""
        if type == "user", isHumanUserMessage(entry: entry) {
            accumulator.messageCount += 1
        }

        guard type == "assistant",
              let message = entry["message"] as? [String: Any],
              let usage = message["usage"] as? [String: Any] else {
            return
        }

        let input = parseToInt64(usage["input_tokens"])
        let output = parseToInt64(usage["output_tokens"])
        let cacheRead = parseToInt64(usage["cache_read_input_tokens"])
        let cacheCreate = parseToInt64(usage["cache_creation_input_tokens"])
        let model = message["model"] as? String ?? "unknown"
        let messageKey = dedupKey(entry: entry, message: message)

        if model == "<synthetic>" || messageKey.isEmpty {
            return
        }

        if let existing = accumulator.messages[messageKey] {
            accumulator.messages[messageKey] = IndexedMessageUsage(
                model: existing.model == "unknown" ? model : existing.model,
                input: max(existing.input, input),
                output: max(existing.output, output),
                cacheRead: max(existing.cacheRead, cacheRead),
                cacheCreate: max(existing.cacheCreate, cacheCreate)
            )
        } else {
            accumulator.messages[messageKey] = IndexedMessageUsage(
                model: model,
                input: input,
                output: output,
                cacheRead: cacheRead,
                cacheCreate: cacheCreate
            )
            accumulator.contextTokens += input
        }

        if let content = message["content"] as? [[String: Any]] {
            for block in content where block["type"] as? String == "tool_use" {
                let toolName = block["name"] as? String ?? "unknown"
                if let toolId = block["id"] as? String, !toolId.isEmpty {
                    accumulator.toolUseIds.insert(toolId)
                    accumulator.toolCounts[toolName, default: 0] += 1
                } else {
                    accumulator.anonymousToolUseFingerprints.insert(
                        toolUseFingerprint(block: block, entry: entry, message: message)
                    )
                    accumulator.toolCounts[toolName, default: 0] += 1
                }
            }
        }
    }

    // MARK: - Helper parsing functions

    static func parseTimestamp(from entry: [String: Any]) -> Date? {
        if let date = parseDate(fromRawTimestamp: entry["timestamp"]) {
            return date
        }
        if let message = entry["message"] as? [String: Any],
           let date = parseDate(fromRawTimestamp: message["timestamp"]) {
            return date
        }
        if let snapshot = entry["snapshot"] as? [String: Any],
           let date = parseDate(fromRawTimestamp: snapshot["timestamp"]) {
            return date
        }
        return nil
    }

    static func isHumanUserMessage(entry: [String: Any]) -> Bool {
        guard let message = entry["message"] as? [String: Any] else { return false }
        let content = message["content"]
        if let text = content as? String {
            return isVisibleText(text)
        }
        if let blocks = content as? [Any] {
            for block in blocks {
                if let text = block as? String, isVisibleText(text) {
                    return true
                }
                guard let dict = block as? [String: Any] else { continue }
                let type = dict["type"] as? String

                if type == "tool_result" || type == "thinking" || type == "redacted_thinking" {
                    continue
                }
                if type == "text", let blockText = dict["text"] as? String, isVisibleText(blockText) {
                    return true
                }
                if type == "image" || type == "image_url" || type == "file" || type == "input_text" {
                    return true
                }
                if let blockText = dict["text"] as? String, isVisibleText(blockText) {
                    return true
                }
            }
        }
        return false
    }

    static func dedupKey(entry: [String: Any], message: [String: Any]) -> String {
        if let messageId = message["id"] as? String, !messageId.isEmpty {
            if let requestId = entry["requestId"] as? String, !requestId.isEmpty {
                return "\(messageId):\(requestId)"
            }
            return messageId
        }
        if let requestId = entry["requestId"] as? String, !requestId.isEmpty {
            return requestId
        }
        return (entry["uuid"] as? String) ?? ""
    }

    static func toolUseFingerprint(
        block: [String: Any],
        entry: [String: Any],
        message: [String: Any]
    ) -> String {
        var components: [String] = []
        if let name = block["name"] as? String {
            components.append("name=\(name)")
        }

        if let input = block["input"] {
            if JSONSerialization.isValidJSONObject(input),
               let data = try? JSONSerialization.data(withJSONObject: input, options: [.sortedKeys]),
               let json = String(data: data, encoding: .utf8) {
                components.append("input=\(json)")
            } else {
                components.append("input=\(String(describing: input))")
            }
        }

        components.append("msg=\(dedupKey(entry: entry, message: message))")
        return components.joined(separator: "|")
    }

    // MARK: - Internal helpers

    private static func parseDate(fromRawTimestamp raw: Any?) -> Date? {
        guard let raw else { return nil }
        if let string = raw as? String {
            if let parsed = iso8601WithFractionalSeconds.date(from: string) {
                return parsed
            }
            return iso8601Basic.date(from: string)
        }

        let seconds: TimeInterval?
        if let value = raw as? Int64 {
            seconds = value > 1_000_000_000_000 ? TimeInterval(value) / 1000.0 : TimeInterval(value)
        } else if let value = raw as? Int {
            seconds = value > 1_000_000_000_000 ? TimeInterval(value) / 1000.0 : TimeInterval(value)
        } else if let value = raw as? Double {
            seconds = value > 1_000_000_000_000 ? value / 1000.0 : value
        } else if let value = raw as? NSNumber {
            let doubleValue = value.doubleValue
            seconds = doubleValue > 1_000_000_000_000 ? doubleValue / 1000.0 : doubleValue
        } else {
            seconds = nil
        }

        guard let seconds else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }

    private static func isVisibleText(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && !trimmed.hasPrefix("<")
    }

    private static func parseToInt64(_ value: Any?) -> Int64 {
        guard let v = value else { return 0 }
        if let i = v as? Int { return Int64(i) }
        if let i = v as? Int64 { return i }
        if let d = v as? Double { return Int64(d) }
        return 0
    }
}
