import SwiftUI

/// Form for `container run`, Docker Desktop "Run new container" style.
struct RunContainerSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var options: RunOptions
    @State private var isRunning = false
    @State private var errorMessage: String?

    init(prefilledImage: String = "") {
        var initial = RunOptions()
        initial.image = prefilledImage
        _options = State(initialValue: initial)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Run a new container")
                    .font(.title3.weight(.semibold))
                Spacer()
            }
            .padding(20)

            Divider()

            Form {
                Section {
                    imageField
                    TextField("Name", text: $options.name, prompt: Text("Optional — auto-generated"))
                    TextField("Command", text: $options.command, prompt: Text("Optional — image default"))
                }
                Section("Networking & Storage") {
                    TextField("Ports", text: $options.ports, prompt: Text("8080:80, 5432:5432"))
                    TextField("Volumes", text: $options.volumes, prompt: Text("myvolume:/data, /host/path:/mnt"))
                }
                Section("Environment") {
                    TextEditor(text: $options.environment)
                        .font(.system(size: 12, design: .monospaced))
                        .frame(height: 60)
                        .overlay(alignment: .topLeading) {
                            if options.environment.isEmpty {
                                Text("KEY=value (one per line)")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 1)
                                    .padding(.leading, 5)
                                    .allowsHitTesting(false)
                            }
                        }
                }
                Section("Resources") {
                    HStack {
                        TextField("CPUs", text: $options.cpus, prompt: Text("4"))
                        TextField("Memory", text: $options.memory, prompt: Text("1g"))
                    }
                    Toggle("Remove container after it stops (--rm)", isOn: $options.removeOnExit)
                }
            }
            .formStyle(.grouped)

            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .lineLimit(3)
                    .textSelection(.enabled)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button {
                    submit()
                } label: {
                    if isRunning {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Run")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(options.image.trimmingCharacters(in: .whitespaces).isEmpty || isRunning)
            }
            .padding(16)
        }
        .frame(width: 520, height: 560)
    }

    @ViewBuilder
    private var imageField: some View {
        HStack {
            TextField("Image", text: $options.image, prompt: Text("alpine:latest"))
            if !store.images.isEmpty {
                Menu {
                    ForEach(store.images) { image in
                        Button(image.reference) {
                            options.image = image.reference
                        }
                    }
                } label: {
                    Image(systemName: "chevron.up.chevron.down")
                }
                .menuStyle(.borderlessButton)
                .frame(width: 24)
                .help("Choose a local image")
            }
        }
    }

    private func submit() {
        isRunning = true
        errorMessage = nil
        Task {
            let succeeded = await store.runContainer(options)
            isRunning = false
            if succeeded {
                dismiss()
            } else {
                errorMessage = store.lastError
                store.lastError = nil
            }
        }
    }
}
