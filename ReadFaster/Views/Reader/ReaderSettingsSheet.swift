import SwiftUI

struct ReaderSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var engine: RSVPEngine

    @AppStorage("fontSize") private var fontSize: Double = 48
    @AppStorage("pauseOnPunctuation") private var pauseOnPunctuation: Bool = true
    @AppStorage("wordsPerChunk") private var wordsPerChunk: Int = 1

    var body: some View {
        NavigationStack {
            Form {
                displaySection
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
            .onChange(of: pauseOnPunctuation) { _, newValue in
                engine.pauseOnPunctuation = newValue
            }
            .onChange(of: wordsPerChunk) { _, newValue in
                let normalized = normalizedChunkSize(newValue)
                if wordsPerChunk != normalized {
                    wordsPerChunk = normalized
                }
                engine.wordsPerChunk = normalized
            }
            .onAppear {
                engine.pauseOnPunctuation = pauseOnPunctuation
                engine.wordsPerChunk = normalizedChunkSize(wordsPerChunk)
            }
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 400)
        #endif
    }

    private var displaySection: some View {
        Section("Display") {
            VStack(alignment: .leading) {
                Text("Font Size: \(Int(fontSize))")
                Slider(value: $fontSize, in: 24...72, step: 2)
            }

            Picker("Reading Pulse", selection: $wordsPerChunk) {
                Text("1 word").tag(1)
                Text("3 words").tag(3)
            }
            .pickerStyle(.segmented)

            Toggle("Show Sentence Context", isOn: $engine.showSentenceContext)

            VStack(spacing: 8) {
                if wordsPerChunk == 3 {
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

            Text("Three-word mode reduces control fatigue and presents short phrase chunks.")
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

    private func normalizedChunkSize(_ value: Int) -> Int {
        value >= 3 ? 3 : 1
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
