import Foundation

extension Int64 {
    /// 格式化 Token 数量为可读字符串
    /// - 1,234,567 → "1.2M"
    /// - 1,234 → "1.2k"
    /// - 123 → "123"
    var formattedTokens: String {
        if self >= 1_000_000 { return String(format: "%.1fM", Double(self) / 1_000_000) }
        if self >= 1_000 { return String(format: "%.1fk", Double(self) / 1_000) }
        return "\(self)"
    }
}
