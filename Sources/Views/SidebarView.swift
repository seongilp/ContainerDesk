import SwiftUI

struct SidebarView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var store = store
        VStack(spacing: 0) {
            List(selection: $store.selectedSection) {
                Section("Resources") {
                    ForEach(SidebarSection.allCases) { section in
                        Label {
                            HStack {
                                Text(section.rawValue)
                                Spacer()
                                Text(count(for: section))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        } icon: {
                            Image(systemName: section.icon)
                        }
                        .tag(section)
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()
            EngineStatusBar()
        }
    }

    private func count(for section: SidebarSection) -> String {
        guard store.engineState == .running else { return "" }
        switch section {
        case .containers:
            return "\(store.runningContainerCount)/\(store.containers.count)"
        case .images:
            return "\(store.images.count)"
        case .volumes:
            return "\(store.volumes.count)"
        case .networks:
            return "\(store.networks.count)"
        }
    }
}

/// Docker Desktop-style engine status footer with a start/stop control.
struct EngineStatusBar: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 9, height: 9)
                .shadow(color: statusColor.opacity(0.6), radius: 3)

            Text(statusLabel)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            Spacer()

            if store.cliAvailable {
                if case .transitioning = store.engineState {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button {
                        store.toggleEngine()
                    } label: {
                        Image(systemName: store.engineState == .running ? "stop.fill" : "play.fill")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help(store.engineState == .running ? "Stop engine" : "Start engine")
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var statusColor: Color {
        switch store.engineState {
        case .running: return .green
        case .stopped: return .red
        case .transitioning: return .orange
        case .unknown: return .gray
        }
    }

    private var statusLabel: String {
        switch store.engineState {
        case .running: return "Engine running"
        case .stopped: return "Engine stopped"
        case .transitioning(let label): return label
        case .unknown: return "Checking…"
        }
    }
}
