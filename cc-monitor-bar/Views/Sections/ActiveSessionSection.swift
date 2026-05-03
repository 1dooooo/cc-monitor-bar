import SwiftUI

/// 活跃会话列表
struct ActiveSessionSection: View {
    let sessions: [Session]
    let usages: [String: SessionUsage]
    @State private var selectedSession: Session?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            HStack {
                Text("活跃会话")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Circle()
                    .fill(.green)
                    .frame(width: 6, height: 6)
            }

            ForEach(sessions, id: \.id) { session in
                SessionCard(session: session, usage: usages[session.id])
                    .onTapGesture {
                        selectedSession = session
                    }
            }
        }
        .padding(DesignTokens.spacingMD)
        .background(GlassBackground().opacity(0.04))
        .cornerRadius(DesignTokens.radiusMD)
        .sheet(item: $selectedSession) { session in
            SessionDetailSheet(session: session, usage: usages[session.id] ?? .zero)
        }
    }
}

struct SessionCard: View {
    let session: Session
    let usage: SessionUsage?

    var body: some View {
        VStack(spacing: DesignTokens.spacingXS) {
            HStack(spacing: DesignTokens.spacingSM) {
                Circle()
                    .fill(.green)
                    .frame(width: 6, height: 6)
                Text(projectName(session.projectPath))
                    .font(.system(size: 10, weight: .medium))
                Spacer()
                Text("\(session.messageCount) msg")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                Text(session.durationFormatted)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }

            HStack(spacing: DesignTokens.spacingMD) {
                HStack(spacing: 4) {
                    Text("↑")
                        .font(.system(size: 9))
                        .foregroundColor(.blue)
                    if let usage {
                        Text(usage.inputTokens.formattedTokens)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(.blue)
                    } else {
                        Text("--")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                }
                HStack(spacing: 4) {
                    Text("↓")
                        .font(.system(size: 9))
                        .foregroundColor(.green)
                    if let usage {
                        Text(usage.outputTokens.formattedTokens)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(.green)
                    } else {
                        Text("--")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                }
                Spacer()
                if let usage {
                    Text(usage.totalTokens.formattedTokens)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                } else {
                    Text("--")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }

            if let usage = usage, usage.contextTokens > 0 {
                ContextLabel(contextTokens: usage.contextTokens)
            }
        }
        .padding(DesignTokens.spacingSM)
        .background(Color.secondary.opacity(0.04))
        .cornerRadius(DesignTokens.radiusSM)
    }

    private func projectName(_ path: String) -> String {
        let components = path.components(separatedBy: "/")
        return components.last ?? path
    }
}

/// Context Window 累计使用量
///
/// 显示累计值（多次消息的 input tokens 累加），不显示百分比
/// 因为 contextTokens 是累计值而非当前窗口大小
struct ContextLabel: View {
    let contextTokens: Int64

    var body: some View {
        HStack(spacing: 4) {
            Text("Context")
                .font(.system(size: 8))
                .foregroundColor(.secondary)
            Text(contextTokens.formattedTokens)
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(.top, 2)
    }
}

#Preview {
    ActiveSessionSection(
        sessions: [
            Session(
                id: "abc123",
                pid: 12345,
                projectPath: "/Users/ido/project/mac/cc-monitor-bar",
                projectId: "cc-monitor-bar",
                startedAt: Date().addingTimeInterval(-3600),
                endedAt: nil,
                durationMs: 3600000,
                messageCount: 23,
                toolCallCount: 142,
                entrypoint: "cli"
            )
        ],
        usages: [
            "abc123": SessionUsage(
                inputTokens: 32100,
                outputTokens: 10500,
                cacheReadTokens: 2000,
                cacheCreationTokens: 600,
                messageCount: 23,
                toolCallCount: 142,
                models: ["claude-sonnet-4-5-20250929": 32100],
                contextTokens: 142000
            )
        ]
    )
    .frame(width: 300)
    .padding()
}
