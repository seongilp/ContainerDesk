import SwiftUI

struct VolumesView: View {
    @Environment(AppStore.self) private var store
    @State private var searchText = ""
    @State private var showCreateSheet = false
    @State private var pendingDelete: VolumeRecord?
    @State private var selectedID: VolumeRecord.ID?

    private var filtered: [VolumeRecord] {
        let sorted = store.volumes.sorted { $0.name < $1.name }
        guard !searchText.isEmpty else { return sorted }
        return sorted.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        Group {
            if filtered.isEmpty && store.hasLoadedOnce {
                EmptyStateView(
                    icon: "externaldrive",
                    title: searchText.isEmpty ? "No volumes" : "No matches",
                    message: searchText.isEmpty
                        ? "Create a volume to persist container data."
                        : "No volumes match \"\(searchText)\"."
                )
            } else {
                volumeTable
            }
        }
        .navigationTitle("Volumes")
        .navigationSubtitle("\(store.volumes.count) total")
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search volumes")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreateSheet = true
                } label: {
                    Label("Create", systemImage: "plus")
                }
                .help("Create a volume")
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            NameOnlySheet(
                title: "Create a volume",
                placeholder: "volume name",
                submitLabel: "Create"
            ) { name in
                await store.createVolume(name)
            }
        }
        .confirmationDialog(
            "Delete volume \"\(pendingDelete?.name ?? "")\"?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let target = pendingDelete { store.deleteVolume(target.name) }
                pendingDelete = nil
            }
        }
    }

    private var volumeTable: some View {
        Table(filtered, selection: $selectedID) {
            TableColumn("Name") { volume in
                Text(volume.name)
                    .font(.system(size: 13, weight: .medium))
            }
            .width(min: 120, ideal: 180)

            TableColumn("Driver") { volume in
                Text(volume.configuration.driver ?? "—")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .width(min: 60, ideal: 80, max: 100)

            TableColumn("Format") { volume in
                Text(volume.configuration.format ?? "—")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .width(min: 60, ideal: 80, max: 100)

            TableColumn("Capacity") { volume in
                Text(Formatters.bytes(volume.configuration.sizeInBytes))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .width(min: 70, ideal: 90, max: 110)

            TableColumn("Created") { volume in
                RelativeTimeText(iso: volume.configuration.creationDate)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .width(min: 80, ideal: 100, max: 130)

            TableColumn("Actions") { volume in
                RowActionButton(systemImage: "trash", help: "Delete", tint: .red) {
                    pendingDelete = volume
                }
            }
            .width(min: 50, ideal: 60, max: 80)
        }
        .tableStyle(.inset)
    }
}

/// Reusable single-text-field creation sheet (volumes, networks).
struct NameOnlySheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let placeholder: String
    let submitLabel: String
    let onSubmit: (String) async -> Bool

    @State private var name = ""
    @State private var isWorking = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title3.weight(.semibold))
            TextField("Name", text: $name, prompt: Text(placeholder))
                .textFieldStyle(.roundedBorder)
                .onSubmit { submit() }
            Spacer()
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button {
                    submit()
                } label: {
                    if isWorking {
                        ProgressView().controlSize(.small)
                    } else {
                        Text(submitLabel)
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isWorking)
            }
        }
        .padding(20)
        .frame(width: 380, height: 160)
    }

    private func submit() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !isWorking else { return }
        isWorking = true
        Task {
            let succeeded = await onSubmit(trimmed)
            isWorking = false
            if succeeded { dismiss() }
        }
    }
}
