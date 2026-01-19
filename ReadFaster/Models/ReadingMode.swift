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

/// Configuration settings for a reading mode
struct ModeSettings {
    let baseWPM: Int
    let showSentenceContext: Bool
    let adaptivePacingEnabled: Bool
    let adaptivePacingIntensity: Double
    let pauseOnPunctuation: Bool
    let punctuationPauseMultiplier: Double
}
