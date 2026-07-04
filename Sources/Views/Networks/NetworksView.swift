import SwiftUI

struct NetworksView: View {
    @Environment(AppStore.self) private var store
    @State private var searchText = ""
    @State private var showCreateSheet = false
    @State private var pendingDelete: NetworkRecord?
    @State private var selectedID: NetworkRecord.ID?

    private var filtered: [NetworkRecord] {
        let sorted = store.networks.sorted { $0.name < $1.name }
        guard !searchText.isEmpty else { return sorted }
        return sorted.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        Group {
            if filtered.isEmpty && store.hasLoadedOnce {
                EmptyStateView(
                    icon: "network",
                    title: searchText.isEmpty ? "No networks" : "No matches",
                    message: searchText.isEmpty
                        ? "Create a network to connect containers."
                        : "No networks match \"\(searchText)\"."
                )
            } else {
                networkTable
            }
        }
        .navigationTitle("Networks")
        .navigationSubtitle("\(store.networks.count) total")
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search networks")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreateSheet = true
                } label: {
                    Label("Create", systemImage: "plus")
                }
                .help("Create a network")
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            NameOnlySheet(
                title: "Create a network",
                placeholder: "network name",
                submitLabel: "Create"
            ) { name in
                await store.createNetwork(name)
            }
        }
        .confirmationDialog(
            "Delete network \"\(pendingDelete?.name ?? "")\"?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let target = pendingDelete { store.deleteNetwork(target.name) }
                pendingDelete = nil
            }
        }
    }

    private var networkTable: some View {
        Table(filtered, selection: $selectedID) {
            TableColumn("Name") { network in
                HStack(spacing: 6) {
                    Text(network.name)
                        .font(.system(size: 13, weight: .medium))
                    if network.isBuiltin {
                        Text("built-in")
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary.opacity(0.6), in: Capsule())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .width(min: 120, ideal: 180)

            TableColumn("Mode") { network in
                Text(network.configuration.mode ?? "—")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .width(min: 50, ideal: 70, max: 90)

            TableColumn("Subnet") { network in
                Text(network.status?.ipv4Subnet ?? "—")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .width(min: 100, ideal: 130, max: 160)

            TableColumn("Gateway") { network in
                Text(network.status?.ipv4Gateway ?? "—")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .width(min: 90, ideal: 110, max: 140)

            TableColumn("Actions") { network in
                if !network.isBuiltin {
                    RowActionButton(systemImage: "trash", help: "Delete", tint: .red) {
                        pendingDelete = network
                    }
                }
            }
            .width(min: 50, ideal: 60, max: 80)
        }
        .tableStyle(.inset)
    }
}
