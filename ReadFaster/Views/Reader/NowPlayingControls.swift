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

// MARK: - WPM Control

struct WPMControl: View {
    @Binding var wpm: Int
    @State private var isExpanded = false
    @State private var sliderValue: Double = 300

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

    private var compactStepper: some View {
        HStack(spacing: 4) {
            Button {
                adjustWPM(by: -step)
            } label: {
                Image(systemName: "minus")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.glass)
            .disabled(wpm <= RSVPEngine.minWPM)
            #if os(iOS)
            .sensoryFeedback(.selection, trigger: wpm)
            #endif

            Button {
                sliderValue = Double(wpm)
                withAnimation { isExpanded = true }
            } label: {
                Text("\(wpm) WPM")
                    .font(AppFont.semibold(size: 15))
                    .monospacedDigit()
                    .frame(minWidth: 86, minHeight: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                adjustWPM(by: step)
            } label: {
                Image(systemName: "plus")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.glass)
            .disabled(wpm >= RSVPEngine.maxWPM)
            #if os(iOS)
            .sensoryFeedback(.selection, trigger: wpm)
            #endif
        }
    }

    private var expandedSlider: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation { isExpanded = false }
            } label: {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.glass)

            Slider(
                value: $sliderValue,
                in: Double(RSVPEngine.minWPM)...Double(RSVPEngine.maxWPM),
                step: Double(step)
            )
            .frame(minWidth: 120, maxWidth: 220)
            .onChange(of: sliderValue) { _, newValue in
                wpm = Int(newValue)
            }

            Text("\(Int(sliderValue))")
                .font(AppFont.semibold(size: 15))
                .monospacedDigit()
                .frame(width: 44)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .capsule)
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

// MARK: - Reading Mode Selector

struct ReadingModeSelector: View {
    let currentMode: ReadingMode
    let onModeChange: (ReadingMode) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(ReadingMode.allCases) { mode in
                Button {
                    onModeChange(mode)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 11, weight: .medium))
                        Text(mode.displayName)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(
                        mode == currentMode ? .primary : .secondary
                    )
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background {
                        if mode == currentMode {
                            Capsule()
                                .fill(Color.accentColor.opacity(0.18))
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .glassEffect(.regular, in: .capsule)
        #if os(iOS)
        .sensoryFeedback(.selection, trigger: currentMode)
        #endif
    }
}
