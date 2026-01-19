import SwiftUI

struct ReaderSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var engine: RSVPEngine

    @AppStorage("fontSize") private var fontSize: Double = 48
    @AppStorage("pauseOnPunctuation") private var pauseOnPunctuation: Bool = true

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
            .onAppear {
                engine.pauseOnPunctuation = pauseOnPunctuation
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

            HStack {
                Spacer()
                Text("Sample")
                    .font(.system(size: fontSize, weight: .medium, design: .monospaced))
                Spacer()
            }
            .padding(.vertical, 8)
        }
    }

    private var timingSection: some View {
        Section("Timing") {
            Toggle("Pause on Punctuation", isOn: $pauseOnPunctuation)

            Text("When enabled, the reader pauses longer at sentence endings and clause breaks for better comprehension.")
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
