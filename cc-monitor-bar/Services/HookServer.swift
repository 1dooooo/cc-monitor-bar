import Foundation

/// 本地 Unix socket 服务器，接收 Claude Code hooks 发送的工具调用事件
/// 提供实时工具调用感知，无需轮询
final class HookServer {
    // MARK: - Types

    typealias EventHandler = (HookEvent) -> Void

    // MARK: - Properties

    private let socketPath: String
    private var socketFD: Int32 = -1
    private var eventHandler: ((HookEvent) -> Void)?
    private var connectionSources: [DispatchSourceRead] = []
    private let queue = DispatchQueue(label: "cc.monitor-bar.HookServer", qos: .userInitiated)

    // MARK: - Init / Deinit

    init?(socketPath: String? = nil) {
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = supportDir.appendingPathComponent("cc-monitor-bar")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        self.socketPath = socketPath ?? dir.appendingPathComponent("hooks.sock").path

        socketFD = socket(AF_UNIX, SOCK_STREAM, 0)
        guard socketFD >= 0 else {
            print("HookServer: socket() failed")
            return nil
        }

        // 禁用 SIGPIPE
        var enable = 0
        setsockopt(socketFD, SOL_SOCKET, SO_NOSIGPIPE, &enable, socklen_t(MemoryLayout<Int32>.size))

        // 允许地址重用
        enable = 1
        setsockopt(socketFD, SOL_SOCKET, SO_REUSEADDR, &enable, socklen_t(MemoryLayout<Int32>.size))

        // 如果 socket 文件已存在，删除它
        try? FileManager.default.removeItem(atPath: self.socketPath)

        // 绑定地址
        let bound = self.socketPath.withCString { pathPtr in
            var addr = sockaddr_un()
            addr.sun_family = sa_family_t(AF_UNIX)

            // 复制路径到 sun_path (逐字节)
            var pathIndex = 0
            var p = pathPtr
            while pathIndex < 103 {
                let c = p.pointee
                withUnsafeMutableBytes(of: &addr.sun_path) { buf in
                    let ptr = buf.assumingMemoryBound(to: Int8.self).baseAddress!
                    ptr[pathIndex] = c
                }
                if c == 0 { break }
                pathIndex += 1
                p = p.advanced(by: 1)
            }

            let size = socklen_t(MemoryLayout<sockaddr_un>.stride)
            return withUnsafeBytes(of: &addr) { ptr -> Int32 in
                let sockaddrPtr = ptr.bindMemory(to: sockaddr.self)
                return bind(socketFD, sockaddrPtr.baseAddress!, size)
            }
        }
        guard bound == 0 else {
            print("HookServer: bind() failed for \(self.socketPath)")
            close(socketFD)
            socketFD = -1
            return nil
        }

        // 开始监听
        guard listen(socketFD, 5) == 0 else {
            print("HookServer: listen() failed")
            close(socketFD)
            socketFD = -1
            return nil
        }
    }

    deinit {
        stop()
        try? FileManager.default.removeItem(atPath: socketPath)
    }

    // MARK: - Public

    /// 设置事件处理回调
    func setEventHandler(_ handler: @escaping (HookEvent) -> Void) {
        eventHandler = handler
    }

    /// 开始接受连接
    func start() {
        let fd = dup(socketFD)
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        source.setEventHandler { [weak self] in
            self?.acceptConnection()
        }
        source.setCancelHandler {
            close(fd)
        }
        source.resume()
    }

    /// 停止服务器
    func stop() {
        for source in connectionSources {
            source.cancel()
        }
        connectionSources.removeAll()

        if socketFD >= 0 {
            close(socketFD)
            socketFD = -1
        }
    }

    // MARK: - Private

    private func acceptConnection() {
        let addr = UnsafeMutablePointer<sockaddr>.allocate(capacity: 1)
        var addrLen: socklen_t = socklen_t(MemoryLayout<sockaddr>.size)

        let clientFD = accept(socketFD, addr, &addrLen)
        addr.deallocate()
        guard clientFD >= 0 else { return }

        // 禁用 SIGPIPE
        var enable = 0
        setsockopt(clientFD, SOL_SOCKET, SO_NOSIGPIPE, &enable, socklen_t(MemoryLayout<Int32>.size))

        let fd = dup(clientFD)
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        source.setEventHandler { [weak self] in
            self?.readFromClient(fd, source: source)
        }
        source.setCancelHandler {
            close(fd)
        }
        source.resume()
        connectionSources.append(source)
    }

    private func readFromClient(_ fd: Int32, source: DispatchSourceRead) {
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
        defer { buffer.deallocate() }

        let bytesRead = recv(fd, buffer, 4096, 0)
        guard bytesRead > 0 else {
            source.cancel()
            if let idx = connectionSources.firstIndex(where: { $0 === source }) {
                connectionSources.remove(at: idx)
            }
            return
        }

        let data = Data(bytes: buffer, count: bytesRead)
        if let json = String(data: data, encoding: .utf8) {
            parseAndHandle(json)
        }
    }

    private func parseAndHandle(_ json: String) {
        let lines = json.components(separatedBy: .newlines).filter { !$0.isEmpty }
        for line in lines {
            guard let data = line.data(using: .utf8),
                  let event = try? JSONDecoder().decode(HookEvent.self, from: data) else {
                continue
            }
            DispatchQueue.main.async {
                self.eventHandler?(event)
            }
        }
    }
}
