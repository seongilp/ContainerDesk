import Foundation

/// An image as reported by `container image ls --format json`.
struct ImageRecord: Decodable, Identifiable, Hashable {
    let id: String
    let configuration: Configuration
    let variants: [Variant]?

    struct Configuration: Decodable, Hashable {
        let name: String?
        let creationDate: String?
        let descriptor: Descriptor?
    }

    struct Descriptor: Decodable, Hashable {
        let digest: String?
        let mediaType: String?
        let size: Int64?
    }

    struct Variant: Decodable, Hashable {
        let digest: String?
        let size: Int64?
        let platform: VariantPlatform?
    }

    struct VariantPlatform: Decodable, Hashable {
        let architecture: String?
        let os: String?
    }
}

extension ImageRecord {
    var reference: String { configuration.name ?? id }

    /// "docker.io/library/alpine:latest" → ("docker.io/library/alpine", "latest")
    var repositoryAndTag: (repository: String, tag: String) {
        let ref = reference
        if let colon = ref.lastIndex(of: ":"),
           !ref[ref.index(after: colon)...].contains("/") {
            return (String(ref[..<colon]), String(ref[ref.index(after: colon)...]))
        }
        return (ref, "latest")
    }

    var shortRepository: String {
        let repo = repositoryAndTag.repository
        guard let lastSlash = repo.lastIndex(of: "/") else { return repo }
        return String(repo[repo.index(after: lastSlash)...])
    }

    var shortDigest: String {
        let digest = configuration.descriptor?.digest ?? id
        let hex = digest.replacingOccurrences(of: "sha256:", with: "")
        return String(hex.prefix(12))
    }

    /// Size of the variant matching the host platform, falling back to the largest variant.
    var displaySize: Int64 {
        let all = variants ?? []
        #if arch(arm64)
        let hostArch = "arm64"
        #else
        let hostArch = "amd64"
        #endif
        if let native = all.first(where: {
            $0.platform?.architecture == hostArch && $0.platform?.os == "linux"
        }), let size = native.size {
            return size
        }
        return all.compactMap(\.size).max() ?? (configuration.descriptor?.size ?? 0)
    }
}
