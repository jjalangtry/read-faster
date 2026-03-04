import SwiftUI

// MARK: - Play / Pause Button

struct PlayPauseButton: View {
    let isPlaying: Bool
    var disabled: Bool = false
    var size: CGFloat = 56
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: size * 0.5, weight: .regular))
                .frame(width: size, height: size)
                .contentShape(Circle())
        }
        .buttonStyle(.glass)
        .disabled(disabled)
        #if os(iOS)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: isPlaying)
        #endif
    }
}

// MARK: - Transport Button

struct TransportButton: View {
    let icon: String
    var disabled: Bool = false
    var size: CGFloat = 44
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.55, weight: .regular))
                .frame(width: size, height: size)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

// MARK: - Speed Presets

private struct SpeedPreset {
    let wpm: Int
    let icon: String
    let label: String
}

private let speedPresets: [SpeedPreset] = [
    SpeedPreset(wpm: 200, icon: "tortoise.fill", label: "Slow"),
    SpeedPreset(wpm: 350, icon: "figure.walk", label: "Normal"),
    SpeedPreset(wpm: 500, icon: "hare.fill", label: "Fast"),
    SpeedPreset(wpm: 700, icon: "bolt.fill", label: "Rapid"),
    SpeedPreset(wpm: 1000, icon: "flame.fill", label: "Max")
]

private let snapThreshold = 30

// MARK: - WPM Control

struct WPMControl: View {
    @Binding var wpm: Int
    @State private var isExpanded = false
    @State private var sliderValue: Double = 300
    @State private var lastSnappedPreset: Int?

    private let step = 25

    var body: some View {
        Group {
            if isExpanded {
                expandedSlider
            } else {
                compactStepper
            }
        }
        .animation(
            .spring(response: 0.35, dampingFraction: 0.85),
            value: isExpanded
        )
    }

    // MARK: Compact (single glass card)

    private var compactStepper: some View {
        HStack(spacing: 0) {
            Button { adjustWPM(by: -step) } label: {
                Image(systemName: "minus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(
                        wpm <= RSVPEngine.minWPM ? .tertiary : .primary
                    )
                    .frame(width: 44, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(wpm <= RSVPEngine.minWPM)

            Button {
                sliderValue = Double(wpm)
                lastSnappedPreset = nil
                withAnimation { isExpanded = true }
            } label: {
                Text("\(wpm) WPM")
                    .font(AppFont.semibold(size: 15))
                    .monospacedDigit()
                    .frame(minWidth: 80, minHeight: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button { adjustWPM(by: step) } label: {
                Image(systemName: "plus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(
                        wpm >= RSVPEngine.maxWPM ? .tertiary : .primary
                    )
                    .frame(width: 44, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(wpm >= RSVPEngine.maxWPM)
        }
        .padding(.horizontal, 4)
        .glassEffect(.regular.interactive(), in: .capsule)
        #if os(iOS)
        .sensoryFeedback(.selection, trigger: wpm)
        #endif
    }

    // MARK: Expanded (slider with preset ticks)

    private var expandedSlider: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                Button {
                    withAnimation { isExpanded = false }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)

                Slider(
                    value: $sliderValue,
                    in: Double(RSVPEngine.minWPM)...Double(RSVPEngine.maxWPM),
                    step: Double(step)
                )
                .onChange(of: sliderValue) { _, newValue in
                    let rounded = Int(newValue)
                    wpm = rounded
                    snapToPresetIfClose(rounded)
                }

                Text("\(wpm)")
                    .font(AppFont.semibold(size: 14))
                    .monospacedDigit()
                    .frame(width: 38)
            }

            presetTickMarks
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
        #if os(iOS)
        .sensoryFeedback(.selection, trigger: lastSnappedPreset)
        #endif
    }

    private var presetTickMarks: some View {
        HStack {
            ForEach(Array(speedPresets.enumerated()), id: \.offset) { _, preset in
                Spacer()
                presetTick(preset)
                Spacer()
            }
        }
    }

    private func presetTick(_ preset: SpeedPreset) -> some View {
        Button {
            sliderValue = Double(preset.wpm)
            wpm = preset.wpm
            lastSnappedPreset = preset.wpm
        } label: {
            VStack(spacing: 2) {
                Circle()
                    .fill(
                        isNearPreset(preset.wpm)
                            ? Color.accentColor
                            : Color.secondary.opacity(0.3)
                    )
                    .frame(width: 5, height: 5)

                Image(systemName: preset.icon)
                    .font(.system(size: 10))
                    .foregroundStyle(
                        isNearPreset(preset.wpm)
                            ? Color.accentColor : .secondary
                    )
            }
        }
        .buttonStyle(.plain)
    }

    private func isNearPreset(_ presetWPM: Int) -> Bool {
        abs(wpm - presetWPM) <= snapThreshold
    }

    private func snapToPresetIfClose(_ value: Int) {
        for preset in speedPresets where abs(value - preset.wpm) <= snapThreshold {
            if lastSnappedPreset != preset.wpm {
                lastSnappedPreset = preset.wpm
                sliderValue = Double(preset.wpm)
                wpm = preset.wpm
            }
            return
        }
        lastSnappedPreset = nil
    }

    private func adjustWPM(by delta: Int) {
        let clamped = min(RSVPEngine.maxWPM, max(RSVPEngine.minWPM, wpm + delta))
        wpm = clamped
        sliderValue = Double(clamped)
    }
}

// MARK: - Display Mode Bar (1-word / 3-word + paragraph toggle)

struct DisplayModeBar: View {
    @Binding var wordDisplayModeRaw: String
    @Binding var showContext: Bool

    private var wordMode: WordDisplayMode {
        WordDisplayMode(rawValue: wordDisplayModeRaw) ?? .singleWord
    }

    var body: some View {
        HStack(spacing: 6) {
            chipButton(
                label: "1 Word",
                icon: "text.word.spacing",
                active: wordMode == .singleWord
            ) {
                wordDisplayModeRaw = WordDisplayMode.singleWord.rawValue
            }

            chipButton(
                label: "3 Words",
                icon: "text.line.first.and.arrowtriangle.forward",
                active: wordMode == .threeWordChunk
            ) {
                wordDisplayModeRaw = WordDisplayMode.threeWordChunk.rawValue
            }

            Divider().frame(height: 20).opacity(0.3)

            chipButton(
                label: "Context",
                icon: "text.alignleft",
                active: showContext
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showContext.toggle()
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .glassEffect(.regular, in: .capsule)
        #if os(iOS)
        .sensoryFeedback(.selection, trigger: wordDisplayModeRaw)
        .sensoryFeedback(.selection, trigger: showContext)
        #endif
    }

    @ViewBuilder
    private func chipButton(
        label: String,
        icon: String,
        active: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                Text(label)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(active ? .primary : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                if active {
                    Capsule().fill(Color.accentColor.opacity(0.18))
                }
            }
        }
        .buttonStyle(.plain)
    }
}
