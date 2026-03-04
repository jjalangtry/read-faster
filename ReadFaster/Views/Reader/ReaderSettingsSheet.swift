import SwiftUI

struct ReaderSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var engine: RSVPEngine

    @AppStorage("fontSize") private var fontSize: Double = 48
    @AppStorage("pauseOnPunctuation") private var pauseOnPunctuation: Bool = true
    @AppStorage("readerWordDisplayMode") private var wordDisplayModeRaw = WordDisplayMode.singleWord.rawValue
    @AppStorage("readerPlaybackMode") private var playbackModeRaw = ReaderPlaybackMode.rsvp.rawValue

    var body: some View {
        NavigationStack {
            Form {
                displaySection
                playbackSection
                timingSection
                speedPresetsSection
            }
            .navigationTitle("Reader Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 400)
        #endif
        .onAppear {
            engine.setPlaybackMode(playbackMode)
        }
        .onChange(of: playbackModeRaw) { _, rawValue in
            let mode = ReaderPlaybackMode(rawValue: rawValue) ?? ReaderPlaybackMode.rsvp
            if mode.rawValue != rawValue {
                playbackModeRaw = mode.rawValue
                return
            }
            Task { @MainActor in
                engine.setPlaybackMode(mode)
            }
        }
    }

    private var displaySection: some View {
        Section("Display") {
            VStack(alignment: .leading) {
                Text("Font Size: \(Int(fontSize))")
                Slider(value: $fontSize, in: 24...72, step: 2)
            }

            Picker("Word Display", selection: $wordDisplayModeRaw) {
                ForEach(WordDisplayMode.allCases) { mode in
                    Text(mode.title).tag(mode.rawValue)
                }
            }
            .pickerStyle(.menu)
            .disabled(playbackMode == .audioTranscription)

            Toggle("Show Sentence Context", isOn: $engine.showSentenceContext)

            VStack(spacing: 8) {
                if playbackMode == .audioTranscription {
                    Text("Listen mode active")
                        .font(AppFont.rsvpPhrase(size: max(24, fontSize * 0.52)))
                } else if wordDisplayMode == .threeWordChunk {
                    Text("the quick brown")
                        .font(AppFont.rsvpPhrase(size: max(24, fontSize * 0.62)))
                } else {
                    Text("Sample")
                        .font(AppFont.rsvpWord(size: fontSize))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

            Text(
                playbackMode == .audioTranscription
                    ? "Word chunk display is disabled while listen mode is active."
                    : wordDisplayMode.subtitle
            )
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var playbackSection: some View {
        Section("Playback") {
            Picker("Playback Experience", selection: $playbackModeRaw) {
                ForEach(ReaderPlaybackMode.allCases) { mode in
                    Label(mode.title, systemImage: mode.icon)
                        .tag(mode.rawValue)
                }
            }
            .pickerStyle(.menu)

            Text(playbackMode.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var timingSection: some View {
        Section("Timing") {
            Toggle("Pause on Punctuation", isOn: $pauseOnPunctuation)

            Text(
                "When enabled, the reader pauses longer at sentence endings and clause breaks for better comprehension."
            )
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var speedPresetsSection: some View {
        Section("Speed Presets") {
            ForEach(SpeedPreset.allCases, id: \.self) { preset in
                SpeedPresetRow(preset: preset, currentWPM: engine.wordsPerMinute) {
                    engine.wordsPerMinute = preset.wpm
                }
            }
        }
    }

    private var wordDisplayMode: WordDisplayMode {
        WordDisplayMode(rawValue: wordDisplayModeRaw) ?? WordDisplayMode.singleWord
    }

    private var playbackMode: ReaderPlaybackMode {
        ReaderPlaybackMode(rawValue: playbackModeRaw) ?? ReaderPlaybackMode.rsvp
    }
}

struct SpeedPresetRow: View {
    let preset: SpeedPreset
    let currentWPM: Int
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading) {
                    Text(preset.name)
                    Text(preset.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("\(preset.wpm) WPM")
                    .foregroundStyle(.secondary)

                if currentWPM == preset.wpm {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

enum SpeedPreset: CaseIterable {
    case beginner
    case comfortable
    case moderate
    case fast
    case veryFast
    case extreme

    var name: String {
        switch self {
        case .beginner: return "Beginner"
        case .comfortable: return "Comfortable"
        case .moderate: return "Moderate"
        case .fast: return "Fast"
        case .veryFast: return "Very Fast"
        case .extreme: return "Extreme"
        }
    }

    var description: String {
        switch self {
        case .beginner: return "Great for getting started"
        case .comfortable: return "Relaxed reading pace"
        case .moderate: return "Average reading speed"
        case .fast: return "Above average"
        case .veryFast: return "Experienced readers"
        case .extreme: return "Speed reading challenge"
        }
    }

    var wpm: Int {
        switch self {
        case .beginner: return 200
        case .comfortable: return 300
        case .moderate: return 400
        case .fast: return 500
        case .veryFast: return 700
        case .extreme: return 1000
        }
    }
}

#Preview {
    ReaderSettingsSheet(engine: RSVPEngine())
}
