import SwiftUI

/// Live-following log viewer for a container.
struct LogsView: View {
    @Environment(AppStore.self) private var store
    let containerID: String
    let isRunning: Bool

    @State private var lines: [LogLine] = []
    @State private var stream: LogStream?
    @State private var following = true
    @State private var autoScroll = true

    struct LogLine: Identifiable {
        let id: Int
        let text: String
    }

    private static let maxLines = 5000

    var body: some View {
        VStack(spacing: 0) {
            logArea
            Divider()
            controls
        }
        .task(id: containerID) {
            await reload()
        }
        .onDisappear {
            stream?.cancel()
            stream = nil
        }
    }

    private var logArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(lines) { line in
                        Text(line.text.isEmpty ? " " : line.text)
                            .font(.system(size: 11.5, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(line.id)
                    }
                    if lines.isEmpty {
                        Text("No log output yet.")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                            .padding(.top, 20)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(12)
            }
            .background(logBackground)
            .onChange(of: lines.count) {
                if autoScroll, let last = lines.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    private var logBackground: Color {
        Color(nsColor: .textBackgroundColor)
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Toggle("Auto-scroll", isOn: $autoScroll)
                .toggleStyle(.checkbox)
                .font(.system(size: 12))

            Spacer()

            Text("\(lines.count) lines")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .monospacedDigit()

            Button {
                lines = []
            } label: {
                Label("Clear", systemImage: "xmark.circle")
            }
            .controlSize(.small)

            Button {
                Task { await reload() }
            } label: {
                Label("Reload", systemImage: "arrow.clockwise")
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func reload() async {
        stream?.cancel()
        stream = nil
        lines = []

        guard let cli = store.cli else { return }

        if isRunning {
            // Follow live output; `container logs --follow` replays existing lines first.
            var counter = 0
            do {
                stream = try cli.followLogs(containerID) { line in
                    counter += 1
                    appendLine(LogLine(id: counter, text: line))
                } onEnd: {
                    stream = nil
                }
            } catch {
                lines = [LogLine(id: 0, text: "Failed to stream logs: \(error.localizedDescription)")]
            }
        } else {
            do {
                let output = try await cli.fetchLogs(containerID, lines: Self.maxLines)
                lines = output
                    .split(separator: "\n", omittingEmptySubsequences: false)
                    .enumerated()
                    .map { LogLine(id: $0.offset, text: String($0.element)) }
            } catch {
                lines = [LogLine(id: 0, text: "Failed to fetch logs: \(error.localizedDescription)")]
            }
        }
    }

    private func appendLine(_ line: LogLine) {
        lines.append(line)
        if lines.count > Self.maxLines {
            lines.removeFirst(lines.count - Self.maxLines)
        }
    }
}
