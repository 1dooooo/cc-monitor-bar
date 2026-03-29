import SwiftUI

/// 浮动锚点导航 — 内嵌在 ScrollView 内
/// 滚动时展开显示图标+文字，静止后收起为小圆点
struct FloatingNav: View {
    let sections: [SectionDef]
    @Binding var activeSection: String
    var onSectionTap: (String) -> Void

    @Binding var isExpanded: Bool
    @State private var collapseTask: DispatchWorkItem?

    @Environment(\.colorTheme) private var theme

    struct SectionDef: Identifiable {
        let id: String
        let icon: String
        let label: String
    }

    var body: some View {
        VStack(spacing: DesignTokens.spacingXS) {
            if isExpanded {
                ForEach(sections) { section in
                    Button(action: { onSectionTap(section.id) }) {
                        HStack(spacing: 6) {
                            Image(systemName: section.icon)
                                .font(.system(size: 10))
                            Text(section.label)
                                .font(.system(size: 11))
                        }
                        .foregroundColor(activeSection == section.id ? ThemeColors.accent(theme) : Color(nsColor: .secondaryLabelColor))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: DesignTokens.radiusSM)
                                .fill(activeSection == section.id ? ThemeColors.accent(theme).opacity(0.15) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            } else {
                ForEach(sections) { section in
                    Circle()
                        .fill(activeSection == section.id ? ThemeColors.accent(theme) : Color(nsColor: .tertiaryLabelColor).opacity(0.4))
                        .frame(width: DesignTokens.floatingNavDotSize, height: DesignTokens.floatingNavDotSize)
                }
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.radiusLG)
                .fill(ThemeColors.cardBackground(theme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.radiusLG)
                .stroke(ThemeColors.cardBorder(theme), lineWidth: 1)
        )
        .animation(.easeInOut(duration: DesignTokens.animationNormal), value: isExpanded)
        .onChange(of: isExpanded) { expanded in
            if expanded { scheduleCollapse() }
        }
    }

    /// 通知发生了滚动，展开导航
    func scheduleExpand() {
        collapseTask?.cancel()
        withAnimation(.easeInOut(duration: DesignTokens.animationFast)) {
            isExpanded = true
        }
        scheduleCollapse()
    }

    private func scheduleCollapse() {
        collapseTask?.cancel()
        let task = DispatchWorkItem {
            withAnimation(.easeInOut(duration: DesignTokens.animationSlow)) {
                self.isExpanded = false
            }
        }
        collapseTask = task
        DispatchQueue.main.asyncAfter(
            deadline: .now() + DesignTokens.floatingNavCollapseDelay,
            execute: task
        )
    }
}
