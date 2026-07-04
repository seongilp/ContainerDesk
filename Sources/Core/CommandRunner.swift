import Foundation

/// Result of running an external command.
struct CommandResult {
    let stdout: String
    let stderr: String
    let exitCode: Int32

    var succeeded: Bool { exitCode == 0 }
}

enum CommandError: LocalizedError {
    case binaryNotFound
    case failed(command: String, stderr: String, exitCode: Int32)

    var errorDescription: String? {
        switch self {
        case .binaryNotFound:
            return "The `container` CLI was not found. Install it from https://github.com/apple/container"
        case .failed(let command, let stderr, let exitCode):
            let detail = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return "`\(command)` failed (exit \(exitCode))\(detail.isEmpty ? "" : ": \(detail)")"
        }
    }
}

/// Runs external processes asynchronously without blocking the main thread.
enum CommandRunner {

    /// Run a command to completion and capture output.
    static func run(_ executable: String, _ arguments: [String]) async throws -> CommandResult {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try runSync(executable, arguments)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Run a command and throw if it exits non-zero. Returns stdout.
    @discardableResult
    static func runChecked(_ executable: String, _ arguments: [String]) async throws -> String {
        let result = try await run(executable, arguments)
        guard result.succeeded else {
            let display = ([URL(fileURLWithPath: executable).lastPathComponent] + arguments)
                .joined(separator: " ")
            throw CommandError.failed(
                command: display,
                stderr: result.stderr.isEmpty ? result.stdout : result.stderr,
                exitCode: result.exitCode
            )
        }
        return result.stdout
    }

    private static func runSync(_ executable: String, _ arguments: [String]) throws -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.environment = enrichedEnvironment()

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()

        // Drain pipes on background queues to avoid deadlock on large output.
        var stdoutData = Data()
        var stderrData = Data()
        let group = DispatchGroup()

        group.enter()
        DispatchQueue.global(qos: .utility).async {
            stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        group.enter()
        DispatchQueue.global(qos: .utility).async {
            stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }

        process.waitUntilExit()
        group.wait()

        return CommandResult(
            stdout: String(data: stdoutData, encoding: .utf8) ?? "",
            stderr: String(data: stderrData, encoding: .utf8) ?? "",
            exitCode: process.terminationStatus
        )
    }

    /// GUI apps launched from Finder get a minimal PATH; make sure Homebrew paths are present.
    static func enrichedEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        let extraPaths = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"]
        let current = env["PATH"] ?? ""
        let merged = (current.split(separator: ":").map(String.init) + extraPaths)
        var seen = Set<String>()
        env["PATH"] = merged.filter { seen.insert($0).inserted }.joined(separator: ":")
        return env
    }
}
