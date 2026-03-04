import Foundation

/// Predefined reading modes that configure multiple settings at once
enum ReadingMode: String, CaseIterable, Codable, Identifiable {
    case skim
    case normal
    case study

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .skim: return "Skim"
        case .normal: return "Normal"
        case .study: return "Study"
        }
    }

    var description: String {
        switch self {
        case .skim: return "Fast pace, minimal context"
        case .normal: return "Balanced speed and comprehension"
        case .study: return "Slower, with full context"
        }
    }

    var icon: String {
        switch self {
        case .skim: return "hare"
        case .normal: return "figure.walk"
        case .study: return "book"
        }
    }

    var settings: ModeSettings {
        switch self {
        case .skim:
            return ModeSettings(
                baseWPM: 600,
                showSentenceContext: false,
                adaptivePacingEnabled: false,
                adaptivePacingIntensity: 0.0,
                pauseOnPunctuation: true,
                punctuationPauseMultiplier: 1.2 // Minimal pause
            )
        case .normal:
            return ModeSettings(
                baseWPM: 350,
                showSentenceContext: true,
                adaptivePacingEnabled: true,
                adaptivePacingIntensity: 1.0,
                pauseOnPunctuation: true,
                punctuationPauseMultiplier: 1.5
            )
        case .study:
            return ModeSettings(
                baseWPM: 250,
                showSentenceContext: true,
                adaptivePacingEnabled: true,
                adaptivePacingIntensity: 1.5, // More aggressive slowdown
                pauseOnPunctuation: true,
                punctuationPauseMultiplier: 2.0 // Extended pauses
            )
        }
    }
}

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

/// Controls whether reading is visual RSVP or spoken transcription playback.
enum ReaderPlaybackMode: String, CaseIterable, Codable, Identifiable {
    case rsvp
    case audioTranscription

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rsvp: return "RSVP"
        case .audioTranscription: return "Listen & Transcript"
        }
    }

    var subtitle: String {
        switch self {
        case .rsvp:
            return "Visual speed-reading with focal ORP highlighting."
        case .audioTranscription:
            return "Speaks each sentence aloud while showing live transcript text."
        }
    }

    var icon: String {
        switch self {
        case .rsvp: return "text.redaction"
        case .audioTranscription: return "waveform"
        }
    }
}

/// Configuration settings for a reading mode
struct ModeSettings {
    let baseWPM: Int
    let showSentenceContext: Bool
    let adaptivePacingEnabled: Bool
    let adaptivePacingIntensity: Double
    let pauseOnPunctuation: Bool
    let punctuationPauseMultiplier: Double
}
