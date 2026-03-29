import SwiftUI

// MARK: - 配色主题

/// 三套可切换的配色方案
enum ColorTheme: String, CaseIterable, Codable, Identifiable {
    case native = "native"
    case frosted = "frosted"
    case warm = "warm"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .native:  return "原生自适应"
        case .frosted: return "毛玻璃通透"
        case .warm:    return "Claude 暖调"
        }
    }
}

// MARK: - 主题感知颜色

/// 根据当前 ColorTheme 返回对应的颜色
/// 用法: ThemeColors.background(theme)
enum ThemeColors {

    // MARK: - 背景

    static func background(_ theme: ColorTheme) -> Color {
        switch theme {
        case .native, .warm:
            return Color(.windowBackgroundColor)
        case .frosted:
            return Color.clear
        }
    }

    static func cardBackground(_ theme: ColorTheme) -> Color {
        switch theme {
        case .native, .warm:
            return Color(.controlBackgroundColor)
        case .frosted:
            return Color.white.opacity(0.06)
        }
    }

    static func cardBorder(_ theme: ColorTheme) -> Color {
        switch theme {
        case .native, .warm:
            return Color(nsColor: .separatorColor).opacity(0.5)
        case .frosted:
            return Color.white.opacity(0.1)
        }
    }

    static func highlightBackground(_ theme: ColorTheme) -> Color {
        switch theme {
        case .native:
            return Color(.underPageBackgroundColor)
        case .frosted:
            return Color.white.opacity(0.1)
        case .warm:
            return Color.amber600.opacity(0.1)
        }
    }

    static func divider(_ theme: ColorTheme) -> Color {
        switch theme {
        case .native, .warm:
            return Color(nsColor: .separatorColor)
        case .frosted:
            return Color.white.opacity(0.08)
        }
    }

    // MARK: - 强调色

    static func accent(_ theme: ColorTheme) -> Color {
        switch theme {
        case .native:
            return Color(.systemBlue)
        case .frosted:
            return Color(.systemTeal)
        case .warm:
            return Color.amber600
        }
    }

    // MARK: - 状态色（三主题通用）

    static let active   = Color(.systemGreen)
    static let info     = Color(.systemBlue)
    static let warning  = Color(.systemOrange)
    static let error    = Color(.systemRed)
    static let muted    = Color(.systemGray)

    // MARK: - 进度条轨道

    static func progressTrack(_ theme: ColorTheme) -> Color {
        switch theme {
        case .native, .warm:
            return Color(nsColor: .separatorColor).opacity(0.5)
        case .frosted:
            return Color.white.opacity(0.08)
        }
    }

    // MARK: - Material

    static func popoverMaterial(_ theme: ColorTheme) -> Material {
        switch theme {
        case .native, .warm:
            return .regularMaterial
        case .frosted:
            return .ultraThinMaterial
        }
    }

    static func cardMaterial(_ theme: ColorTheme) -> Material? {
        switch theme {
        case .native, .warm:
            return nil
        case .frosted:
            return .thinMaterial
        }
    }
}

// MARK: - Claude 暖调自定义色

extension Color {
    static let amber600 = Color(red: 0.85, green: 0.47, blue: 0.02)
    static let amber500 = Color(red: 0.96, green: 0.62, blue: 0.04)
}

// MARK: - 模型颜色映射

enum ModelColors {
    static func color(for modelName: String) -> Color {
        let lower = modelName.lowercased()
        if lower.contains("sonnet") { return Color(nsColor: .systemBlue) }
        if lower.contains("opus")   { return Color(nsColor: .systemTeal) }
        if lower.contains("haiku")  { return Color(nsColor: .systemGreen) }
        return Color(nsColor: .systemOrange)
    }
}

// MARK: - 工具颜色映射

enum ToolColors {
    static func color(for toolName: String) -> Color {
        let lower = toolName.lowercased()
        if ["edit", "write", "read"].contains(where: { lower.contains($0) }) {
            return Color(nsColor: .systemBlue)
        }
        if ["grep", "glob", "search"].contains(where: { lower.contains($0) }) {
            return Color(nsColor: .systemTeal)
        }
        if ["bash", "shell"].contains(where: { lower.contains($0) }) {
            return Color(nsColor: .systemOrange)
        }
        return Color(nsColor: .systemGray)
    }
}
