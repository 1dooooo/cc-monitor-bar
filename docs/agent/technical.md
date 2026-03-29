# 技术描述

> [AI-AGENT-MAINTAINED]

## 技术栈

| 层级 | 技术 | 说明 |
|------|------|------|
| 语言 | Swift 5.0+ | - |
| UI 框架 | SwiftUI + AppKit | SwiftUI 为主，NSStatusItem / NSPopover / NSWindow 通过 AppKit 管理 |
| 图表 | Charts framework | macOS 14+ 原生 Charts，附带自定义 fallback |
| 数据库 | SQLite.swift | 本地包引用，非 SPM 远程依赖 |
| 引导提示 | TipKit | 首次使用引导 |
| 目标平台 | macOS 14.0+ | - |
| 最低部署 | arm64 | Apple Silicon |

## 构建命令

```bash
# 命令行构建
xcodebuild -project cc-monitor-bar.xcodeproj -scheme cc-monitor-bar build

# Xcode 打开
open cc-monitor-bar.xcodeproj
```

## 项目配置

- **Bundle ID**: `com.ido.cc-monitor-bar`
- **开发团队 ID**: `9T496VMQYV`
- **沙盒**: 关闭 (`com.apple.security.app-sandbox: false`)
- **文件权限**: 仅用户选择的只读读取

## 依赖

| 依赖 | 版本 | 来源 | 用途 |
|------|------|------|------|
| SQLite.swift | 本地包 | `SQLite.swift/` 目录 | SQLite ORM 封装 |

无其他外部依赖。Charts、TipKit、Combine 均为系统框架。

## 文件组织

Xcode 项目使用 `PBXFileSystemSynchronizedRootGroup`，文件系统即项目结构，无需手动维护 `.pbxproj` 中的文件引用。

## 关键目录

```
cc-monitor-bar/
├── App/           # 入口：App、AppDelegate、AppState
├── Models/        # 数据模型：Session、SessionUsage、TokenUsage、DailyStats 等
├── Services/      # 服务层：ClaudeDataReader、DataPoller、ProjectResolver
├── Database/      # 数据库：DatabaseManager、Schema、Repository
├── Views/         # 视图：Components/、Dashboard/、Minimal/、Timeline/、Onboarding/
├── Settings/      # 设置窗口：分区管理
└── Theme/         # 主题系统：DesignTokens、ColorTheme、ThemeEnvironment
```
