# UI 重构 — 实施计划索引

> 本文档是 UI 重构的总索引，将整体工作拆分为 6 个独立子计划，每个子计划可单独执行、测试和提交。

## 依赖关系

```
P1 设计系统基础 ──→ P2 设置独立窗口 ──→ P3 极简视图重构
                  ──→ P4 看板视图重构
                  ──→ P5 时间线视图重构
                                        ──→ P6 快捷键 & TipKit
```

- P1 是所有后续计划的前置依赖
- P2-P5 可并行但建议按顺序
- P6 依赖 P2-P5 完成后的最终组件

## 子计划列表

| # | 名称 | 计划文件 | 主要变更 |
|---|------|---------|---------|
| P1 | 设计系统基础 | `P1-design-system.md` | ColorTheme 枚举、DesignTokens、主题切换基础设施 |
| P2 | 设置独立窗口 | `P2-settings-window.md` | SettingsWindowController、左导航布局、SF Symbol 选择器、实时预览 |
| P3 | 极简视图重构 | `P3-minimal-view.md` | 会话钻取、ESC 返回、新组件样式 |
| P4 | 看板视图重构 | `P4-dashboard-view.md` | 单页滚动、FloatingNav 组件、scroll spy |
| P5 | 时间线视图重构 | `P5-timeline-view.md` | 更新组件样式、新设计系统适配 |
| P6 | 快捷键 & TipKit | `P6-shortcuts-onboarding.md` | 全局快捷键、TipKit 首次引导 |

## 设计文档

- [设计系统](../specs/2026-04-02-design-system.md)
- [UI 规格](../specs/2026-04-02-ui-specification.md)
