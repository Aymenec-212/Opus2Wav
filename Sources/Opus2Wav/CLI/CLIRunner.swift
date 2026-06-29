import Foundation

/// Headless conversion path, reusing the same `FileDiscovery` + `FFmpegRunner`
/// the GUI uses. Lets you convert without a display (SSH, scripts, CI):
///
///     swift run Opus2Wav --cli <file-or-folder> [more...] [-o <output-dir>]
enum CLIRunner {

    /// Runs the CLI to completion and terminates the process with an exit code.
    /// The work runs on the Swift concurrency pool; the main thread is parked in
    /// `dispatchMain()` until the task calls `exit`.
    static func run(arguments: [String]) -> Never {
        Task {
            let code = await execute(arguments: arguments)
            exit(code)
        }
        dispatchMain()
    }

    private static func execute(arguments: [String]) async -> Int32 {
        if arguments.contains("-h") || arguments.contains("--help") {
            printUsage()
            return 0
        }

        var inputs: [URL] = []
        var outputDir: URL?
        var index = 0
        while index < arguments.count {
            let arg = arguments[index]
            switch arg {
            case "-o", "--output":
                guard index + 1 < arguments.count else {
                    printErr("Missing directory after \(arg)")
                    return 2
                }
                outputDir = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
                index += 2
            default:
                inputs.append(URL(fileURLWithPath: arg))
                index += 1
            }
        }

        guard !inputs.isEmpty else {
            printErr("No input files or folders given.")
            printUsage()
            return 2
        }

        guard let binary = FFmpegRunner.locateBundledBinary() else {
            printErr("ffmpeg not found. Install it (e.g. `brew install ffmpeg`), "
                + "set OPUS2WAV_FFMPEG=/path/to/ffmpeg, or run scripts/fetch-ffmpeg.sh.")
            return 3
        }
        let runner = FFmpegRunner(binaryURL: binary)

        let sources = FileDiscovery.discoverOpusFiles(at: inputs)
        guard !sources.isEmpty else {
            printErr("No .opus files found in the given path(s).")
            return 4
        }

        let fileManager = FileManager.default
        var failures = 0
        print("Converting \(sources.count) file(s) → 16 kHz · mono · 16-bit PCM WAV")
        print("Using ffmpeg: \(binary.path)\n")

        for (offset, source) in sources.enumerated() {
            let targetDir = outputDir ?? source.deletingLastPathComponent()
            try? fileManager.createDirectory(at: targetDir, withIntermediateDirectories: true)
            let destination = FileDiscovery.uniqueDestinationURL(for: source, in: targetDir)
            let label = "[\(offset + 1)/\(sources.count)] \(source.lastPathComponent)"

            do {
                try await runner.convert(source: source, destination: destination) { _ in }
                print("  ✓ \(label) → \(destination.path)")
            } catch {
                failures += 1
                printErr("  ✗ \(label): \(error.localizedDescription)")
            }
        }

        let succeeded = sources.count - failures
        print("\nDone. \(succeeded) succeeded, \(failures) failed.")
        return failures == 0 ? 0 : 5
    }

    private static func printUsage() {
        print("""
        Opus2Wav — convert .opus audio to 16 kHz · mono · 16-bit PCM WAV (ASR-ready)

        GUI:  swift run Opus2Wav
        CLI:  swift run Opus2Wav --cli <file-or-folder> [more...] [-o <output-dir>]

        Options:
          -o, --output <dir>   Write .wav files into <dir> (created if needed).
                               Default: next to each source file.
          -h, --help           Show this help.

        Examples:
          swift run Opus2Wav --cli recording.opus
          swift run Opus2Wav --cli ~/darija-corpus -o ~/wavs

        Folders are walked recursively for .opus files. Name collisions get a
        short unique suffix so nothing is overwritten.
        """)
    }

    private static func printErr(_ message: String) {
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }
}
