import SwiftUI

struct MainView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var store = store
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        } detail: {
            ZStack(alignment: .top) {
                detailContent
                if let error = store.lastError {
                    ErrorBanner(message: error) {
                        withAnimation { store.lastError = nil }
                    }
                    .zIndex(1)
                }
            }
        }
        .navigationTitle("")
    }

    @ViewBuilder
    private var detailContent: some View {
        if !store.cliAvailable {
            CLIMissingView()
        } else if store.engineState == .stopped || isTransitioning {
            EngineOffView()
        } else {
            switch store.selectedSection {
            case .containers: ContainersView()
            case .images: ImagesView()
            case .volumes: VolumesView()
            case .networks: NetworksView()
            }
        }
    }

    private var isTransitioning: Bool {
        if case .transitioning = store.engineState { return true }
        return false
    }
}

/// Shown when the `container` binary isn't installed.
struct CLIMissingView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "shippingbox.and.arrow.backward")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.tertiary)
            Text("container CLI not found")
                .font(.title2.weight(.semibold))
            Text("Install Apple's container tool, then relaunch:")
                .foregroundStyle(.secondary)
            Text("brew install container")
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                .textSelection(.enabled)
            Link("github.com/apple/container",
                 destination: URL(string: "https://github.com/apple/container")!)
                .font(.callout)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Shown when the engine (apiserver) is stopped or transitioning.
struct EngineOffView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        VStack(spacing: 16) {
            if case .transitioning(let label) = store.engineState {
                ProgressView()
                    .controlSize(.large)
                Text(label)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "power.circle")
                    .font(.system(size: 52, weight: .light))
                    .foregroundStyle(.tertiary)
                Text("Container engine is stopped")
                    .font(.title2.weight(.semibold))
                Text("Start the engine to manage containers, images, volumes and networks.")
                    .foregroundStyle(.secondary)
                Button {
                    store.toggleEngine()
                } label: {
                    Label("Start Engine", systemImage: "play.fill")
                        .padding(.horizontal, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
