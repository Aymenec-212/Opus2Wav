import SwiftUI
import AppKit

struct ControlBarView: View {
    @EnvironmentObject private var engine: ConversionEngine

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Output")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(action: chooseOutputDirectory) {
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                        Text(engine.outputDirectory.path)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .buttonStyle(.link)
            }

            Spacer()

            Text(summary)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            Button("Clear Done") { engine.clearCompleted() }
                .disabled(!hasCompleted)

            if engine.isRunning {
                Button(role: .destructive, action: engine.cancel) {
                    Label("Cancel", systemImage: "stop.fill")
                }
                .keyboardShortcut(".", modifiers: .command)
            } else {
                Button(action: engine.start) {
                    Label("Start", systemImage: "play.fill")
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(!hasPending)
            }
        }
    }

    private var hasCompleted: Bool {
        engine.tasks.contains { $0.status.isTerminal }
    }

    private var hasPending: Bool {
        engine.tasks.contains { !$0.status.isTerminal }
    }

    private var summary: String {
        let total = engine.tasks.count
        let done = engine.tasks.filter { if case .completed = $0.status { return true } else { return false } }.count
        let failed = engine.tasks.filter { if case .failed = $0.status { return true } else { return false } }.count
        return "\(done)/\(total) done · \(failed) failed · \(engine.workerCap) workers"
    }

    private func chooseOutputDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = engine.outputDirectory
        panel.prompt = "Choose"
        if panel.runModal() == .OK, let url = panel.url {
            engine.outputDirectory = url
        }
    }
}
