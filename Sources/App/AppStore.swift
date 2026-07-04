import SwiftUI
import Observation

enum SidebarSection: String, CaseIterable, Identifiable {
    case containers = "Containers"
    case images = "Images"
    case volumes = "Volumes"
    case networks = "Networks"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .containers: return "shippingbox"
        case .images: return "square.stack.3d.up"
        case .volumes: return "externaldrive"
        case .networks: return "network"
        }
    }
}

enum EngineState: Equatable {
    case unknown
    case running
    case stopped
    case transitioning(String) // "Starting…" / "Stopping…"
}

@MainActor
@Observable
final class AppStore {
    let cli: ContainerCLI?

    var selectedSection: SidebarSection = .containers
    var engineState: EngineState = .unknown
    var containers: [ContainerRecord] = []
    var images: [ImageRecord] = []
    var volumes: [VolumeRecord] = []
    var networks: [NetworkRecord] = []

    var lastError: String?
    var busyContainerIDs: Set<String> = []
    var busyImageIDs: Set<String> = []
    var isPulling = false
    var hasLoadedOnce = false

    private var pollTask: Task<Void, Never>?

    init(cli: ContainerCLI? = ContainerCLI.locate()) {
        self.cli = cli
    }

    var cliAvailable: Bool { cli != nil }

    var runningContainerCount: Int {
        containers.filter { $0.state.isRunning }.count
    }

    // MARK: - Lifecycle

    func startPolling() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh(quietly: true)
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    // MARK: - Refresh

    func refresh(quietly: Bool = false) async {
        guard let cli else { return }
        do {
            let status = try await cli.systemStatus()
            if case .transitioning = engineState {
                // Keep showing the transition label until the toggle finishes.
            } else {
                engineState = status.isRunning ? .running : .stopped
            }
            guard status.isRunning else {
                hasLoadedOnce = true
                return
            }

            async let containersTask = cli.listContainers()
            async let imagesTask = cli.listImages()
            async let volumesTask = cli.listVolumes()
            async let networksTask = cli.listNetworks()

            containers = try await containersTask
            images = try await imagesTask
            volumes = try await volumesTask
            networks = try await networksTask
            hasLoadedOnce = true
        } catch {
            hasLoadedOnce = true
            if !quietly {
                lastError = error.localizedDescription
            }
        }
    }

    // MARK: - Engine

    func toggleEngine() {
        guard let cli else { return }
        let wasRunning = engineState == .running
        engineState = .transitioning(wasRunning ? "Stopping…" : "Starting…")
        Task {
            do {
                if wasRunning {
                    try await cli.systemStop()
                    containers = []
                } else {
                    try await cli.systemStart()
                }
                engineState = .unknown
                await refresh()
            } catch {
                lastError = error.localizedDescription
                engineState = .unknown
                await refresh()
            }
        }
    }

    // MARK: - Container actions

    func startContainer(_ id: String) {
        performContainerAction(id) { try await $0.startContainer(id) }
    }

    func stopContainer(_ id: String) {
        performContainerAction(id) { try await $0.stopContainer(id) }
    }

    func killContainer(_ id: String) {
        performContainerAction(id) { try await $0.killContainer(id) }
    }

    func deleteContainer(_ id: String, force: Bool = false) {
        performContainerAction(id) { try await $0.deleteContainer(id, force: force) }
    }

    func pruneContainers() {
        guard let cli else { return }
        Task {
            do {
                try await cli.pruneContainers()
                await refresh()
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    func openShell(_ id: String) {
        guard let cli else { return }
        Task {
            do {
                try await cli.openShellInTerminal(id)
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    func runContainer(_ options: RunOptions) async -> Bool {
        guard let cli else { return false }
        do {
            try await cli.runContainer(options)
            await refresh()
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    private func performContainerAction(
        _ id: String,
        _ action: @escaping (ContainerCLI) async throws -> Void
    ) {
        guard let cli, !busyContainerIDs.contains(id) else { return }
        busyContainerIDs.insert(id)
        Task {
            do {
                try await action(cli)
            } catch {
                lastError = error.localizedDescription
            }
            busyContainerIDs.remove(id)
            await refresh()
        }
    }

    // MARK: - Image actions

    func pullImage(_ reference: String) async -> Bool {
        guard let cli else { return false }
        isPulling = true
        defer { isPulling = false }
        do {
            try await cli.pullImage(reference)
            await refresh()
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func deleteImage(_ image: ImageRecord) {
        guard let cli, !busyImageIDs.contains(image.id) else { return }
        busyImageIDs.insert(image.id)
        Task {
            do {
                try await cli.deleteImage(image.reference)
            } catch {
                lastError = error.localizedDescription
            }
            busyImageIDs.remove(image.id)
            await refresh()
        }
    }

    func pruneImages() {
        guard let cli else { return }
        Task {
            do {
                try await cli.pruneImages()
                await refresh()
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    // MARK: - Volume actions

    func createVolume(_ name: String) async -> Bool {
        guard let cli else { return false }
        do {
            try await cli.createVolume(name)
            await refresh()
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func deleteVolume(_ name: String) {
        guard let cli else { return }
        Task {
            do {
                try await cli.deleteVolume(name)
            } catch {
                lastError = error.localizedDescription
            }
            await refresh()
        }
    }

    // MARK: - Network actions

    func createNetwork(_ name: String) async -> Bool {
        guard let cli else { return false }
        do {
            try await cli.createNetwork(name)
            await refresh()
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func deleteNetwork(_ name: String) {
        guard let cli else { return }
        Task {
            do {
                try await cli.deleteNetwork(name)
            } catch {
                lastError = error.localizedDescription
            }
            await refresh()
        }
    }
}
