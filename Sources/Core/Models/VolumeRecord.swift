import Foundation

/// A volume as reported by `container volume ls --format json`.
struct VolumeRecord: Decodable, Identifiable, Hashable {
    let id: String
    let configuration: Configuration

    struct Configuration: Decodable, Hashable {
        let name: String?
        let driver: String?
        let format: String?
        let sizeInBytes: Int64?
        let source: String?
        let creationDate: String?
    }

    var name: String { configuration.name ?? id }
}
