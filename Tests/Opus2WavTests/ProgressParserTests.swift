import XCTest
@testable import Opus2Wav

final class ProgressParserTests: XCTestCase {

    func test_extractsDuration_inHHMMSSCSFormat() {
        let sample = """
        Input #0, ogg, from '/tmp/in.opus':
          Duration: 00:02:34.56, start: 0.000000, bitrate: 64 kb/s
        """
        let duration = ProgressParser.extractDurationSeconds(from: sample)
        XCTAssertEqual(duration ?? -1, (2 * 60) + 34 + 0.56, accuracy: 0.001)
    }

    func test_extractsCurrent_picksLastMatchForLiveProgress() {
        let chunk = """
        size=    256kB time=00:00:05.12 bitrate=  64.0kbits/s
        size=    512kB time=00:00:10.24 bitrate=  64.0kbits/s
        """
        let current = ProgressParser.extractCurrentSeconds(from: chunk)
        XCTAssertEqual(current ?? -1, 10.24, accuracy: 0.001)
    }

    func test_returnsNil_whenNoMatch() {
        XCTAssertNil(ProgressParser.extractDurationSeconds(from: "no metadata here"))
        XCTAssertNil(ProgressParser.extractCurrentSeconds(from: "frame=10"))
    }

    func test_handlesHourBoundaries() {
        let sample = "Duration: 01:23:45.67"
        let duration = ProgressParser.extractDurationSeconds(from: sample)
        XCTAssertEqual(duration ?? -1, 3600 + (23 * 60) + 45 + 0.67, accuracy: 0.001)
    }
}
