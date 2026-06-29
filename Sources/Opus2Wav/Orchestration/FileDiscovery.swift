import Foundation

struct FileDiscovery {
    static let opusExtension = "opus"

    static func discoverOpusFiles(at urls: [URL]) -> [URL] {
        var results: [URL] = []
        var seen = Set<URL>()
        for url in urls {
            for file in expand(url) where seen.insert(file.standardizedFileURL).inserted {
                results.append(file)
            }
        }
        return results
    }

    static func uniqueDestinationURL(for source: URL, in directory: URL) -> URL {
        let base = source.deletingPathExtension().lastPathComponent
        let candidate = directory.appendingPathComponent("\(base).wav")
        guard FileManager.default.fileExists(atPath: candidate.path) else { return candidate }
        let suffix = String(UUID().uuidString.prefix(8))
        return directory.appendingPathComponent("\(base)_\(suffix).wav")
    }

    private static func expand(_ url: URL) -> [URL] {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return []
        }
        if !isDirectory.boolValue {
            return isOpus(url) ? [url] : []
        }
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var collected: [URL] = []
        for case let candidate as URL in enumerator where isOpus(candidate) {
            collected.append(candidate)
        }
        return collected
    }

    private static func isOpus(_ url: URL) -> Bool {
        url.pathExtension.lowercased() == opusExtension
    }
}
