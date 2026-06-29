import Foundation
import Combine

@MainActor
final class ConversionEngine: ObservableObject {
    @Published private(set) var tasks: [ConversionTask] = []
    @Published private(set) var isRunning: Bool = false
    @Published var outputDirectory: URL
    @Published private(set) var lastEngineError: String?

    let workerCap: Int
    private let runner: FFmpegRunner?
    private var runTask: Task<Void, Never>?
    private var runGeneration: Int = 0

    init(outputDirectory: URL? = nil) {
        let cores = ProcessInfo.processInfo.processorCount
        self.workerCap = max(1, cores - 1)
        self.outputDirectory = outputDirectory ?? Self.defaultOutputDirectory()
        if let binary = FFmpegRunner.locateBundledBinary() {
            self.runner = FFmpegRunner(binaryURL: binary)
            self.lastEngineError = nil
        } else {
            self.runner = nil
            self.lastEngineError = "Embedded ffmpeg binary not found in Resources. See README."
        }
    }

    nonisolated static func defaultOutputDirectory() -> URL {
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory())
    }

    func enqueue(droppedURLs: [URL]) {
        let discovered = FileDiscovery.discoverOpusFiles(at: droppedURLs)
        let existing = Set(tasks.map { $0.sourceURL.standardizedFileURL })
        let additions = discovered
            .filter { !existing.contains($0.standardizedFileURL) }
            .map { source in
                ConversionTask(
                    sourceURL: source,
                    destinationURL: FileDiscovery.uniqueDestinationURL(for: source, in: outputDirectory)
                )
            }
        tasks.append(contentsOf: additions)
    }

    func clearCompleted() {
        tasks.removeAll { $0.status.isTerminal }
    }

    func clearAll() {
        cancel()
        tasks.removeAll()
    }

    func cancel() {
        runTask?.cancel()
        runTask = nil
        isRunning = false
        for index in tasks.indices where !tasks[index].status.isTerminal {
            tasks[index].status = .failed(errorMessage: "Cancelled")
        }
    }

    func start() {
        guard !isRunning else { return }
        guard let runner else {
            lastEngineError = "Cannot start: embedded ffmpeg binary missing."
            return
        }
        let outputDir = outputDirectory
        for index in tasks.indices where !tasks[index].status.isTerminal {
            tasks[index].destinationURL = FileDiscovery.uniqueDestinationURL(
                for: tasks[index].sourceURL,
                in: outputDir
            )
            tasks[index].progress = 0
        }
        let pending = tasks
            .filter { !$0.status.isTerminal }
            .map { TaskHandle(id: $0.id, source: $0.sourceURL, destination: $0.destinationURL) }
        guard !pending.isEmpty else { return }

        isRunning = true
        runGeneration += 1
        let generation = runGeneration
        let cap = workerCap
        let engineRef = self
        runTask = Task.detached(priority: .userInitiated) {
            await Self.runQueue(handles: pending, runner: runner, cap: cap, engine: engineRef)
            await MainActor.run {
                guard engineRef.runGeneration == generation else { return }
                engineRef.isRunning = false
                engineRef.runTask = nil
            }
        }
    }

    private struct TaskHandle: Sendable {
        let id: UUID
        let source: URL
        let destination: URL
    }

    nonisolated private static func runQueue(
        handles: [TaskHandle],
        runner: FFmpegRunner,
        cap: Int,
        engine: ConversionEngine
    ) async {
        await withTaskGroup(of: Void.self) { group in
            var iterator = handles.makeIterator()
            for _ in 0..<cap {
                guard let handle = iterator.next() else { break }
                group.addTask { await Self.processOne(handle, runner: runner, engine: engine) }
            }
            while await group.next() != nil {
                if Task.isCancelled { break }
                guard let handle = iterator.next() else { continue }
                group.addTask { await Self.processOne(handle, runner: runner, engine: engine) }
            }
        }
    }

    nonisolated private static func processOne(
        _ handle: TaskHandle,
        runner: FFmpegRunner,
        engine: ConversionEngine
    ) async {
        await engine.updateStatus(id: handle.id, status: .extractingMetadata)

        let source = handle.source
        let didAccess = source.startAccessingSecurityScopedResource()
        defer {
            if didAccess { source.stopAccessingSecurityScopedResource() }
        }

        await engine.updateStatus(id: handle.id, status: .processing)

        do {
            try await runner.convert(source: source, destination: handle.destination) { ratio in
                Task { await engine.updateProgress(id: handle.id, progress: ratio) }
            }
            await engine.updateProgress(id: handle.id, progress: 1.0)
            await engine.updateStatus(id: handle.id, status: .completed)
        } catch is CancellationError {
            await engine.updateStatus(id: handle.id, status: .failed(errorMessage: "Cancelled"))
        } catch {
            await engine.updateStatus(id: handle.id, status: .failed(errorMessage: error.localizedDescription))
        }
    }

    fileprivate func updateStatus(id: UUID, status: ConversionStatus) {
        if let index = tasks.firstIndex(where: { $0.id == id }) {
            tasks[index].status = status
        }
    }

    fileprivate func updateProgress(id: UUID, progress: Double) {
        if let index = tasks.firstIndex(where: { $0.id == id }) {
            tasks[index].progress = progress
        }
    }
}
