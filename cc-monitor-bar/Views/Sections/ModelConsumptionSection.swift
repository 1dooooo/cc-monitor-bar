import SwiftUI

/// 模型消耗列表
struct ModelConsumptionSection: View {
    let todayStats: TodayStats?

    private var modelBreakdown: [(name: String, tokens: Int64, inputTokens: Int64, outputTokens: Int64, cacheTokens: Int64)] {
        todayStats?.modelBreakdown ?? []
    }

    private var totalTokens: Int64 {
        todayStats?.totalTokens ?? 0
    }

    private var isLoading: Bool {
        todayStats == nil
    }

    private var modelTotalTokens: Int64 {
        modelBreakdown.reduce(0) { $0 + $1.tokens }
    }

    private var coverageRatio: Double {
        guard totalTokens > 0 else { return 0 }
        return Double(modelTotalTokens) / Double(totalTokens)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            Text("模型消耗")
                .font(.caption)
                .foregroundColor(.secondary)

            if isLoading {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("加载中...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(8)
            } else if modelBreakdown.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("暂无模型数据")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("可能原因：JSONL 文件未包含模型信息")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
            } else {
                if coverageRatio < 0.8 {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.orange)
                        Text("部分模型数据缺失 (\(Int(coverageRatio * 100))%)")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                    }
                    .padding(4)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(4)
                }

                ForEach(modelBreakdown, id: \.name) { model in
                    ModelRow(
                        name: model.name,
                        tokens: model.tokens,
                        inputTokens: model.inputTokens,
                        outputTokens: model.outputTokens,
                        cacheTokens: model.cacheTokens,
                        total: totalTokens
                    )
                }
            }
        }
        .padding(DesignTokens.spacingMD)
        .background(GlassBackground().opacity(0.04))
        .cornerRadius(DesignTokens.radiusMD)
    }
}

struct ModelRow: View {
    let name: String
    let tokens: Int64
    let inputTokens: Int64
    let outputTokens: Int64
    let cacheTokens: Int64
    let total: Int64

    private var ratio: CGFloat {
        guard total > 0 else { return 0 }
        return CGFloat(tokens) / CGFloat(total)
    }

    private var color: Color {
        let lower = name.lowercased()
        if lower.contains("sonnet") { return .blue }
        if lower.contains("opus") { return .teal }
        if lower.contains("haiku") { return .green }
        return .orange
    }

    var body: some View {
        VStack(spacing: DesignTokens.spacingXS) {
            HStack {
                HStack(spacing: 6) {
                    Rectangle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                        .cornerRadius(2)
                    Text(modelNameDisplay(name))
                        .font(.system(size: 10))
                        .fontWeight(.medium)
                    Spacer()
                    Text(tokens.formattedTokens)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(color)
                }
            }

            HStack(spacing: DesignTokens.spacingSM) {
                Text("↑ \(inputTokens.formattedTokens)")
                    .font(.system(size: 9))
                    .foregroundColor(.blue)
                Text("↓ \(outputTokens.formattedTokens)")
                    .font(.system(size: 9))
                    .foregroundColor(.green)
                Text("⟳ \(cacheTokens.formattedTokens)")
                    .font(.system(size: 9))
                    .foregroundColor(.teal)
                Spacer()
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.1))
                        .frame(height: 3)
                        .cornerRadius(2)
                    Rectangle()
                        .fill(color)
                        .frame(width: geo.size.width * ratio, height: 3)
                        .cornerRadius(2)
                }
            }
            .frame(height: 3)
        }
        .padding(DesignTokens.spacingSM)
        .background(Color.secondary.opacity(0.04))
        .cornerRadius(DesignTokens.radiusSM)
    }

    private func modelNameDisplay(_ name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("sonnet") { return "Sonnet" }
        if lower.contains("opus") { return "Opus" }
        if lower.contains("haiku") { return "Haiku" }
        // Fallback: 移除 "claude-" 前缀，保留简短名称
        if name.hasPrefix("claude-") {
            return name.dropFirst(7).capitalized
        }
        return name
    }
}

#Preview {
    ModelConsumptionSection(
        todayStats: TodayStats(
            messageCount: 50, sessionCount: 3, toolCallCount: 200,
            totalTokens: 1_240_000, inputTokens: 790_000, outputTokens: 430_000,
            cacheTokens: 70_000,
            modelBreakdown: [
                ("claude-sonnet-4-5-20250929", 843_000, 500_000, 300_000, 43_000),
                ("claude-opus-4-5-20251001", 248_000, 150_000, 80_000, 18_000),
                ("claude-haiku-4-5-20251001", 149_000, 90_000, 50_000, 9_000),
            ],
            toolCounts: ["Read": 100, "Write": 50]
        )
    )
    .frame(width: 300)
    .padding()
}
