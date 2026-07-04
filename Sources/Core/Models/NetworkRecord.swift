import Foundation

/// A network as reported by `container network ls --format json`.
struct NetworkRecord: Decodable, Identifiable, Hashable {
    let id: String
    let configuration: Configuration
    let status: Status?

    struct Configuration: Decodable, Hashable {
        let name: String?
        let mode: String?
        let plugin: String?
        let creationDate: String?
        let labels: [String: String]?
    }

    struct Status: Decodable, Hashable {
        let ipv4Subnet: String?
        let ipv4Gateway: String?
        let ipv6Subnet: String?
    }

    var name: String { configuration.name ?? id }

    var isBuiltin: Bool {
        configuration.labels?["com.apple.container.resource.role"] == "builtin"
    }
}
