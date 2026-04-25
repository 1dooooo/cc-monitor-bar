import SwiftUI

/// 模型消耗列表
struct ModelConsumptionSection: View {
    let modelBreakdown: [(name: String, tokens: Int64, inputTokens: Int64, outputTokens: Int64, cacheTokens: Int64)]

    private var totalTokens: Int64 {
        modelBreakdown.reduce(0) { $0 + $1.tokens }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            Text("模型消耗")
                .font(.caption)
                .foregroundColor(.secondary)

            if modelBreakdown.isEmpty {
                Text("暂无模型数据")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.5))
            } else {
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
    ModelConsumptionSection(modelBreakdown: [
        ("claude-sonnet-4-5-20250929", 843_000, 500_000, 300_000, 43_000),
        ("claude-opus-4-5-20251001", 248_000, 150_000, 80_000, 18_000),
        ("claude-haiku-4-5-20251001", 149_000, 90_000, 50_000, 9_000),
    ])
    .frame(width: 300)
    .padding()
}
