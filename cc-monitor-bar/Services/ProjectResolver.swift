import Foundation

class ProjectResolver {
    static let shared = ProjectResolver()

    /// 解析项目 ID：规范化路径 + Git 根目录匹配
    func resolveProjectId(from path: String) -> String {
        // 1. 规范化路径
        let normalized = normalizePath(path)

        // 2. 查找 Git 根目录
        if let gitRoot = findGitRoot(from: normalized) {
            return gitRoot.lastPathComponent
        }

        // 3. 返回规范化路径的最后一部分
        return normalized.lastPathComponent
    }

    /// 规范化路径
    private func normalizePath(_ path: String) -> String {
        var result = path

        // 去除末尾的 "/"
        while result.hasSuffix("/") {
            result.removeLast()
        }

        // 解析 "~"
        if result.hasPrefix("~") {
            let homePath = FileManager.default.homeDirectoryForCurrentUser.path
            result = result.replacingCharacters(in: ..<result.index(after: result.startIndex), with: homePath)
        }

        // 解析 "." 和 ".."
        let components = result.components(separatedBy: "/").filter { !$0.isEmpty && $0 != "." }
        var resolved: [String] = []

        for component in components {
            if component == ".." {
                _ = resolved.popLast()
            } else {
                resolved.append(component)
            }
        }

        return "/" + resolved.joined(separator: "/")
    }

    /// 向上查找 .git 目录
    private func findGitRoot(from path: String) -> URL? {
        var currentURL = URL(fileURLWithPath: path)

        while currentURL.path != "/" {
            let gitURL = currentURL.appendingPathComponent(".git")
            if FileManager.default.fileExists(atPath: gitURL.path) {
                return currentURL
            }
            currentURL.deleteLastPathComponent()
        }

        return nil
    }
}

extension String {
    var lastPathComponent: String {
        (self as NSString).lastPathComponent
    }
}
