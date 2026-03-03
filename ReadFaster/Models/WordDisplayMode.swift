import Foundation

/// Controls how many words are shown per RSVP step.
enum WordDisplayMode: String, CaseIterable, Codable, Identifiable {
    case singleWord
    case threeWordChunk

    var id: String { rawValue }

    var wordsPerChunk: Int {
        switch self {
        case .singleWord: return 1
        case .threeWordChunk: return 3
        }
    }

    var title: String {
        switch self {
        case .singleWord: return "1 word at a time"
        case .threeWordChunk: return "3-word chunks"
        }
    }

    var subtitle: String {
        switch self {
        case .singleWord:
            return "Classic RSVP with one focal word."
        case .threeWordChunk:
            return "Shows short phrase chunks with focal highlight."
        }
    }
}
