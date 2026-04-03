import SwiftUI

/// 工具调用 Top 5
struct ToolCallSection: View {
    let toolCallCount: Int

    // 模拟数据
    private let topTools: [(name: String, count: Int)] = [
        ("Read", 312),
        ("Bash", 245),
        ("Edit", 189),
        ("Glob", 67),
        ("Grep", 34)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            HStack {
                Text("工具调用")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("共 \(toolCallCount.formattedTokens) 次")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: DesignTokens.spacingSM) {
                ForEach(topTools, id: \.name) { tool in
                    ToolTag(name: tool.name, count: tool.count)
                }
            }
        }
        .padding(DesignTokens.spacingMD)
        .background(GlassBackground().opacity(0.04))
        .cornerRadius(DesignTokens.radiusMD)
    }
}

struct ToolTag: View {
    let name: String
    let count: Int

    private var color: Color {
        switch name {
        case "Read": return .blue
        case "Bash": return .orange
        case "Edit": return .green
        case "Glob": return .teal
        case "Grep": return .pink
        default: return .secondary
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(name)
                .font(.system(size: 9, weight: .medium))
            Text("\(count)")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
        }
        .padding(.horizontal, DesignTokens.spacingSM)
        .padding(.vertical, 2)
        .background(color.opacity(0.15))
        .foregroundColor(color)
        .cornerRadius(DesignTokens.radiusSM)
    }
}

#Preview {
    ToolCallSection(toolCallCount: 847)
        .frame(width: 300)
        .padding()
}
