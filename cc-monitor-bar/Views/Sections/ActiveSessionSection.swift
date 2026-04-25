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
                if let usage = usage {
                    Text("\(usage.messageCount) msg")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Text(session.durationFormatted)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
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

            // Context Window 进度条
            if let usage = usage, usage.contextTokens > 0 {
                ContextProgressBar(contextTokens: usage.contextTokens)
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

/// Context Window 使用量进度条
///
/// 颜色阈值: 🟢 < 60% / 🟡 60-85% / 🔴 > 85%
struct ContextProgressBar: View {
    let contextTokens: Int64
    private let contextLimit: Int64 = 200_000  // 默认 Claude 200K context

    private var ratio: Double {
        Double(contextTokens) / Double(contextLimit)
    }

    private var percentage: Int {
        min(Int(ratio * 100), 999)
    }

    private var barColor: Color {
        if ratio < 0.6 { return .green }
        if ratio < 0.85 { return .orange }
        return .red
    }

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 6) {
                Text("Context")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
                ProgressView(value: min(ratio, 1.0))
                    .progressViewStyle(LinearProgressViewStyle(tint: barColor))
                    .scaleEffect(x: 1, y: 0.6, anchor: .center)
                Text("\(percentage)%")
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .foregroundColor(barColor)
            }
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
