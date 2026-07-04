import SwiftUI

struct ContainersView: View {
    @Environment(AppStore.self) private var store
    @State private var searchText = ""
    @State private var selectedID: ContainerRecord.ID?
    @State private var tableSelection: ContainerRecord.ID?
    @State private var showRunSheet = false
    @State private var pendingDelete: ContainerRecord?

    private var filtered: [ContainerRecord] {
        let sorted = store.containers.sorted {
            ($0.state.isRunning ? 0 : 1, $0.id) < ($1.state.isRunning ? 0 : 1, $1.id)
        }
        guard !searchText.isEmpty else { return sorted }
        return sorted.filter {
            $0.id.localizedCaseInsensitiveContains(searchText)
                || $0.imageReference.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var selectedContainer: ContainerRecord? {
        store.containers.first { $0.id == selectedID }
    }

    var body: some View {
        Group {
            if let container = selectedContainer {
                ContainerDetailView(container: container) {
                    selectedID = nil
                }
            } else {
                listContent
            }
        }
        .sheet(isPresented: $showRunSheet) {
            RunContainerSheet()
        }
        .confirmationDialog(
            "Delete container \"\(pendingDelete?.id ?? "")\"?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let target = pendingDelete {
                    store.deleteContainer(target.id, force: target.state.isRunning)
                }
                pendingDelete = nil
            }
        }
    }

    private var listContent: some View {
        Group {
            if filtered.isEmpty && store.hasLoadedOnce {
                EmptyStateView(
                    icon: "shippingbox",
                    title: searchText.isEmpty ? "No containers" : "No matches",
                    message: searchText.isEmpty
                        ? "Run your first container to see it here."
                        : "No containers match \"\(searchText)\"."
                )
            } else {
                containerTable
            }
        }
        .navigationTitle("Containers")
        .navigationSubtitle("\(store.runningContainerCount) running")
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search containers")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    store.pruneContainers()
                } label: {
                    Label("Prune stopped", systemImage: "trash.slash")
                }
                .help("Remove all stopped containers")

                Button {
                    showRunSheet = true
                } label: {
                    Label("Run", systemImage: "plus")
                }
                .help("Run a new container")
            }
        }
    }

    private var containerTable: some View {
        Table(filtered, selection: $tableSelection) {
            TableColumn("Status") { container in
                StatusBadge(state: container.state)
            }
            .width(min: 80, ideal: 90, max: 110)

            TableColumn("Name") { container in
                Button {
                    selectedID = container.id
                } label: {
                    Text(container.id)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .help("Open details")
            }
            .width(min: 120, ideal: 180)

            TableColumn("Image") { container in
                Text(container.shortImage)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .width(min: 120, ideal: 180)

            TableColumn("IP") { container in
                Text(container.ipv4Address ?? "—")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .width(min: 90, ideal: 110, max: 140)

            TableColumn("Started") { container in
                Group {
                    if container.state.isRunning {
                        RelativeTimeText(iso: container.status?.startedDate)
                    } else {
                        Text("—")
                    }
                }
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            }
            .width(min: 80, ideal: 100, max: 130)

            TableColumn("Actions") { container in
                ContainerRowActions(container: container) {
                    pendingDelete = container
                } onSelect: {
                    selectedID = container.id
                }
            }
            .width(min: 130, ideal: 140, max: 160)
        }
        .tableStyle(.inset)
        .contextMenu(forSelectionType: ContainerRecord.ID.self) { ids in
            if let id = ids.first, let container = store.containers.first(where: { $0.id == id }) {
                contextMenuItems(for: container)
            }
        } primaryAction: { ids in
            if let id = ids.first { selectedID = id }
        }
    }

    @ViewBuilder
    private func contextMenuItems(for container: ContainerRecord) -> some View {
        Button("Details") { selectedID = container.id }
        Divider()
        if container.state.isRunning {
            Button("Stop") { store.stopContainer(container.id) }
            Button("Kill") { store.killContainer(container.id) }
            Button("Open Shell") { store.openShell(container.id) }
        } else {
            Button("Start") { store.startContainer(container.id) }
        }
        Divider()
        Button("Delete", role: .destructive) { pendingDelete = container }
    }
}

private struct ContainerRowActions: View {
    @Environment(AppStore.self) private var store
    let container: ContainerRecord
    let onDelete: () -> Void
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            if store.busyContainerIDs.contains(container.id) {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 24, height: 24)
            } else if container.state.isRunning {
                RowActionButton(systemImage: "stop.fill", help: "Stop") {
                    store.stopContainer(container.id)
                }
                RowActionButton(systemImage: "terminal", help: "Open shell in Terminal") {
                    store.openShell(container.id)
                }
            } else {
                RowActionButton(systemImage: "play.fill", help: "Start", tint: .green) {
                    store.startContainer(container.id)
                }
            }
            RowActionButton(systemImage: "doc.text", help: "Logs") {
                onSelect()
            }
            RowActionButton(systemImage: "trash", help: "Delete", tint: .red) {
                onDelete()
            }
        }
    }
}
