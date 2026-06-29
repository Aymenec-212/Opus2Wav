import Foundation

enum ConversionStatus: Hashable {
    case queued
    case extractingMetadata
    case processing
    case completed
    case failed(errorMessage: String)

    var isTerminal: Bool {
        switch self {
        case .completed, .failed: return true
        case .queued, .extractingMetadata, .processing: return false
        }
    }

    var label: String {
        switch self {
        case .queued: return "Queued"
        case .extractingMetadata: return "Reading metadata"
        case .processing: return "Processing"
        case .completed: return "Completed"
        case .failed(let message): return "Failed — \(message)"
        }
    }
}
