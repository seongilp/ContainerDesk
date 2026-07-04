import SwiftUI

@main
struct ContainerDeskApp: App {
    @State private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(store)
                .frame(minWidth: 960, minHeight: 620)
                .task {
                    await store.refresh()
                    store.startPolling()
                }
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Refresh") {
                    Task { await store.refresh() }
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}
