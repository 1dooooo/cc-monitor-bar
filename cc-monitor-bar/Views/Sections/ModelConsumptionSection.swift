import SwiftUI

/// 模型消耗列表
struct ModelConsumptionSection: View {
    let modelBreakdown: [(name: String, tokens: Int64)]

    private var totalTokens: Int64 {
        modelBreakdown.reduce(0) { $0 + $1.tokens }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            Text("模型消耗")
                .font(.caption)
                .foregroundColor(.secondary)

            ForEach(modelBreakdown, id: \.name) { model in
                ModelRow(
                    name: model.name,
                    tokens: model.tokens,
                    total: totalTokens
                )
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
                Text("↑ 0")
                    .font(.system(size: 9))
                    .foregroundColor(.blue)
                Text("↓ 0")
                    .font(.system(size: 9))
                    .foregroundColor(.green)
                Text("⟳ 0")
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
        if name.lowercased().contains("sonnet") { return "Sonnet" }
        if name.lowercased().contains("opus") { return "Opus" }
        if name.lowercased().contains("haiku") { return "Haiku" }
        return name
    }
}

#Preview {
    ModelConsumptionSection(modelBreakdown: [
        ("claude-sonnet-4-5-20250929", 843_000),
        ("claude-opus-4-5-20251001", 248_000),
        ("claude-haiku-4-5-20251001", 149_000),
    ])
    .frame(width: 300)
    .padding()
}
