# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

macOS 菜单栏应用 **cc-monitor-bar**，用于本地监控 Claude Code 的使用情况：活跃会话追踪、Token 用量估算、工具调用统计、每日聚合分析。

## 构建命令

```bash
# 使用 xcodebuild
xcodebuild -project cc-monitor-bar.xcodeproj -scheme cc-monitor-bar build

# 或在 Xcode 中打开
open cc-monitor-bar.xcodeproj
```

- Swift 5.0，目标平台 macOS 14.0+
- 唯一外部依赖：SQLite.swift（本地包引用）
- 开发团队 ID：9T496VMQYV

## 架构

三层设计：

**UI 层** (`App/`, `Views/`) — SwiftUI + AppKit 混合，AppDelegate 管理菜单栏图标和 NSPopover

**服务层** (`Services/`) — 核心业务逻辑：
- `ClaudeDataReader` — 读取 `~/.claude/` 下的数据文件（stats-cache.json、history.jsonl、sessions/*.json、projects/*/*.jsonl）
- `DataPoller` — 定时轮询（默认 30s）
- `ProjectResolver` — 通过 Git 根目录解析项目
- `KeyboardShortcuts` — 全局快捷键管理

**数据层** (`Database/`, `Models/`) — SQLite 持久化（5 张表），数据模型定义

## 数据来源

应用只读取本地文件，不调用 API：

| 路径 | 用途 |
|------|------|
| `~/.claude/stats-cache.json` | Token 统计基线 |
| `~/.claude/history.jsonl` | 会话历史索引 |
| `~/.claude/sessions/*.json` | 活跃会话元数据 |
| `~/.claude/projects/*/*.jsonl` | 项目会话转录 |

## 设计文档

详细规格和实施计划在 `docs/superpowers/` 下，数据源调研在 `docs/claude-code-data-survey.md`。

## Agent 自维护文档

`docs/agent/` 目录下的文件由 AI Agent 维护，用于帮助 Agent 快速理解项目。

### 自维护规则

- 当代码发生**结构性变更**（新增/删除文件、修改核心接口、重构架构）时，主动更新 `docs/agent/` 下对应的文档
- 纯 UI 微调、文案修改、Bug 修复不影响文档准确性时，无需更新
- 更新前先读取目标文档确认当前内容，避免覆盖有效信息
- 如果无法确认正确内容，在对应段落添加 `<!-- OUTDATED: 说明 -->` 标记

### 文档索引

| 文件 | 内容 | 更新触发 |
|------|------|---------|
| `docs/agent/business.md` | 业务描述、用户场景、核心功能 | 功能增减 |
| `docs/agent/technical.md` | 技术栈、构建配置、依赖 | 技术选型变更 |
| `docs/agent/architecture.md` | 分层架构、数据流、模块关系 | 代码结构变更 |
| `docs/agent/data-sources.md` | 本地文件格式、Token 计算逻辑 | 数据源或计算逻辑变更 |
