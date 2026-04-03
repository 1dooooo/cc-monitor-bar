import SwiftUI

struct SnapshotDetail: View {
    let event: TimelineEvent
    @Environment(\.colorTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("会话快照")
                    .font(.headline)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color(nsColor: .secondaryLabelColor))
                }
                .buttonStyle(.plain)
            }
            .padding(DesignTokens.spacingMD)
            .background(ThemeColors.cardBackground(theme))

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
                    DetailRow(label: "会话 ID", value: event.id)
                    DetailRow(label: "启动时间", value: formattedDate)

                    if let project = event.project {
                        DetailRow(label: "项目路径", value: project)
                    }

                    Divider()

                    if let tokens = event.tokens {
                        StatCard(title: "Token 总量", value: tokens.formattedTokens)
                    }
                }
                .padding(DesignTokens.spacingMD)
            }
        }
        .frame(width: 320, height: 420)
        .background(ThemeColors.background(theme))
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: event.time)
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(Color(nsColor: .secondaryLabelColor))
                .frame(width: 80, alignment: .leading)
            Text(value)
                .foregroundColor(.primary)
            Spacer()
        }
        .font(.subheadline)
    }
}

// MARK: - Preview 扩展

#if DEBUG
extension TimelineEvent {
    var modelName: String { "glm-5.1" }
    var inputTokens: String { "10,234" }
    var outputTokens: String { "2,222" }
    var cacheTokens: String { "500" }
    var messageCount: Int { 15 }
    var toolCalls: String { "Bash×5, Read×3, Write×2" }
}
#endif
