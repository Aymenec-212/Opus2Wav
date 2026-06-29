import Foundation

enum FFmpegError: Error, LocalizedError {
    case binaryMissing
    case launchFailed(underlying: Error)
    case timedOut(seconds: Int)
    case nonZeroExit(code: Int32, stderr: String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .binaryMissing:
            return "Embedded ffmpeg binary missing from bundle resources."
        case .launchFailed(let underlying):
            return "Failed to launch ffmpeg: \(underlying.localizedDescription)"
        case .timedOut(let seconds):
            return "Process exceeded \(seconds)s watchdog timeout."
        case .nonZeroExit(let code, let stderr):
            let tail = stderr.split(separator: "\n").suffix(3).joined(separator: " | ")
            return "ffmpeg exited \(code): \(tail)"
        case .cancelled:
            return "Cancelled."
        }
    }
}

struct FFmpegRunner: Sendable {
    static let perTaskTimeoutSeconds: Int = 60

    private let binaryURL: URL

    init(binaryURL: URL) {
        self.binaryURL = binaryURL
    }

    /// Resolves an ffmpeg executable, in priority order:
    /// 1. `OPUS2WAV_FFMPEG` env override (absolute path).
    /// 2. A binary bundled inside the .app (`Bundle.main`), for signed distribution.
    /// 3. The dev-path binary under `Sources/Opus2Wav/Resources/ffmpeg` (fetch script).
    /// 4. Common system install locations (Homebrew, MacPorts, /usr/bin).
    /// 5. Anything named `ffmpeg` on `PATH`.
    static func locateBundledBinary() -> URL? {
        let fm = FileManager.default

        if let override = ProcessInfo.processInfo.environment["OPUS2WAV_FFMPEG"],
           !override.isEmpty,
           fm.isExecutableFile(atPath: override) {
            return URL(fileURLWithPath: override)
        }

        if let main = Bundle.main.url(forResource: "ffmpeg", withExtension: nil),
           fm.isExecutableFile(atPath: main.path) {
            return main
        }

        let dev = URL(fileURLWithPath: "Sources/Opus2Wav/Resources/ffmpeg",
                      relativeTo: URL(fileURLWithPath: fm.currentDirectoryPath))
        if fm.isExecutableFile(atPath: dev.path) {
            return dev.standardizedFileURL
        }

        let commonPaths = [
            "/opt/homebrew/bin/ffmpeg",  // Apple Silicon Homebrew
            "/usr/local/bin/ffmpeg",     // Intel Homebrew
            "/opt/local/bin/ffmpeg",     // MacPorts
            "/usr/bin/ffmpeg"
        ]
        for path in commonPaths where fm.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }

        return ffmpegFromPATH()
    }

    private static func ffmpegFromPATH() -> URL? {
        let fm = FileManager.default
        guard let pathVar = ProcessInfo.processInfo.environment["PATH"] else { return nil }
        for dir in pathVar.split(separator: ":") where !dir.isEmpty {
            let candidate = URL(fileURLWithPath: String(dir)).appendingPathComponent("ffmpeg")
            if fm.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }

    func convert(
        source: URL,
        destination: URL,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws {
        let process = Process()
        process.executableURL = binaryURL
        process.arguments = [
            "-y",
            "-i", source.path,
            "-acodec", "pcm_s16le",
            "-ac", "1",
            "-ar", "16000",
            destination.path
        ]

        // ffmpeg writes the WAV to a file and logs everything to stderr; stdout
        // stays empty. Route stdout/stdin to /dev/null so an undrained pipe can
        // never fill and stall the subprocess.
        let stderrPipe = Pipe()
        process.standardError = stderrPipe
        process.standardOutput = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice

        let collector = StderrCollector()

        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            if let ratio = collector.ingest(data) {
                onProgress(ratio)
            }
        }
        // Guarantee the handler is torn down on every exit path (including the
        // timeout/cancel throws below) so no dispatch source dangles on the Pipe.
        defer { stderrPipe.fileHandleForReading.readabilityHandler = nil }

        do {
            try process.run()
        } catch {
            throw FFmpegError.launchFailed(underlying: error)
        }

        try await withTaskCancellationHandler {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    await waitForExit(process)
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(Self.perTaskTimeoutSeconds) * 1_000_000_000)
                    if process.isRunning {
                        process.terminate()
                        throw FFmpegError.timedOut(seconds: Self.perTaskTimeoutSeconds)
                    }
                }
                try await group.next()
                group.cancelAll()
            }
        } onCancel: {
            if process.isRunning { process.terminate() }
        }

        stderrPipe.fileHandleForReading.readabilityHandler = nil
        let trailing = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        if !trailing.isEmpty {
            _ = collector.ingest(trailing)
        }

        if process.terminationStatus != 0 {
            throw FFmpegError.nonZeroExit(code: process.terminationStatus, stderr: collector.fullText())
        }

        onProgress(1.0)
    }

    private func waitForExit(_ process: Process) async {
        await withCheckedContinuation { continuation in
            let resumer = ContinuationResumer(continuation)
            process.terminationHandler = { _ in resumer.resume() }
            if !process.isRunning { resumer.resume() }
        }
    }
}

private final class ContinuationResumer: @unchecked Sendable {
    private let continuation: CheckedContinuation<Void, Never>
    private let lock = NSLock()
    private var resumed = false

    init(_ continuation: CheckedContinuation<Void, Never>) {
        self.continuation = continuation
    }

    func resume() {
        lock.lock()
        defer { lock.unlock() }
        guard !resumed else { return }
        resumed = true
        continuation.resume()
    }
}

/// Thread-safe accumulator for ffmpeg's stderr. `ingest` is called from the
/// pipe's readability handler (a background queue) and returns a progress ratio
/// when one can be computed, so the caller can forward it without an async hop.
private final class StderrCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = Data()
    private var totalDuration: Double?

    func ingest(_ data: Data) -> Double? {
        lock.lock()
        defer { lock.unlock() }
        buffer.append(data)

        let text = String(decoding: buffer, as: UTF8.self)
        if totalDuration == nil, let duration = ProgressParser.extractDurationSeconds(from: text) {
            totalDuration = duration
        }

        guard let total = totalDuration, total > 0,
              let current = ProgressParser.extractCurrentSeconds(from: text) else { return nil }
        return min(max(current / total, 0.0), 0.999)
    }

    func fullText() -> String {
        lock.lock()
        defer { lock.unlock() }
        return String(decoding: buffer, as: UTF8.self)
    }
}
