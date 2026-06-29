import XCTest
@testable import Opus2Wav

final class FileDiscoveryTests: XCTestCase {

    private var tempRoot: URL!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("Opus2WavTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    func test_discoversFlatOpusFiles() throws {
        let a = try touch("a.opus")
        let b = try touch("b.OPUS")
        let nonOpus = try touch("c.wav")

        let found = FileDiscovery.discoverOpusFiles(at: [tempRoot])
        let names = Set(found.map { $0.lastPathComponent })

        XCTAssertEqual(names, [a.lastPathComponent, b.lastPathComponent])
        XCTAssertFalse(names.contains(nonOpus.lastPathComponent))
    }

    func test_recursesIntoSubdirectories() throws {
        let nested = tempRoot.appendingPathComponent("nest/deep", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        let deepFile = nested.appendingPathComponent("inner.opus")
        FileManager.default.createFile(atPath: deepFile.path, contents: Data())

        let found = FileDiscovery.discoverOpusFiles(at: [tempRoot])
        XCTAssertTrue(found.contains { $0.lastPathComponent == "inner.opus" })
    }

    func test_dedupesIdenticalSources() throws {
        let file = try touch("dup.opus")
        let found = FileDiscovery.discoverOpusFiles(at: [file, file, tempRoot])
        XCTAssertEqual(found.filter { $0.lastPathComponent == "dup.opus" }.count, 1)
    }

    func test_uniqueDestination_returnsPlainPathWhenNoCollision() {
        let source = tempRoot.appendingPathComponent("song.opus")
        let destination = FileDiscovery.uniqueDestinationURL(for: source, in: tempRoot)
        XCTAssertEqual(destination.lastPathComponent, "song.wav")
    }

    func test_uniqueDestination_appendsShortSuffixOnCollision() throws {
        let existing = tempRoot.appendingPathComponent("song.wav")
        FileManager.default.createFile(atPath: existing.path, contents: Data())

        let source = tempRoot.appendingPathComponent("song.opus")
        let destination = FileDiscovery.uniqueDestinationURL(for: source, in: tempRoot)

        XCTAssertNotEqual(destination.lastPathComponent, "song.wav")
        XCTAssertTrue(destination.lastPathComponent.hasPrefix("song_"))
        XCTAssertTrue(destination.lastPathComponent.hasSuffix(".wav"))
    }

    @discardableResult
    private func touch(_ name: String) throws -> URL {
        let url = tempRoot.appendingPathComponent(name)
        FileManager.default.createFile(atPath: url.path, contents: Data())
        return url
    }
}
