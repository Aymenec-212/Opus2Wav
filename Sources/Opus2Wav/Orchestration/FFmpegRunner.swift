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

    static func locateBundledBinary() -> URL? {
        if let override = ProcessInfo.processInfo.environment["OPUS2WAV_FFMPEG"],
           !override.isEmpty,
           FileManager.default.isExecutableFile(atPath: override) {
            return URL(fileURLWithPath: override)
        }
        if let main = Bundle.main.url(forResource: "ffmpeg", withExtension: nil) {
            return main
        }
        let dev = URL(fileURLWithPath: "Sources/Opus2Wav/Resources/ffmpeg",
                      relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
        if FileManager.default.isExecutableFile(atPath: dev.path) {
            return dev
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

        let stderrPipe = Pipe()
        let stdoutPipe = Pipe()
        process.standardError = stderrPipe
        process.standardOutput = stdoutPipe

        let collector = StderrCollector()

        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
            Task { await collector.ingest(chunk, onProgress: onProgress) }
        }

        do {
            try process.run()
        } catch {
            stderrPipe.fileHandleForReading.readabilityHandler = nil
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
        if let chunk = String(data: trailing, encoding: .utf8), !chunk.isEmpty {
            await collector.ingest(chunk, onProgress: onProgress)
        }

        if process.terminationStatus != 0 {
            let stderr = await collector.fullText()
            throw FFmpegError.nonZeroExit(code: process.terminationStatus, stderr: stderr)
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

private actor StderrCollector {
    private var buffer = ""
    private var totalDuration: Double?

    func ingest(_ chunk: String, onProgress: @Sendable (Double) -> Void) {
        buffer.append(chunk)

        if totalDuration == nil, let duration = ProgressParser.extractDurationSeconds(from: buffer) {
            totalDuration = duration
        }

        guard let total = totalDuration, total > 0 else { return }
        guard let current = ProgressParser.extractCurrentSeconds(from: chunk) else { return }
        let ratio = min(max(current / total, 0.0), 0.999)
        onProgress(ratio)
    }

    func fullText() -> String { buffer }
}
