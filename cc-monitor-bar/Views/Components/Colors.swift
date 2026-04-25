import SwiftUI

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
