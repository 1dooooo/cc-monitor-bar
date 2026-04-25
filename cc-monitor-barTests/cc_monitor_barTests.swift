//
//  cc_monitor_barTests.swift
//  cc-monitor-barTests
//
//  Created by ido on 2026/3/29.
//

import Foundation
import Testing
@testable import cc_monitor_bar

struct cc_monitor_barTests {
    private func makeTempHome() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("cc-monitor-bar-tests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func iso8601(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    @Test func sessionUsageDeduplicatesStreamingAssistantMessages() throws {
        let tempHome = try makeTempHome()
        defer { try? FileManager.default.removeItem(at: tempHome) }

        let paths = ClaudeDataPaths(baseDir: tempHome.path)
        let reader = ClaudeDataReader(paths: paths)
        let cwd = "/Users/test/project"
        let sessionId = "session-1"
        let projectDir = "\(paths.projectsDir)/-Users-test-project"
        try FileManager.default.createDirectory(atPath: projectDir, withIntermediateDirectories: true)

        let now = Date()
        let t1 = iso8601(now)
        let t2 = iso8601(now.addingTimeInterval(1))
        let t3 = iso8601(now.addingTimeInterval(2))
        let t4 = iso8601(now.addingTimeInterval(3))
        let t5 = iso8601(now.addingTimeInterval(4))

        let lines = [
            #"{"type":"user","timestamp":"\#(t1)","message":{"role":"user","content":"hello"}}"#,
            #"{"type":"assistant","timestamp":"\#(t2)","requestId":"req-1","message":{"id":"msg-1","model":"modelA","usage":{"input_tokens":100,"output_tokens":0,"cache_read_input_tokens":0,"cache_creation_input_tokens":0},"content":[{"type":"tool_use","id":"tool-1","name":"Read"}]}}"#,
            #"{"type":"assistant","timestamp":"\#(t3)","requestId":"req-1","message":{"id":"msg-1","model":"modelA","usage":{"input_tokens":5,"output_tokens":20,"cache_read_input_tokens":30,"cache_creation_input_tokens":40},"stop_reason":"end_turn","content":[{"type":"tool_use","id":"tool-1","name":"Read"}]}}"#,
            #"{"type":"assistant","timestamp":"\#(t4)","requestId":"req-2","message":{"id":"msg-2","model":"modelB","usage":{"input_tokens":10,"output_tokens":2,"cache_read_input_tokens":0,"cache_creation_input_tokens":0},"stop_reason":"end_turn"}}"#,
            #"{"type":"user","timestamp":"\#(t5)","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"tool-1","content":"ok"}]}}"#
        ]

        let filePath = "\(projectDir)/\(sessionId).jsonl"
        try lines.joined(separator: "\n").write(toFile: filePath, atomically: true, encoding: .utf8)

        let usage = reader.readSessionUsage(cwd: cwd, sessionId: sessionId)

        #expect(usage.messageCount == 1)
        #expect(usage.toolCallCount == 1)
        #expect(usage.inputTokens == 110)
        #expect(usage.outputTokens == 22)
        #expect(usage.cacheReadTokens == 30)
        #expect(usage.cacheCreationTokens == 40)
        #expect(usage.models["modelA"] == 190)
        #expect(usage.models["modelB"] == 12)
    }

    @Test func todayUsageFiltersByEntryTimestamp() throws {
        let tempHome = try makeTempHome()
        defer { try? FileManager.default.removeItem(at: tempHome) }

        let paths = ClaudeDataPaths(baseDir: tempHome.path)
        let reader = ClaudeDataReader(paths: paths)

        let projectDir = "\(paths.projectsDir)/-Users-test-today"
        try FileManager.default.createDirectory(atPath: projectDir, withIntermediateDirectories: true)

        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        let oldTs = iso8601(yesterday)
        let todayTs1 = iso8601(now)
        let todayTs2 = iso8601(now.addingTimeInterval(1))

        let lines = [
            #"{"type":"assistant","timestamp":"\#(oldTs)","requestId":"old-req","message":{"id":"old-msg","model":"oldModel","usage":{"input_tokens":1000,"output_tokens":500,"cache_read_input_tokens":300,"cache_creation_input_tokens":200},"stop_reason":"end_turn","content":[{"type":"tool_use","id":"tool-old","name":"Read"}]}}"#,
            #"{"type":"user","timestamp":"\#(todayTs1)","message":{"role":"user","content":"today prompt"}}"#,
            #"{"type":"assistant","timestamp":"\#(todayTs2)","requestId":"today-req","message":{"id":"today-msg","model":"todayModel","usage":{"input_tokens":10,"output_tokens":5,"cache_read_input_tokens":2,"cache_creation_input_tokens":0},"stop_reason":"end_turn","content":[{"type":"tool_use","id":"tool-today","name":"Read"}]}}"#
        ]

        try lines.joined(separator: "\n").write(
            toFile: "\(projectDir)/today-session.jsonl",
            atomically: true,
            encoding: .utf8
        )

        let usage = reader.readTodayUsage()

        #expect(usage.messageCount == 1)
        #expect(usage.sessionCount == 1)
        #expect(usage.toolCallCount == 1)
        #expect(usage.inputTokens == 10)
        #expect(usage.outputTokens == 5)
        #expect(usage.cacheTokens == 2)
        #expect(usage.totalTokens == 17)
        #expect(usage.modelBreakdown.first?.name == "todayModel")
        #expect(usage.modelBreakdown.first?.tokens == 17)
    }

    @Test func sessionUsageFallsBackToOtherProjectRootsWhenCwdMappingMisses() throws {
        let tempHome = try makeTempHome()
        defer { try? FileManager.default.removeItem(at: tempHome) }

        let paths = ClaudeDataPaths(baseDir: tempHome.path)
        let reader = ClaudeDataReader(paths: paths)

        let sessionId = "fallback-session"
        let fallbackProjectDir = "\(paths.xcodeProjectsDir)/xcode-project"
        try FileManager.default.createDirectory(atPath: fallbackProjectDir, withIntermediateDirectories: true)

        let now = Date()
        let t1 = iso8601(now)
        let t2 = iso8601(now.addingTimeInterval(1))
        let lines = [
            #"{"type":"user","timestamp":"\#(t1)","message":{"role":"user","content":"from xcode root"}}"#,
            #"{"type":"assistant","timestamp":"\#(t2)","message":{"id":"msg-fallback","model":"modelX","usage":{"input_tokens":9,"output_tokens":4,"cache_read_input_tokens":1,"cache_creation_input_tokens":0},"stop_reason":"end_turn"}}"#
        ]

        try lines.joined(separator: "\n").write(
            toFile: "\(fallbackProjectDir)/\(sessionId).jsonl",
            atomically: true,
            encoding: .utf8
        )

        // cwd 与 xcode-project 不匹配，验证会话可被兜底发现
        let usage = reader.readSessionUsage(cwd: "/Users/test/not-matching", sessionId: sessionId)

        #expect(usage.messageCount == 1)
        #expect(usage.inputTokens == 9)
        #expect(usage.outputTokens == 4)
        #expect(usage.cacheReadTokens == 1)
        #expect(usage.totalTokens == 14)
        #expect(usage.models["modelX"] == 14)
    }

    @Test func sessionUsageCountsUserTextBlocksInsideArrayContent() throws {
        let tempHome = try makeTempHome()
        defer { try? FileManager.default.removeItem(at: tempHome) }

        let paths = ClaudeDataPaths(baseDir: tempHome.path)
        let reader = ClaudeDataReader(paths: paths)
        let cwd = "/Users/test/project"
        let sessionId = "session-array-content"
        let projectDir = "\(paths.projectsDir)/-Users-test-project"
        try FileManager.default.createDirectory(atPath: projectDir, withIntermediateDirectories: true)

        let now = Date()
        let t1 = iso8601(now)
        let t2 = iso8601(now.addingTimeInterval(1))
        let t3 = iso8601(now.addingTimeInterval(2))
        let lines = [
            #"{"type":"user","timestamp":"\#(t1)","message":{"role":"user","content":[{"type":"text","text":"hello from block"}]}}"#,
            #"{"type":"user","timestamp":"\#(t2)","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"tool-1","content":"ok"}]}}"#,
            #"{"type":"assistant","timestamp":"\#(t3)","message":{"id":"msg-array","model":"modelA","usage":{"input_tokens":3,"output_tokens":2,"cache_read_input_tokens":0,"cache_creation_input_tokens":0},"stop_reason":"end_turn"}}"#
        ]

        try lines.joined(separator: "\n").write(
            toFile: "\(projectDir)/\(sessionId).jsonl",
            atomically: true,
            encoding: .utf8
        )

        let usage = reader.readSessionUsage(cwd: cwd, sessionId: sessionId)

        #expect(usage.messageCount == 1)
        #expect(usage.totalTokens == 5)
    }

    @Test func sessionUsageUpdatesCorrectlyAfterFileAppend() throws {
        let tempHome = try makeTempHome()
        defer { try? FileManager.default.removeItem(at: tempHome) }

        let paths = ClaudeDataPaths(baseDir: tempHome.path)
        let reader = ClaudeDataReader(paths: paths)
        let cwd = "/Users/test/project"
        let sessionId = "session-append"
        let projectDir = "\(paths.projectsDir)/-Users-test-project"
        try FileManager.default.createDirectory(atPath: projectDir, withIntermediateDirectories: true)

        let now = Date()
        let t1 = iso8601(now)
        let t2 = iso8601(now.addingTimeInterval(1))
        let t3 = iso8601(now.addingTimeInterval(2))

        let initialLines = [
            #"{"type":"user","timestamp":"\#(t1)","message":{"role":"user","content":"first prompt"}}"#,
            #"{"type":"assistant","timestamp":"\#(t2)","requestId":"req-1","message":{"id":"msg-1","model":"modelA","usage":{"input_tokens":10,"output_tokens":3,"cache_read_input_tokens":0,"cache_creation_input_tokens":0},"stop_reason":"end_turn"}}"#
        ]

        let filePath = "\(projectDir)/\(sessionId).jsonl"
        try initialLines.joined(separator: "\n").write(toFile: filePath, atomically: true, encoding: .utf8)

        let firstUsage = reader.readSessionUsage(cwd: cwd, sessionId: sessionId)
        #expect(firstUsage.messageCount == 1)
        #expect(firstUsage.totalTokens == 13)

        let appendedLine = "\n" + #"{"type":"assistant","timestamp":"\#(t3)","requestId":"req-2","message":{"id":"msg-2","model":"modelA","usage":{"input_tokens":7,"output_tokens":2,"cache_read_input_tokens":1,"cache_creation_input_tokens":0},"stop_reason":"end_turn"}}"#
        if let handle = FileHandle(forWritingAtPath: filePath) {
            defer { try? handle.close() }
            try handle.seekToEnd()
            if let data = appendedLine.data(using: .utf8) {
                try handle.write(contentsOf: data)
            }
        } else {
            Issue.record("无法追加写入测试 JSONL")
        }

        let secondUsage = reader.readSessionUsage(cwd: cwd, sessionId: sessionId)
        #expect(secondUsage.messageCount == 1)
        #expect(secondUsage.inputTokens == 17)
        #expect(secondUsage.outputTokens == 5)
        #expect(secondUsage.cacheReadTokens == 1)
        #expect(secondUsage.totalTokens == 23)
    }

    @Test func dataQualityStatusClassifiesLargeDiffAsCritical() {
        let todayUsage: (
            messageCount: Int,
            sessionCount: Int,
            toolCallCount: Int,
            totalTokens: Int64,
            inputTokens: Int64,
            outputTokens: Int64,
            cacheTokens: Int64,
            modelBreakdown: [(name: String, tokens: Int64, inputTokens: Int64, outputTokens: Int64, cacheTokens: Int64)]
        ) = (
            messageCount: 50,
            sessionCount: 4,
            toolCallCount: 30,
            totalTokens: 10_000,
            inputTokens: 6_000,
            outputTokens: 3_000,
            cacheTokens: 1_000,
            modelBreakdown: []
        )

        let cache = StatsCache(
            version: 2,
            lastComputedDate: AppState.todayDateString(),
            dailyActivity: [
                DailyActivity(
                    date: AppState.todayDateString(),
                    messageCount: 5,
                    sessionCount: 1,
                    toolCallCount: 3,
                    inputTokens: 200,
                    outputTokens: 100,
                    cacheTokens: 50
                )
            ],
            dailyModelTokens: [],
            modelUsage: [:]
        )

        let status = AppState.buildDataQualityStatus(
            todayUsage: todayUsage,
            cache: cache,
            todayStr: AppState.todayDateString()
        )

        #expect(status.level == .critical)
    }

}
