import Foundation

/// 使用 DispatchSourceFileSystemObject 监控活跃会话 JSONL 文件写入事件
/// 文件变更时立即触发增量解析，比轮询更快感知数据变化
final class FileWatcher {
    // MARK: - Types

    typealias OnFileChange = (String) -> Void

    // MARK: - Properties

    private let queue = DispatchQueue(label: "cc.monitor-bar.FileWatcher", qos: .userInitiated)
    private var sources: [String: DispatchSourceFileSystemObject] = [:]
    private let lock = NSLock()
    private var onChangeHandler: OnFileChange?

    // MARK: - Public

    /// 设置变更回调
    func setOnChangeHandler(_ handler: @escaping OnFileChange) {
        onChangeHandler = handler
    }

    /// 开始监控一组文件路径
    func watch(paths: Set<String>) {
        lock.lock()
        defer { lock.unlock() }

        // 新增的文件：开始监控
        for path in paths {
            guard sources[path] == nil else { continue }
            guard let source = createSource(for: path) else { continue }
            sources[path] = source
        }

        // 不再需要的文件：移除监控
        let toRemove = sources.keys.filter { !paths.contains($0) }
        for path in toRemove {
            sources[path]?.cancel()
            sources[path] = nil
        }
    }

    /// 停止所有监控
    func stopAll() {
        lock.lock()
        defer { lock.unlock() }

        for source in sources.values {
            source.cancel()
        }
        sources.removeAll()
    }

    // MARK: - Private

    private func createSource(for path: String) -> DispatchSourceFileSystemObject? {
        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else { return nil }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend],
            queue: queue
        )

        source.setEventHandler { [weak self] in
            self?.onChangeHandler?(path)
        }

        source.setCancelHandler {
            close(fd)
        }

        source.resume()
        return source
    }
}
