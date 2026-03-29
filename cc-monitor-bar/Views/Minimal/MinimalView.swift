import SwiftUI

/// 极简视图 — 双态布局：今日概览 / 会话详情
/// 点击会话行 → 钻入详情；ESC 或返回按钮 → 回到概览
struct MinimalView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorTheme) private var theme

    /// 当前钻入的会话 ID（nil = 概览态）
    @State private var drilledSessionId: String?

    var body: some View {
        ZStack {
            if let sid = drilledSessionId,
               let session = appState.currentSessions.first(where: { $0.id == sid }) ?? appState.historySessions.first(where: { $0.id == sid }) {
                SessionDetailView(
                    session: session,
                    usage: appState.sessionUsages[sid],
                    onBack: { drilledSessionId = nil }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            } else {
                overviewContent
                    .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing)))
            }
        }
        .animation(.easeInOut(duration: DesignTokens.animationFast), value: drilledSessionId)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ThemeColors.background(theme))
        // ESC 键返回
        .onExitCommand {
            if drilledSessionId != nil {
                drilledSessionId = nil
            }
        }
    }

    // MARK: - 概览态

    private var overviewContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: DesignTokens.spacingMD) {
                // 今日统计条
                todayStatsBar

                // 模型分布
                if let stats = appState.todayStats, !stats.modelBreakdown.isEmpty {
                    modelDistributionSection(stats.modelBreakdown)
                }

                // 工具调用
                if let stats = appState.todayStats, stats.toolCallCount > 0 {
                    toolCallSection(count: stats.toolCallCount)
                }

                // 活跃会话
                if !appState.currentSessions.isEmpty {
                    sectionHeader("活跃会话", icon: "circle.fill", iconColor: ThemeColors.active)
                    ForEach(appState.currentSessions) { session in
                        SessionRow(
                            session: session,
                            tokenUsage: nil,
                            toolCalls: nil
                        ) {
                            drilledSessionId = session.id
                        }
                    }
                    .sessionDrillDownTip()
                }

                // 最近会话
                if !appState.historySessions.isEmpty {
                    if !appState.currentSessions.isEmpty {
                        Divider().padding(.vertical, DesignTokens.spacingXS)
                    }
                    sectionHeader("最近会话", icon: "clock.arrow.circlepath", iconColor: nil)
                    ForEach(appState.historySessions.prefix(10)) { session in
                        SessionRow(
                            session: session,
                            tokenUsage: appState.sessionUsages[session.id],
                            toolCalls: nil
                        ) {
                            drilledSessionId = session.id
                        }
                    }
                }

                // 空态
                if appState.currentSessions.isEmpty && appState.historySessions.isEmpty && !appState.isLoading {
                    emptyState
                }

                if appState.isLoading && appState.currentSessions.isEmpty {
                    ProgressView()
                        .padding(.top, DesignTokens.spacingXL)
                }
            }
            .padding(DesignTokens.spacingMD)
        }
    }

    // MARK: - 今日统计条

    private var todayStatsBar: some View {
        HStack(spacing: 0) {
            if let stats = appState.todayStats {
                statItem(value: stats.totalTokens.formattedTokens, label: "Token", icon: "circle.hexagongrid", color: ThemeColors.info)
                divider
                statItem(value: "\(stats.sessionCount)", label: "会话", icon: "terminal", color: ThemeColors.active)
                divider
                statItem(value: "\(stats.toolCallCount)", label: "工具", icon: "wrench", color: ThemeColors.warning)
            } else {
                statItem(value: "-", label: "Token", icon: "circle.hexagongrid", color: ThemeColors.muted)
                divider
                statItem(value: "-", label: "会话", icon: "terminal", color: ThemeColors.muted)
                divider
                statItem(value: "-", label: "工具", icon: "wrench", color: ThemeColors.muted)
            }
        }
        .padding(.vertical, DesignTokens.spacingSM)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.radiusMD)
                .fill(ThemeColors.cardBackground(theme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.radiusMD)
                .stroke(ThemeColors.cardBorder(theme), lineWidth: 1)
        )
    }

    private var divider: some View {
        Rectangle()
            .fill(ThemeColors.divider(theme))
            .frame(width: 1, height: 24)
    }

    private func statItem(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundColor(color)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            Text(label)
                .font(.caption2)
                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 模型分布

    private func modelDistributionSection(_ breakdown: [(name: String, tokens: Int64)]) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            Text("模型分布")
                .font(.caption2)
                .foregroundColor(Color(nsColor: .secondaryLabelColor))

            let total = breakdown.map(\.tokens).reduce(Int64(0), +)
            MultiSegmentBar(
                segments: breakdown.prefix(4).map { item in
                    let fraction = total > 0 ? Double(item.tokens) / Double(total) : 0
                    return (label: "\(item.name) \(Int(fraction * 100))%", value: fraction, color: ModelColors.color(for: item.name))
                },
                height: 5
            )
        }
        .padding(.horizontal, DesignTokens.spacingSM)
    }

    // MARK: - 工具调用

    private func toolCallSection(count: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "wrench")
                .font(.system(size: 9))
                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
            Text("工具调用")
                .font(.caption2)
                .foregroundColor(Color(nsColor: .secondaryLabelColor))
            Text("\(count)")
                .font(.caption2)
                .fontWeight(.medium)
                .monospacedDigit()
                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
        }
        .padding(.horizontal, DesignTokens.spacingSM)
    }

    // MARK: - 辅助

    private func sectionHeader(_ title: String, icon: String, iconColor: Color?) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(iconColor ?? Color(nsColor: .secondaryLabelColor))
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(Color(nsColor: .secondaryLabelColor))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, DesignTokens.spacingXS)
    }

    private var emptyState: some View {
        VStack(spacing: DesignTokens.spacingSM) {
            Image(systemName: "moon.zzz")
                .font(.system(size: 28))
                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
            Text("无会话记录")
                .font(.subheadline)
                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignTokens.spacingXL)
    }
}

// MARK: - 会话详情视图

private struct SessionDetailView: View {
    let session: Session
    let usage: SessionUsage?
    let onBack: () -> Void

    @Environment(\.colorTheme) private var theme

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
                // 顶部导航
                HStack {
                    Button(action: onBack) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.caption)
                            Text("返回")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(ThemeColors.accent(theme))

                    Spacer()

                    if session.isRunning {
                        Badge(text: "运行中", color: ThemeColors.active)
                    }
                }

                // 项目信息卡片
                projectCard

                // Token 用量
                if let usage {
                    tokenSection(usage)
                }

                // 模型分布
                if let usage, !usage.models.isEmpty {
                    modelSection(usage)
                }
            }
            .padding(DesignTokens.spacingMD)
        }
    }

    // MARK: - 项目信息

    private var projectCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(URL(fileURLWithPath: session.projectPath).lastPathComponent)
                        .font(.headline)
                        .lineLimit(1)
                    Text(session.projectPath)
                        .font(.caption)
                        .foregroundColor(Color(nsColor: .secondaryLabelColor))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
            }

            HStack(spacing: DesignTokens.spacingMD) {
                infoChip(icon: "clock", text: session.durationFormatted)
                infoChip(icon: "bubble.left", text: "\(session.messageCount) 消息")
                infoChip(icon: "wrench", text: "\(session.toolCallCount) 工具")
                if !session.entrypoint.isEmpty {
                    infoChip(icon: "terminal", text: session.entrypoint)
                }
            }
        }
        .padding(DesignTokens.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.radiusMD)
                .fill(ThemeColors.cardBackground(theme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.radiusMD)
                .stroke(ThemeColors.cardBorder(theme), lineWidth: 1)
        )
    }

    private func infoChip(icon: String, text: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(text)
                .font(.caption2)
        }
        .foregroundColor(Color(nsColor: .secondaryLabelColor))
    }

    // MARK: - Token 用量

    private func tokenSection(_ usage: SessionUsage) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            Text("Token 用量")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(Color(nsColor: .secondaryLabelColor))

            let total = usage.totalTokens
            HStack(spacing: DesignTokens.spacingMD) {
                StatCard(title: "总用量", value: total.formattedTokens)
                StatCard(title: "输入", value: usage.inputTokens.formattedTokens)
                StatCard(title: "输出", value: usage.outputTokens.formattedTokens)
            }

            if total > 0 {
                ProgressBar(
                    value: Double(usage.outputTokens) / Double(total),
                    color: ThemeColors.warning,
                    height: 4,
                    showLabel: true,
                    labelLeft: "输出占比",
                    labelRight: String(format: "%.0f%%", Double(usage.outputTokens) / Double(total) * 100)
                )
            }
        }
        .padding(DesignTokens.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.radiusMD)
                .fill(ThemeColors.cardBackground(theme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.radiusMD)
                .stroke(ThemeColors.cardBorder(theme), lineWidth: 1)
        )
    }

    // MARK: - 模型分布

    private func modelSection(_ usage: SessionUsage) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            Text("模型分布")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(Color(nsColor: .secondaryLabelColor))

            let sorted = usage.models.sorted { $0.value > $1.value }
            let totalTokens = sorted.map(\.value).reduce(0, +)

            ForEach(sorted, id: \.key) { model in
                HStack(spacing: DesignTokens.spacingSM) {
                    Text(model.key)
                        .font(.caption)
                        .lineLimit(1)
                        .frame(width: 80, alignment: .leading)

                    ProgressBar(
                        value: totalTokens > 0 ? Double(model.value) / Double(totalTokens) : 0,
                        color: ModelColors.color(for: model.key),
                        height: 6
                    )

                    Text(model.value.formattedTokens)
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundColor(Color(nsColor: .secondaryLabelColor))
                        .frame(width: 45, alignment: .trailing)
                }
            }
        }
        .padding(DesignTokens.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.radiusMD)
                .fill(ThemeColors.cardBackground(theme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.radiusMD)
                .stroke(ThemeColors.cardBorder(theme), lineWidth: 1)
        )
    }
}
