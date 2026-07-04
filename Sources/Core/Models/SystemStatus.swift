import Foundation

/// Output of `container system status --format json`.
struct SystemStatus: Decodable {
    let status: String?
    let apiServerVersion: String?
    let appRoot: String?
    let installRoot: String?

    var isRunning: Bool { status == "running" }
}
