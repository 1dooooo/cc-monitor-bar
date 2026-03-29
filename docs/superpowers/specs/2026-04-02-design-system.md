# 设计系统 — cc-monitor-bar

> 版本：1.0 · 日期：2026-04-02

## 设计原则

| 原则 | 说明 |
|------|------|
| **信息优先** | 关键数据一目了然，辅助信息按需展开。避免装饰性元素抢占注意力 |
| **原生质感** | 优先使用 SwiftUI 原生控件和系统语义色。自定义仅限于视觉层（卡片背景、分隔线样式） |
| **通透轻盈** | 适度使用毛玻璃效果营造层次感。弹窗不遮挡太多桌面空间，避免厚重感 |
| **一致性** | 圆角、间距、字体、配色在不同视图和主题间保持一致的节奏感 |
| **即时响应** | 菜单栏应用应感觉即时。数据更新不突兀，布局不跳动 |
| **克制用色** | 大面积使用中性色/半透明色。颜色仅用于状态指示、数据类别区分、交互反馈。同一视图不超过 3 种强调色 |

---

## 配色系统

### 三套可切换主题

所有主题通过 `AppPreferences.theme` 统一管理，设置中切换后即时预览。

#### 主题 A — 原生自适应 (Native)

完全使用 macOS 系统语义色，自动适配深色/浅色模式和壁纸着色 (Desktop Tinting)。

| 用途 | SwiftUI / AppKit 语义色 | 深色模式近似值 |
|------|------------------------|---------------|
| 窗口背景 | `Color(.windowBackgroundColor)` | `#1E1E1E` |
| 卡片背景 | `Color(.controlBackgroundColor)` | `#252525` |
| 悬浮/高亮 | `Color(.underPageBackgroundColor)` | `#2D2D2D` |
| 分组背景 | `Color(.textBackgroundColor)` | `#1E1E1E` |
| 分割线 | `Color(.separator)` | 半透明 |
| 强调色 | `Color(.systemBlue)` | `#007AFF` |

#### 主题 B — 毛玻璃通透 (Frosted)

基于 SwiftUI Material 构建通透的层次感。**注意**：此主题是"毛玻璃层叠禁令"的例外——通过使用不同透明度等级的 Material（而非多层相同 Material）来保持可读性。强调色偏鲜亮。

| 用途 | 实现方式 | 说明 |
|------|---------|------|
| 窗口背景 | `.ultraThinMaterial` | 最高透明度 |
| 卡片背景 | `.thinMaterial` | 轻量遮罩 |
| 悬浮/高亮 | `.regularMaterial` | 标准弹窗背景 |
| 分组背景 | `.thinMaterial` + 0.04 opacity | 极轻遮罩 |
| 分割线 | `Color.white.opacity(0.08)` | 微妙分隔 |
| 强调色 | `Color(.systemTeal)` | `#5AC8FA` |

#### 主题 C — Claude 暖调 (Warm)

背景沿用系统语义色，强调色采用暖色系（棕/橙/金），呼应 Claude 品牌调性。

| 用途 | 实现方式 | 说明 |
|------|---------|------|
| 窗口背景 | `Color(.windowBackgroundColor)` | 与 Native 相同 |
| 卡片背景 | `Color(.controlBackgroundColor)` | 与 Native 相同 |
| 悬浮/高亮 | `Color.amber.opacity(0.1)` | 琥珀色浅底 |
| 分组背景 | `Color(.textBackgroundColor)` | 与 Native 相同 |
| 分割线 | `Color(.separator)` | 与 Native 相同 |
| 强调色 | 自定义 `amber-600` | `#D97706` |

Claude 暖调的自定义色定义：

```swift
extension Color {
    static let amber600 = Color(red: 0.85, green: 0.47, blue: 0.02) // #D97706
    static let amber500 = Color(red: 0.96, green: 0.62, blue: 0.04) // #F59E0B
}
```

### 状态色（三主题通用）

| 状态 | 颜色 | SwiftUI | 用途 |
|------|------|---------|------|
| 正常/活跃 | `#34C759` | `.systemGreen` | 活跃会话、正常状态 |
| 信息/中性 | `#007AFF` | `.systemBlue` | 主强调色、活动状态 |
| 警告 | `#FF9500` | `.systemOrange` | 接近限制、高用量 |
| 错误/危险 | `#FF3B30` | `.systemRed` | 超限、异常、失败 |
| 次要信息 | `#8E8E93` | `.systemGray` | 辅助文本、禁用状态 |

### 文本色阶

| 层级 | SwiftUI 语义色 | 不透明度 | 用途 |
|------|---------------|---------|------|
| 主要文本 | `Color(.labelColor)` | 100% | 标题、数值、正文 |
| 次要文本 | `Color(.secondaryLabelColor)` | ~60% | 辅助说明、副标题 |
| 辅助文本 | `Color(.tertiaryLabelColor)` | ~40% | 标签、注释 |
| 占位文本 | `Color(.quaternaryLabelColor)` | ~25% | 空状态、占位符 |

---

## 字体层次

使用系统字体 SF Pro（SwiftUI 默认），不引入自定义字体。

| 样式 | SwiftUI 修饰符 | 大小 | 字重 | 用途 |
|------|---------------|------|------|------|
| 数值展示 | `.title3.bold` | 20pt | Bold | 统计卡片中的大数字 |
| 区块标题 | `.headline` | 17pt | Bold | 视图区域标题 |
| 辅助标题 | `.subheadline` | 15pt | Regular | 会话名、项目名 |
| 正文内容 | `.body` | 14pt | Regular | 正文、描述 |
| 标签说明 | `.caption` | 12pt | Regular | 数据标签、徽章文字 |
| 时间戳/路径 | `.caption2` | 11pt | Regular | 路径、时间、次要信息 |

---

## 间距 Token

| 名称 | 值 | 用途 |
|------|-----|------|
| `spacing-xs` | 4pt | 行内间距、紧凑元素内边距 |
| `spacing-sm` | 8pt | 卡片内边距、同组元素间距 |
| `spacing-md` | 12pt | 区块间距、卡片间距 |
| `spacing-lg` | 16pt | 外边距、大区块间距 |
| `spacing-xl` | 20pt | 页面级间距、大标题上方 |

---

## 圆角 Token

| 名称 | 值 | 用途 |
|------|-----|------|
| `radius-sm` | 4pt | 徽章、标签、小按钮 |
| `radius-md` | 8pt | 卡片、输入框、下拉框、会话行 |
| `radius-lg` | 12pt | 区块容器、模态面板、浮动导航 |
| `radius-full` | 50% | 状态指示点、头像、药丸按钮 |

---

## 毛玻璃效果

### 实现方式

优先使用 SwiftUI `.background(.ultraThinMaterial)` 等 Material API，而非手动 `NSVisualEffectView`，以便向前兼容 macOS 26 Liquid Glass。

### 规范

- Popover 整体背景：一层毛玻璃即可（主题 A/C 使用系统语义色，主题 B 使用 `.ultraThinMaterial`）
- 卡片背景：半透明色。主题 A/C 使用 `Color(.windowBackgroundColor).opacity(0.5)`；主题 B 使用 `.thinMaterial`（这是主题 B 的设计意图，使用**不同透明度等级**的 Material 而非叠加相同层）
- 禁止在**相同透明度等级**的毛玻璃上叠加多层毛玻璃（如 `.thinMaterial` 上叠加 `.thinMaterial`），影响可读性
- 主题 B 允许 `.ultraThinMaterial`（窗口）+ `.thinMaterial`（卡片）这样的递进层级，因为它们是不同透明度等级
- 需要测试"减少透明度"辅助功能开启时的表现

---

## 菜单栏图标

| 参数 | 规范 |
|------|------|
| 可用高度 | 22pt（系统固定，不可超出） |
| 推荐图标 | 16×16pt SF Symbol |
| 格式 | Template Image（macOS 自动适配深色/浅色模式） |
| 用户自定义 | 用户可从 SF Symbol 库中选择任意图标 |

---

## Popover 尺寸

| 参数 | 值 | 说明 |
|------|-----|------|
| 宽度 | 320pt（默认） | 支持三档可配置：紧凑 280pt / 标准 320pt / 宽松 360pt |
| 高度 | 480pt（动态） | 根据内容量自适应调整 |
| 圆角 | 10pt | NSPopover 系统默认 |

---

## 图标与颜色映射

### 模型颜色

| 模型 | 颜色 | SwiftUI |
|------|------|---------|
| Sonnet | `#007AFF` 蓝 | `.systemBlue` |
| Opus | `#5AC8FA` 青 | `.systemTeal` |
| Haiku | `#34C759` 绿 | `.systemGreen` |
| 其他 | `#FF9500` 橙 | `.systemOrange` |

### 工具颜色

| 工具类型 | 颜色 |
|---------|------|
| 文件操作 (Edit/Write/Read) | `systemBlue` |
| 搜索 (Grep/Glob) | `systemTeal` |
| 执行 (Bash) | `systemOrange` |
| 其他 | `systemGray` |
