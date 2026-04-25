# UI 规格说明 — cc-monitor-bar

> 版本：2.0 · 日期：2026-04-25
> 依赖：[设计系统](./2026-04-02-design-system.md)

---

## 窗口架构

### 概览

| 组件 | 类型 | 尺寸 | 说明 |
|------|------|------|------|
| Popover | NSPopover | 320×480pt（动态） | 菜单栏弹出，单面板滚动 |
| 设置窗口 | NSWindow | ~520×400pt | 独立悬浮，支持实时预览 |

### 实时预览机制

设置窗口打开时，Popover 保持显示并实时响应设置变化。

**实现方式**：
- 所有偏好设置通过 `@AppStorage` 持久化 + `@Published` 响应式绑定
- Popover 和设置窗口共享同一个 `AppPreferences` 实例
- 修改设置 → `@Published` 属性变化 → SwiftUI 自动刷新 Popover

---

## 通用组件库

### StatCard — 统计卡片

| 变体 | 说明 |
|------|------|
| 数值型 | 标签 + 大数字 + 可选变化率 |
| 图标型 | 标签 + emoji/图标 + 大数字 + 辅助文字 |
| 进度型 | 标签 + 大数字 + 底部迷你进度条 |

**规格**：
- 圆角：`radius-md` (8pt)，内边距：14pt
- 边框：`Color(.separator).opacity(0.5)`
- 标签：`.caption` · `secondaryLabelColor`
- 数值：`.title3.bold` · `labelColor`

### Badge — 徽章/标签

- 圆角：`radius-sm` (4pt)，内边距：3pt 10pt
- 背景：状态色 15% 透明度
- 文字：`.caption` · 状态色 · 字重 medium

### ProgressBar — 进度条

| 变体 | 高度 | 用途 |
|------|------|------|
| 标准 | 4pt | 模型分布、用量占比 |
| 紧凑 | 3pt | 行内小型进度 |
| 多段 | 6pt | 多类别对比 |

- 圆角 = 高度 / 2
- 轨道色：`Color(.separator).opacity(0.5)`
- 填充色：对应类别色

### SessionRow — 会话行

| 状态 | 状态点颜色 | 行背景 |
|------|-----------|--------|
| 活跃 | `systemGreen` | `windowBackgroundColor.opacity(0.06)` |
| 历史 | `systemGray` | `windowBackgroundColor.opacity(0.03)` |

- 状态指示点：8pt 圆形，行高：40-48pt
- 布局：`HStack` — 状态点 | 信息区 | 数值区

### Divider — 分割线

- 颜色：`Color(.separator)`
- 两侧留 14pt 内边距，不使用全宽分割

---

## 单面板布局

### 当前面板结构

```
ScrollView (垂直滚动)
├── TokenSummarySection      # 今日 Token + 数据质量状态
├── TrendChartSection        # 7日堆叠柱状图 (输入/输出/缓存)
├── ModelConsumptionSection   # 模型消耗分解
├── ActiveSessionSection      # 活跃会话 (含 Context Window)
├── RecentSessionSection      # 最近会话
├── ToolCallSection           # 工具调用 Top 5
```

### 各 Section 规格

#### 1. TokenSummarySection

- 大号数字展示今日总 Token 量
- 三维分解：↑输入 / ↓输出 / ⟳缓存
- 数据质量状态指示器：圆点 + 文字（"校验 正常/偏差/异常/未知"）
- 可展开显示详细诊断（JSONL vs Cache 差异、原因分析）

#### 2. TrendChartSection

- 堆叠柱状图，每根柱子分三层：输入（蓝）/ 输出（绿）/ 缓存（青）
- 右上角 Segmented Control：周（7 天）/ 月（30 天）
- 今日柱子用圆点标记高亮
- 底部图例说明颜色含义

#### 3. ModelConsumptionSection

每个模型一个卡片：
- 色块 + 模型名 + Token 总量
- ↑输入 / ↓输出 / ⟳缓存 三维数据
- 底部进度条显示该模型占总量的比例

#### 4. ActiveSessionSection

- 绿色状态点标识
- 卡片样式，项目名 + 消息数 + 时长
- ↑输入 / ↓输出 / 总量
- **Context Window 进度条**：`Context: 142K/200K (71%)`
- 颜色阈值：🟢 < 60% / 🟡 60-85% / 🔴 > 85%

#### 5. RecentSessionSection

- 灰色状态点标识
- 紧凑行样式
- 项目名 + 时长 + ↑输入 / ↓输出 / 总量

#### 6. ToolCallSection

- Top 5 彩色标签（真实的 tool_use 统计，非伪造数据）
- 格式：`[Bash × 42]` `[Read × 38]` `[Edit × 27]`

---

## 设置窗口

### 窗口规格

| 参数 | 值 |
|------|-----|
| 类型 | `NSWindow`，`.titled` + `.closable` + `.miniaturizable` |
| 尺寸 | ~520×400pt |
| 层级 | `.floating` |
| 位置 | 首次居中，之后记住用户最后位置 |

### 设置分区

#### 🎨 外观

| 设置项 | 控件类型 | 说明 |
|--------|---------|------|
| 主题风格 | 3 张卡片选择 | 原生自适应 / 毛玻璃通透 / Claude 暖调 |
| 毛玻璃效果 | Toggle | 启用/禁用毛玻璃背景 |
| 菜单栏图标 | SF Symbol 选择器 | 关键词模糊匹配 + 预览 |
| 菜单栏显示模式 | Segmented | 图标 / 文字 / 图文 |

#### 📊 显示

| 设置项 | 控件类型 | 说明 |
|--------|---------|------|
| Popover 宽度 | Segmented | 紧凑 280pt / 标准 320pt / 宽松 360pt |
| Token 显示单位 | Segmented | 自动 / K / M / B |
| 信息密度 | Segmented | 紧凑 / 标准 / 详细 |
| 时间格式 | Segmented | 12小时 / 24小时 |

#### 🔄 数据

| 设置项 | 控件类型 | 说明 |
|--------|---------|------|
| 活跃会话刷新频率 | Slider | 5s - 30s，默认 10s |
| 今日统计刷新频率 | Slider | 15s - 60s，默认 30s |
| 显示项目路径 | Toggle | 在会话行中显示项目路径 |
| 显示模型用量 | Toggle | 在极简视图中显示模型分布 |

#### 🔔 通知

| 设置项 | 控件类型 | 说明 |
|--------|---------|------|
| 会话卡住检测 | Toggle + 阈值 | 超过 N 分钟无 token 增长时通知 |
| 异常消耗检测 | Toggle | Token 消耗 > 日均 3 倍时通知 |
| Cache 过期检测 | Toggle | stats-cache > 2 小时未更新时通知 |
| Context 接近极限 | Toggle | 活跃会话 context > 90% 时通知 |

#### ⌨️ 快捷键

| 设置项 | 控件类型 | 说明 |
|--------|---------|------|
| 刷新数据 | 按键录制 | `⌘R` |
| 打开设置 | 按键录制 | `⌘,` |
| 关闭 Popover | 按键录制 | `⎋ Esc` |
| 启用全局快捷键 | Toggle | 总开关 |

#### ℹ️ 关于

应用版本、构建号、开源许可信息。

---

## 快捷键

| 功能 | 快捷键 |
|------|--------|
| 刷新数据 | `⌘R` |
| 打开设置 | `⌘,` |
| 关闭 Popover | `⎋ Esc` |

> 注意：单面板架构后，`⌘1`/`⌘2`/`⌘3` 面板切换快捷键已删除。

---

## 首次使用引导

使用 Apple TipKit（macOS 14+）实现轻量级渐进发现引导。

| 阶段 | 触发时机 | 内容 |
|------|---------|------|
| 首次打开 Popover | 检测到首次启动 | 「点击活跃会话查看会话详情，按 Esc 返回」 |
| 首次打开设置 | 打开设置窗口时 | 「切换主题可即时预览」 |

```swift
import TipKit

struct SessionDetailTip: Tip {
    var title: Text { "点击会话查看详情" }
    var message: Text? { Text("点击活跃会话可查看该会话的 Token、工具调用等数据。") }
    var options: [TipOption] { [MaxDisplayCount(3)] }
}
```
