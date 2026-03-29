import SwiftUI
import TipKit

extension View {
    /// 首次使用 — 会话钻取提示
    func sessionDrillDownTip() -> some View {
        self.popoverTip(SessionDrillDownTip(), arrowEdge: .top)
    }

    /// 首次使用 — 看板导航提示
    func dashboardNavTip() -> some View {
        self.popoverTip(DashboardNavTip(), arrowEdge: .bottom)
    }

    /// 首次使用 — 主题切换引导
    func themePreviewTip() -> some View {
        self.popoverTip(ThemePreviewTip(), arrowEdge: .bottom)
    }
}
