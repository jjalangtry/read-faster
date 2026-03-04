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

// MARK: - Transport Button (skip backward / forward)

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

// MARK: - WPM Control (Podcast-style speed)

struct WPMControl: View {
    @Binding var wpm: Int
    @State private var isExpanded = false
    @State private var sliderValue: Double = 300

    @State private var decreaseTimer: Timer?
    @State private var increaseTimer: Timer?
    @State private var tickCount = 0
    @State private var isDecreasePressed = false
    @State private var isIncreasePressed = false

    private let step = 25
    private let holdDelay: TimeInterval = 0.25
    private let initialTickInterval: TimeInterval = 0.12
    private let minimumTickInterval: TimeInterval = 0.04

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

// MARK: - Reading Mode Selector

struct ReadingModeSelector: View {
    let currentMode: ReadingMode
    let onModeChange: (ReadingMode) -> Void

    @Namespace private var modeNS

    var body: some View {
        GlassEffectContainer {
            HStack(spacing: 4) {
                ForEach(ReadingMode.allCases) { mode in
                    ModeChip(
                        mode: mode,
                        isSelected: mode == currentMode,
                        namespace: modeNS,
                        action: { onModeChange(mode) }
                    )
                }
            }
        }
    }
}

struct ModeChip: View {
    let mode: ReadingMode
    let isSelected: Bool
    var namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: mode.icon)
                    .font(.system(size: 13, weight: .medium))

                if isSelected {
                    Text(mode.displayName)
                        .font(AppFont.medium(size: 13))
                }
            }
            .padding(.horizontal, isSelected ? 14 : 10)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .glassEffect(
            isSelected ? .regular.tint(.accentColor).interactive() : .regular,
            in: .capsule
        )
        .glassEffectID(mode.id, in: namespace)
        .animation(.easeInOut(duration: 0.25), value: isSelected)
    }
}
