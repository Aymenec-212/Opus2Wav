import SwiftUI
import UniformTypeIdentifiers

struct DropZoneView: View {
    @EnvironmentObject private var engine: ConversionEngine
    @State private var isTargeted: Bool = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary.opacity(0.6))
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isTargeted ? Color.accentColor.opacity(0.08) : Color.gray.opacity(0.04))
                )

            VStack(spacing: 8) {
                Image(systemName: "waveform.badge.plus")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(.secondary)
                Text("Drop .opus files or folders here")
                    .font(.headline)
                Text("Output: 16 kHz · Mono · 16-bit PCM WAV")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .frame(height: 140)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted, perform: handleDrop)
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard !providers.isEmpty else { return false }

        // handleDrop already runs on the main actor. We iterate the providers
        // here (never handing the non-Sendable NSItemProvider to a task) and let
        // each load complete independently. Capture `engine` (a Sendable
        // @MainActor object) by value so the completion closure does not capture
        // the View; only Sendable URLs cross back to the main actor.
        let engine = self.engine
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                Task { @MainActor in
                    engine.enqueue(droppedURLs: [url])
                }
            }
        }
        return true
    }
}
