import SwiftUI

@main
struct Opus2WavApp: App {
    @StateObject private var engine = ConversionEngine()

    var body: some Scene {
        WindowGroup("Opus2Wav — ASR Prep") {
            ContentView()
                .environmentObject(engine)
                .frame(minWidth: 720, minHeight: 480)
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
