import SwiftUI

struct ContainerDetailView: View {
    @Environment(AppStore.self) private var store
    let container: ContainerRecord
    let onBack: () -> Void

    @State private var selectedTab: DetailTab = .logs

    enum DetailTab: String, CaseIterable, Identifiable {
        case logs = "Logs"
        case info = "Info"
        case inspect = "Inspect"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            Picker("", selection: $selectedTab) {
                ForEach(DetailTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 320)
            .padding(.vertical, 10)

            Divider()

            switch selectedTab {
            case .logs: LogsView(containerID: container.id, isRunning: container.state.isRunning)
            case .info: ContainerInfoView(container: container)
            case .inspect: InspectView(containerID: container.id)
            }
        }
        .navigationTitle("")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if container.state.isRunning {
                    Button {
                        store.openShell(container.id)
                    } label: {
                        Label("Shell", systemImage: "terminal")
                    }
                    .help("Open shell in Terminal")
                    Button {
                        store.stopContainer(container.id)
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                    }
                } else {
                    Button {
                        store.startContainer(container.id)
                    } label: {
                        Label("Start", systemImage: "play.fill")
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                onBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .help("Back to containers")

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 10) {
                    Text(container.id)
                        .font(.title3.weight(.semibold))
                    StatusBadge(state: container.state)
                }
                Text(container.imageReference)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if store.busyContainerIDs.contains(container.id) {
                ProgressView().controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

/// Static configuration details.
struct ContainerInfoView: View {
    let container: ContainerRecord

    var body: some View {
        ScrollView {
            Grid(alignment: .topLeading, horizontalSpacing: 16, verticalSpacing: 8) {
                InfoRow(label: "ID", value: container.id)
                InfoRow(label: "Image", value: container.imageReference)
                InfoRow(label: "State", value: container.state.displayName)
                InfoRow(label: "Command", value: container.command.isEmpty ? "—" : container.command)
                InfoRow(label: "IP Address", value: container.ipv4Address ?? "—")
                InfoRow(label: "Ports", value: container.portsSummary ?? "—")
                InfoRow(
                    label: "CPUs",
                    value: container.configuration.resources?.cpus.map(String.init) ?? "—"
                )
                InfoRow(
                    label: "Memory",
                    value: Formatters.bytes(container.configuration.resources?.memoryInBytes)
                )
                InfoRow(
                    label: "Platform",
                    value: [
                        container.configuration.platform?.os,
                        container.configuration.platform?.architecture,
                    ].compactMap { $0 }.joined(separator: "/")
                )
                InfoDateRow(label: "Created", iso: container.configuration.creationDate)
                if container.state.isRunning {
                    InfoDateRow(label: "Started", iso: container.status?.startedDate)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Pretty-printed `container inspect` JSON.
struct InspectView: View {
    @Environment(AppStore.self) private var store
    let containerID: String
    @State private var json = ""
    @State private var loading = true

    var body: some View {
        Group {
            if loading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView([.vertical, .horizontal]) {
                    Text(json)
                        .font(.system(size: 11.5, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .task(id: containerID) {
            loading = true
            do {
                json = try await store.cli?.inspectContainer(containerID) ?? ""
            } catch {
                json = "Failed to inspect: \(error.localizedDescription)"
            }
            loading = false
        }
    }
}
