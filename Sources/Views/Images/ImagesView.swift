import SwiftUI

struct ImagesView: View {
    @Environment(AppStore.self) private var store
    @State private var searchText = ""
    @State private var showPullSheet = false
    @State private var pendingDelete: ImageRecord?
    @State private var runImage: ImageRecord?
    @State private var selectedID: ImageRecord.ID?

    private var filtered: [ImageRecord] {
        let sorted = store.images.sorted { $0.reference < $1.reference }
        guard !searchText.isEmpty else { return sorted }
        return sorted.filter { $0.reference.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        Group {
            if filtered.isEmpty && store.hasLoadedOnce {
                EmptyStateView(
                    icon: "square.stack.3d.up",
                    title: searchText.isEmpty ? "No images" : "No matches",
                    message: searchText.isEmpty
                        ? "Pull an image from a registry to get started."
                        : "No images match \"\(searchText)\"."
                )
            } else {
                imageTable
            }
        }
        .navigationTitle("Images")
        .navigationSubtitle("\(store.images.count) local")
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search images")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    store.pruneImages()
                } label: {
                    Label("Prune unused", systemImage: "trash.slash")
                }
                .help("Remove unreferenced images")

                Button {
                    showPullSheet = true
                } label: {
                    Label("Pull", systemImage: "arrow.down.circle")
                }
                .help("Pull an image from a registry")
            }
        }
        .sheet(isPresented: $showPullSheet) {
            PullImageSheet()
        }
        .sheet(item: $runImage) { image in
            RunContainerSheet(prefilledImage: image.reference)
        }
        .confirmationDialog(
            "Delete image \"\(pendingDelete?.reference ?? "")\"?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let target = pendingDelete { store.deleteImage(target) }
                pendingDelete = nil
            }
        }
    }

    private var imageTable: some View {
        Table(filtered, selection: $selectedID) {
            TableColumn("Repository") { image in
                VStack(alignment: .leading, spacing: 2) {
                    Text(image.shortRepository)
                        .font(.system(size: 13, weight: .medium))
                    Text(image.repositoryAndTag.repository)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
            }
            .width(min: 160, ideal: 220)

            TableColumn("Tag") { image in
                Text(image.repositoryAndTag.tag)
                    .font(.system(size: 12, design: .monospaced))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(.quaternary.opacity(0.6), in: Capsule())
            }
            .width(min: 70, ideal: 90, max: 140)

            TableColumn("Digest") { image in
                Text(image.shortDigest)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .width(min: 100, ideal: 120, max: 140)

            TableColumn("Size") { image in
                Text(Formatters.bytes(image.displaySize))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .width(min: 60, ideal: 80, max: 100)

            TableColumn("Created") { image in
                RelativeTimeText(iso: image.configuration.creationDate)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .width(min: 80, ideal: 100, max: 130)

            TableColumn("Actions") { image in
                HStack(spacing: 6) {
                    if store.busyImageIDs.contains(image.id) {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 24, height: 24)
                    } else {
                        RowActionButton(systemImage: "play.fill", help: "Run container", tint: .green) {
                            runImage = image
                        }
                        RowActionButton(systemImage: "trash", help: "Delete", tint: .red) {
                            pendingDelete = image
                        }
                    }
                }
            }
            .width(min: 70, ideal: 80, max: 100)
        }
        .tableStyle(.inset)
    }
}
