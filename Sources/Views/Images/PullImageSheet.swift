import SwiftUI

/// Prompt for `container image pull`.
struct PullImageSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var reference = ""
    @State private var errorMessage: String?

    private static let suggestions = [
        "alpine:latest", "ubuntu:latest", "nginx:latest",
        "redis:latest", "postgres:latest", "python:3-slim", "node:lts-slim",
    ]

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Pull an image")
                    .font(.title3.weight(.semibold))

                TextField("Image reference", text: $reference, prompt: Text("e.g. nginx:latest"))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, design: .monospaced))
                    .disabled(store.isPulling)
                    .onSubmit { submit() }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Popular")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    FlowLayout(spacing: 6) {
                        ForEach(Self.suggestions, id: \.self) { suggestion in
                            Button {
                                reference = suggestion
                            } label: {
                                Text(suggestion)
                                    .font(.system(size: 11, design: .monospaced))
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 4)
                                    .background(
                                        reference == suggestion
                                            ? AnyShapeStyle(Color.accentColor.opacity(0.35))
                                            : AnyShapeStyle(.quaternary.opacity(0.5)),
                                        in: Capsule()
                                    )
                            }
                            .buttonStyle(.plain)
                            .disabled(store.isPulling)
                        }
                    }
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.red)
                        .lineLimit(3)
                        .textSelection(.enabled)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Divider()

            HStack(spacing: 10) {
                if store.isPulling {
                    ProgressView()
                        .controlSize(.small)
                    Text("Pulling \(reference)…")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .disabled(store.isPulling)
                Button("Pull") { submit() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(reference.trimmingCharacters(in: .whitespaces).isEmpty || store.isPulling)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(.bar)
        }
        .frame(width: 460, height: errorMessage == nil ? 280 : 320)
    }

    private func submit() {
        let trimmed = reference.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        errorMessage = nil
        Task {
            let succeeded = await store.pullImage(trimmed)
            if succeeded {
                dismiss()
            } else {
                errorMessage = store.lastError
                store.lastError = nil
            }
        }
    }
}
