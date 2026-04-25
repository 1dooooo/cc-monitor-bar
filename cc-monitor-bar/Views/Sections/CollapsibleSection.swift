import SwiftUI

/// 可折叠区块容器 — 点击标题区域折叠/展开内容
struct CollapsibleSection<Content: View>: View {
    let title: String
    @Binding var isCollapsed: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            // 标题区域（可点击折叠）
            HStack {
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .rotationEffect(isCollapsed ? .degrees(0) : .degrees(0))
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(DesignTokens.spacingSM)
            .background(Color.secondary.opacity(0.03))
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isCollapsed.toggle()
                }
            }

            // 内容区域
            if !isCollapsed {
                content()
            }
        }
        .background(GlassBackground().opacity(0.04))
        .cornerRadius(DesignTokens.radiusMD)
    }
}

#Preview {
    CollapsibleSection(
        title: "示例区块",
        isCollapsed: .constant(false)
    ) {
        Text("区块内容")
            .padding()
    }
    .frame(width: 300)
}
