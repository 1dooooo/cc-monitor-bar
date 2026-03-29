import SwiftUI

/// 工具调用标签列表 — FlexWrap 布局
/// 用法: ToolTagList(tools: [("Bash", 5), ("Read", 3), ("Edit", 2)])
struct ToolTagList: View {
    let tools: [(name: String, count: Int)]

    var body: some View {
        FlexWrapLayout(spacing: DesignTokens.spacingXS) {
            ForEach(0..<tools.count, id: \.self) { i in
                let tool = tools[i]
                HStack(spacing: 3) {
                    Image(systemName: toolIcon(tool.name))
                        .font(.system(size: 9))
                    Text(tool.name)
                        .font(.caption2)
                    if tool.count > 1 {
                        Text("\(tool.count)")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                    }
                }
                .foregroundColor(ToolColors.color(for: tool.name))
                .padding(.vertical, 2)
                .padding(.horizontal, 6)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.radiusSM)
                        .fill(ToolColors.color(for: tool.name).opacity(0.1))
                )
            }
        }
    }

    private func toolIcon(_ name: String) -> String {
        switch name {
        case "Bash":  return "terminal"
        case "Read":  return "doc.text"
        case "Write": return "pencil.and.list"
        case "Glob":  return "folder"
        case "Grep":  return "magnifyingglass"
        case "Edit":  return "pencil"
        default:      return "wrench"
        }
    }
}

/// 自适应换行布局容器
private struct FlexWrapLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (positions, CGSize(width: maxX, height: y + rowHeight))
    }
}
