import Foundation

/// Typed wrapper around Apple's `container` CLI.
struct ContainerCLI {
    let binaryPath: String

    private static let candidatePaths = [
        "/opt/homebrew/bin/container",
        "/usr/local/bin/container",
        "/usr/bin/container",
    ]

    static func locate() -> ContainerCLI? {
        for path in candidatePaths where FileManager.default.isExecutableFile(atPath: path) {
            return ContainerCLI(binaryPath: path)
        }
        return nil
    }

    private func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    // MARK: - System

    func systemStatus() async throws -> SystemStatus {
        let result = try await CommandRunner.run(binaryPath, ["system", "status", "--format", "json"])
        guard result.succeeded, let jsonStart = result.stdout.firstIndex(of: "{") else {
            return SystemStatus(status: "stopped", apiServerVersion: nil, appRoot: nil, installRoot: nil)
        }
        return try decode(SystemStatus.self, from: String(result.stdout[jsonStart...]))
    }

    func systemStart() async throws {
        try await CommandRunner.runChecked(binaryPath, ["system", "start"])
    }

    func systemStop() async throws {
        try await CommandRunner.runChecked(binaryPath, ["system", "stop"])
    }

    // MARK: - Containers

    func listContainers() async throws -> [ContainerRecord] {
        let json = try await CommandRunner.runChecked(binaryPath, ["ls", "-a", "--format", "json"])
        return try decode([ContainerRecord].self, from: json)
    }

    func startContainer(_ id: String) async throws {
        try await CommandRunner.runChecked(binaryPath, ["start", id])
    }

    func stopContainer(_ id: String) async throws {
        try await CommandRunner.runChecked(binaryPath, ["stop", id])
    }

    func killContainer(_ id: String) async throws {
        try await CommandRunner.runChecked(binaryPath, ["kill", id])
    }

    func deleteContainer(_ id: String, force: Bool) async throws {
        var args = ["delete", id]
        if force { args.insert("--force", at: 1) }
        try await CommandRunner.runChecked(binaryPath, args)
    }

    func pruneContainers() async throws {
        try await CommandRunner.runChecked(binaryPath, ["prune"])
    }

    func inspectContainer(_ id: String) async throws -> String {
        let json = try await CommandRunner.runChecked(binaryPath, ["inspect", id])
        return Self.prettyPrint(json)
    }

    func fetchLogs(_ id: String, lines: Int) async throws -> String {
        let result = try await CommandRunner.run(binaryPath, ["logs", "-n", String(lines), id])
        return result.succeeded ? result.stdout : result.stderr
    }

    func followLogs(
        _ id: String,
        onLine: @escaping (String) -> Void,
        onEnd: @escaping () -> Void
    ) throws -> LogStream {
        let stream = LogStream(
            executable: binaryPath,
            arguments: ["logs", "--follow", id],
            onLine: onLine,
            onEnd: onEnd
        )
        try stream.start()
        return stream
    }

    func runContainer(_ options: RunOptions) async throws {
        try await CommandRunner.runChecked(binaryPath, options.buildArguments())
    }

    /// Open Terminal.app with an interactive shell inside the container.
    func openShellInTerminal(_ id: String) async throws {
        let command = "\(binaryPath) exec -it \(id) /bin/sh"
        let script = """
        tell application "Terminal"
            activate
            do script "\(command)"
        end tell
        """
        try await CommandRunner.runChecked("/usr/bin/osascript", ["-e", script])
    }

    // MARK: - Images

    func listImages() async throws -> [ImageRecord] {
        let json = try await CommandRunner.runChecked(binaryPath, ["image", "ls", "--format", "json"])
        return try decode([ImageRecord].self, from: json)
    }

    func pullImage(_ reference: String) async throws {
        try await CommandRunner.runChecked(binaryPath, ["image", "pull", reference])
    }

    func deleteImage(_ reference: String) async throws {
        try await CommandRunner.runChecked(binaryPath, ["image", "delete", reference])
    }

    func pruneImages() async throws {
        try await CommandRunner.runChecked(binaryPath, ["image", "prune"])
    }

    // MARK: - Volumes

    func listVolumes() async throws -> [VolumeRecord] {
        let json = try await CommandRunner.runChecked(binaryPath, ["volume", "ls", "--format", "json"])
        return try decode([VolumeRecord].self, from: json)
    }

    func createVolume(_ name: String) async throws {
        try await CommandRunner.runChecked(binaryPath, ["volume", "create", name])
    }

    func deleteVolume(_ name: String) async throws {
        try await CommandRunner.runChecked(binaryPath, ["volume", "delete", name])
    }

    // MARK: - Networks

    func listNetworks() async throws -> [NetworkRecord] {
        let json = try await CommandRunner.runChecked(binaryPath, ["network", "ls", "--format", "json"])
        return try decode([NetworkRecord].self, from: json)
    }

    func createNetwork(_ name: String) async throws {
        try await CommandRunner.runChecked(binaryPath, ["network", "create", name])
    }

    func deleteNetwork(_ name: String) async throws {
        try await CommandRunner.runChecked(binaryPath, ["network", "delete", name])
    }

    // MARK: - Helpers

    static func prettyPrint(_ json: String) -> String {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(
                withJSONObject: object,
                options: [.prettyPrinted, .sortedKeys]
              ),
              let string = String(data: pretty, encoding: .utf8)
        else { return json }
        return string
    }
}

/// Options for `container run`.
struct RunOptions {
    var image: String = ""
    var name: String = ""
    var command: String = ""
    var ports: String = ""      // comma separated "8080:80"
    var volumes: String = ""    // comma separated "vol:/path" or "/host:/dest"
    var environment: String = "" // newline separated KEY=VALUE
    var cpus: String = ""
    var memory: String = ""     // e.g. "1g", "512m"
    var removeOnExit: Bool = false

    func buildArguments() -> [String] {
        var args = ["run", "--detach"]
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        if !trimmedName.isEmpty { args += ["--name", trimmedName] }
        if removeOnExit { args.append("--rm") }

        for port in splitList(ports) { args += ["--publish", port] }
        for volume in splitList(volumes) { args += ["--volume", volume] }
        for envLine in environment.split(whereSeparator: \.isNewline) {
            let entry = envLine.trimmingCharacters(in: .whitespaces)
            if !entry.isEmpty { args += ["--env", entry] }
        }

        let trimmedCPUs = cpus.trimmingCharacters(in: .whitespaces)
        if !trimmedCPUs.isEmpty { args += ["--cpus", trimmedCPUs] }
        let trimmedMemory = memory.trimmingCharacters(in: .whitespaces)
        if !trimmedMemory.isEmpty { args += ["--memory", trimmedMemory] }

        args.append(image.trimmingCharacters(in: .whitespaces))

        let commandParts = command.split(separator: " ").map(String.init)
        args += commandParts
        return args
    }

    private func splitList(_ raw: String) -> [String] {
        raw.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
