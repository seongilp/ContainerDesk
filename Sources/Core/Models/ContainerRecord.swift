import Foundation

/// A container as reported by `container ls -a --format json`.
struct ContainerRecord: Decodable, Identifiable, Hashable {
    let id: String
    let configuration: Configuration
    let status: Status?

    struct Configuration: Decodable, Hashable {
        let id: String
        let creationDate: String?
        let image: ImageRef?
        let initProcess: InitProcess?
        let labels: [String: String]?
        let networks: [NetworkAttachment]?
        let publishedPorts: [PublishedPort]?
        let resources: Resources?
        let platform: Platform?
        let mounts: [Mount]?
    }

    struct ImageRef: Decodable, Hashable {
        let reference: String?
    }

    struct InitProcess: Decodable, Hashable {
        let executable: String?
        let arguments: [String]?
        let workingDirectory: String?
        let environment: [String]?
    }

    struct NetworkAttachment: Decodable, Hashable {
        let network: String?
    }

    struct PublishedPort: Decodable, Hashable {
        let hostPort: Int?
        let containerPort: Int?
        let proto: String?

        private enum CodingKeys: String, CodingKey {
            case hostPort, containerPort
            case proto = "protocol"
        }
    }

    struct Resources: Decodable, Hashable {
        let cpus: Int?
        let memoryInBytes: Int64?
    }

    struct Platform: Decodable, Hashable {
        let architecture: String?
        let os: String?
    }

    struct Mount: Decodable, Hashable {
        let destination: String?
    }

    struct Status: Decodable, Hashable {
        let state: String?
        let startedDate: String?
        let networks: [RuntimeNetwork]?
    }

    struct RuntimeNetwork: Decodable, Hashable {
        let hostname: String?
        let ipv4Address: String?
        let network: String?
    }
}

extension ContainerRecord {
    var state: ContainerState {
        ContainerState(rawValue: status?.state ?? "") ?? .unknown
    }

    var imageReference: String { configuration.image?.reference ?? "—" }

    /// "docker.io/library/alpine:latest" → "alpine:latest"
    var shortImage: String {
        let ref = imageReference
        guard let lastSlash = ref.lastIndex(of: "/") else { return ref }
        return String(ref[ref.index(after: lastSlash)...])
    }

    var ipv4Address: String? {
        status?.networks?.first?.ipv4Address?.split(separator: "/").first.map(String.init)
    }

    var command: String {
        let exec = configuration.initProcess?.executable ?? ""
        let args = configuration.initProcess?.arguments ?? []
        return ([exec] + args).joined(separator: " ").trimmingCharacters(in: .whitespaces)
    }

    var portsSummary: String? {
        guard let ports = configuration.publishedPorts, !ports.isEmpty else { return nil }
        return ports
            .map { "\($0.hostPort.map(String.init) ?? "?"):\($0.containerPort.map(String.init) ?? "?")" }
            .joined(separator: ", ")
    }
}

enum ContainerState: String {
    case running
    case stopped
    case stopping
    case creating
    case created
    case paused
    case unknown

    var isRunning: Bool { self == .running }

    var displayName: String {
        self == .unknown ? "Unknown" : rawValue.capitalized
    }
}
