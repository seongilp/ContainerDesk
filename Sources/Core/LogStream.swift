import Foundation

/// Streams lines from a long-running process (e.g. `container logs --follow`).
final class LogStream {
    private let process = Process()
    private let pipe = Pipe()
    private var buffer = Data()
    private let onLine: (String) -> Void
    private let onEnd: () -> Void
    private let lock = NSLock()
    private var finished = false

    init(
        executable: String,
        arguments: [String],
        onLine: @escaping (String) -> Void,
        onEnd: @escaping () -> Void
    ) {
        self.onLine = onLine
        self.onEnd = onEnd
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.environment = CommandRunner.enrichedEnvironment()
        process.standardOutput = pipe
        process.standardError = pipe
    }

    func start() throws {
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let self else { return }
            let data = handle.availableData
            if data.isEmpty {
                self.finish()
            } else {
                self.consume(data)
            }
        }
        process.terminationHandler = { [weak self] _ in
            self?.finish()
        }
        try process.run()
    }

    func cancel() {
        if process.isRunning {
            process.terminate()
        }
        finish()
    }

    private func consume(_ data: Data) {
        lock.lock()
        buffer.append(data)
        var lines: [String] = []
        while let newlineIndex = buffer.firstIndex(of: UInt8(ascii: "\n")) {
            let lineData = buffer.subdata(in: buffer.startIndex..<newlineIndex)
            buffer.removeSubrange(buffer.startIndex...newlineIndex)
            if let line = String(data: lineData, encoding: .utf8) {
                lines.append(line)
            }
        }
        lock.unlock()

        guard !lines.isEmpty else { return }
        DispatchQueue.main.async { [onLine] in
            lines.forEach(onLine)
        }
    }

    private func finish() {
        lock.lock()
        let alreadyFinished = finished
        finished = true
        let remainder = buffer
        buffer = Data()
        lock.unlock()

        guard !alreadyFinished else { return }
        pipe.fileHandleForReading.readabilityHandler = nil

        DispatchQueue.main.async { [onLine, onEnd] in
            if let tail = String(data: remainder, encoding: .utf8),
               !tail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                onLine(tail)
            }
            onEnd()
        }
    }
}
