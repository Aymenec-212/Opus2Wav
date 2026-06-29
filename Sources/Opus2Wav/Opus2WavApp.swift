import SwiftUI
import AppKit

/// Process entry point. Runs the headless converter when invoked with `--cli`
/// (or `convert`); otherwise launches the SwiftUI app. Keeping both behind one
/// binary means `swift run Opus2Wav` opens the window while
/// `swift run Opus2Wav --cli …` converts without a display.
@main
struct Opus2WavEntry {
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        if let first = arguments.first, first == "--cli" || first == "convert" {
            CLIRunner.run(arguments: Array(arguments.dropFirst()))
        }
        Opus2WavApp.main()
    }
}

struct Opus2WavApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
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

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // When launched via `swift run` there is no .app bundle, so the process
        // defaults to an accessory activation policy: the window opens behind
        // everything and never takes focus. Promote to a regular foreground app
        // so it behaves normally. This is a no-op for a properly bundled .app.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
