import TipKit

/// 会话钻取引导
struct SessionDrillDownTip: Tip {
    var title: Text {
        Text("点击会话查看详情")
    }
    var message: Text? {
        Text("点击活跃会话可查看该会话的 Token、工具调用等数据。\n按 Esc 返回今日总览。")
    }
    var options: [TipOption] { [MaxDisplayCount(3)] }
}

/// 主题切换引导
struct ThemePreviewTip: Tip {
    var title: Text {
        Text("切换主题即时预览")
    }
    var message: Text? {
        Text("在设置中切换配色主题，菜单栏弹窗会实时反映变化。")
    }
    var options: [TipOption] { [MaxDisplayCount(2)] }
}

/// 看板导航引导
struct DashboardNavTip: Tip {
    var title: Text {
        Text("滚动浏览所有数据")
    }
    var message: Text? {
        Text("看板视图支持滚动浏览概览、模型、会话、工具。滚动时右侧会出现锚点导航。")
    }
    var options: [TipOption] { [MaxDisplayCount(2)] }
}
