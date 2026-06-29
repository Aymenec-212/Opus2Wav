import Foundation

struct ProgressParser {
    // Extended `#/.../#` literals compile without the BareSlashRegexLiterals
    // upcoming-feature flag, unlike the bare `/.../` form.
    private static let durationRegex = #/Duration:\s*(\d{2}):(\d{2}):(\d{2})\.(\d{2})/#
    private static let timeRegex = #/time=(\d{2}):(\d{2}):(\d{2})\.(\d{2})/#

    static func extractDurationSeconds(from chunk: String) -> Double? {
        guard let match = chunk.firstMatch(of: durationRegex) else { return nil }
        return totalSeconds(
            hours: match.output.1,
            minutes: match.output.2,
            seconds: match.output.3,
            centiseconds: match.output.4
        )
    }

    static func extractCurrentSeconds(from chunk: String) -> Double? {
        guard let match = chunk.matches(of: timeRegex).last else { return nil }
        return totalSeconds(
            hours: match.output.1,
            minutes: match.output.2,
            seconds: match.output.3,
            centiseconds: match.output.4
        )
    }

    private static func totalSeconds(
        hours: Substring,
        minutes: Substring,
        seconds: Substring,
        centiseconds: Substring
    ) -> Double? {
        // `Double` has no Substring initializer; convert via String.
        guard
            let hh = Double(String(hours)),
            let mm = Double(String(minutes)),
            let ss = Double(String(seconds)),
            let cs = Double(String(centiseconds))
        else { return nil }
        return (hh * 3600.0) + (mm * 60.0) + ss + (cs / 100.0)
    }
}
