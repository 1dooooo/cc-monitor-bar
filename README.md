# cc-monitor-bar

macOS 原生菜单栏应用，监控 Claude Code 的所有本地行为。

## 功能

- **会话监控**: 追踪活跃会话状态、时长、项目路径
- **Token 统计**: 实时估算当前会话 Token 消耗、展示历史趋势
- **模型分析**: 按模型聚合使用量
- **三种 UI 风格**: 极简/数据看板/时间线可切换

## 技术栈

- Swift 5.0+
- SwiftUI + AppKit
- SQLite.swift
- macOS 14+

## 开发

```bash
open cc-monitor-bar.xcodeproj   # 在 Xcode 中打开
# Cmd+R 运行，Cmd+B 构建
```

## 项目结构

```
cc-monitor-bar/
├── App/          # 应用入口（AppDelegate、CCMonitorBarApp）
├── Models/       # 数据模型（Session、TokenUsage、DailyStats、ToolCall）
├── Database/     # SQLite 数据库（DatabaseManager、Repository、Schema）
├── Services/     # 服务层（ClaudeDataReader、DataPoller、TokenEstimator 等）
├── Settings/     # 设置（AppPreferences、SettingsView）
└── Views/        # UI 视图
    ├── Components/  # 通用组件（GlassBackground、FrequencySlider）
    ├── Minimal/     # 极简风格
    ├── Dashboard/   # 数据看板
    └── Timeline/    # 时间线
```

## 数据存储

数据存储在 `~/Library/Application Support/ClaudeMonitor/data.db`

## License

MIT
