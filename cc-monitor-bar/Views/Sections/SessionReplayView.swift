import SwiftUI

/// 会话回放 — 逐步展示对话时间线
struct SessionReplayView: View {
    let session: SessionRecord
    @State private var currentIndex = 0
    @State private var isPlaying = false
    @State private var playTimer: Timer?

    // 模拟时间线数据（从 SessionRecord 生成）
    private var timelineEvents: [TimelineEvent] {
        [
            TimelineEvent(type: .user, content: "用户消息", timestamp: session.startedAt),
            TimelineEvent(type: .assistant, content: "AI 回复", timestamp: session.startedAt.addingTimeInterval(30)),
            TimelineEvent(type: .toolCall, content: "工具调用 (\(session.toolCallCount) 次)", timestamp: session.startedAt.addingTimeInterval(45)),
            TimelineEvent(type: .tokenUsage, content: "Token 用量: \(session.totalTokens.formattedTokens)", timestamp: session.startedAt.addingTimeInterval(60)),
            TimelineEvent(type: .context, content: "Context: \(session.contextTokens.formattedTokens)", timestamp: session.startedAt.addingTimeInterval(90)),
        ]
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 基本信息
                SessionDetailInfo(session: session)
                    .padding(.bottom, DesignTokens.spacingMD)

                // 时间线
                ScrollView {
                    VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                        ForEach(Array(timelineEvents.enumerated()), id: \.offset) { index, event in
                            TimelineEventRow(event: event, isRevealed: currentIndex >= index)
                        }
                    }
                    .padding()
                }

                // 播放控件
                PlaybackControls(
                    totalSteps: timelineEvents.count,
                    currentIndex: currentIndex,
                    isPlaying: isPlaying,
                    onPlay: startPlayback,
                    onPause: pausePlayback,
                    onNext: nextStep,
                    onReset: resetPlayback
                )
                .padding(DesignTokens.spacingMD)
                .background(Color.secondary.opacity(0.05))
            }
            .navigationTitle(session.projectPath.isEmpty ? "会话回放" : session.projectPath)
        }
    }

    private func startPlayback() {
        isPlaying = true
        playTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
            if currentIndex < timelineEvents.count - 1 {
                currentIndex += 1
            } else {
                pausePlayback()
            }
        }
    }

    private func pausePlayback() {
        isPlaying = false
        playTimer?.invalidate()
        playTimer = nil
    }

    private func nextStep() {
        if currentIndex < timelineEvents.count - 1 {
            currentIndex += 1
        }
    }

    private func resetPlayback() {
        pausePlayback()
        currentIndex = 0
    }
}

/// 时间线事件
struct TimelineEvent {
    let type: EventType
    let content: String
    let timestamp: Date

    enum EventType {
        case user, assistant, toolCall, tokenUsage, context
    }
}

/// 时间线事件行
struct TimelineEventRow: View {
    let event: TimelineEvent
    let isRevealed: Bool

    private var iconColor: Color {
        switch event.type {
        case .user: return .blue
        case .assistant: return .green
        case .toolCall: return .orange
        case .tokenUsage: return .purple
        case .context: return .red
        }
    }

    var body: some View {
        HStack(spacing: DesignTokens.spacingSM) {
            Circle()
                .fill(isRevealed ? iconColor : Color.secondary.opacity(0.3))
                .frame(width: 8, height: 8)

            Text(event.content)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(isRevealed ? .primary : .secondary.opacity(0.5))
                .lineLimit(1)

            Spacer()

            Text(event.timestamp.formatted(date: .omitted, time: .shortened))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .opacity(isRevealed ? 1 : 0.4)
    }
}

/// 回放控件
struct PlaybackControls: View {
    let totalSteps: Int
    let currentIndex: Int
    let isPlaying: Bool
    let onPlay: () -> Void
    let onPause: () -> Void
    let onNext: () -> Void
    let onReset: () -> Void

    var body: some View {
        HStack(spacing: DesignTokens.spacingMD) {
            Button(action: onReset) {
                Image(systemName: "backward.end")
            }

            Button(action: isPlaying ? onPause : onPlay) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
            }
            .disabled(currentIndex >= totalSteps && !isPlaying)

            Button(action: onNext) {
                Image(systemName: "forward.end")
            }

            Spacer()

            Text("\(currentIndex + 1) / \(totalSteps)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

/// 会话详情信息
struct SessionDetailInfo: View {
    let session: SessionRecord

    var body: some View {
        VStack(spacing: DesignTokens.spacingSM) {
            InfoRow(label: "ID", value: String(session.id.prefix(8)))
            InfoRow(label: "项目", value: session.projectPath)
            InfoRow(label: "运行时间", value: session.durationFormatted())
            InfoRow(label: "消息数", value: "\(session.messageCount)")
            InfoRow(label: "工具调用", value: "\(session.toolCallCount)")
            InfoRow(label: "总 Token", value: session.totalTokens.formattedTokens)
            InfoRow(label: "Context", value: session.contextTokens.formattedTokens)
        }
        .padding()
    }
}

#Preview {
    SessionReplayView(
        session: SessionRecord(
            id: "abc123", pid: 12345, projectPath: "/Users/ido/project",
            projectId: "my-project", startedAt: Date().addingTimeInterval(-3600),
            endedAt: Date(), durationMs: 3600000,
            messageCount: 23, toolCallCount: 142, entrypoint: "cli",
            inputTokens: 120_000, outputTokens: 45_000,
            cacheReadTokens: 30_000, cacheCreationTokens: 5_000, contextTokens: 142_000
        )
    )
}
