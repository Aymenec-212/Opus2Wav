import Foundation

struct ConversionTask: Identifiable, Hashable {
    let id: UUID
    let sourceURL: URL
    var destinationURL: URL
    var status: ConversionStatus
    var progress: Double

    init(
        id: UUID = UUID(),
        sourceURL: URL,
        destinationURL: URL,
        status: ConversionStatus = .queued,
        progress: Double = 0.0
    ) {
        self.id = id
        self.sourceURL = sourceURL
        self.destinationURL = destinationURL
        self.status = status
        self.progress = progress
    }
}
