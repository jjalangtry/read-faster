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
                .font(.system(size: size * 0.52, weight: .regular))
                .foregroundStyle(disabled ? .tertiary : .primary)
                .frame(width: size, height: size)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .opacity(disabled ? 0.4 : 1.0)
        .allowsHitTesting(!disabled)
        #if os(iOS)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: isPlaying)
        #endif
    }
}

// MARK: - Transport Button (skip backward / forward)

struct TransportButton: View {
    let icon: String
    var disabled: Bool = false
    var size: CGFloat = 36
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.62, weight: .regular))
                .foregroundStyle(disabled ? .tertiary : .primary)
                .frame(width: size, height: size)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .opacity(disabled ? 0.4 : 1.0)
        .allowsHitTesting(!disabled)
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
        HStack(spacing: 0) {
            wpmStepperButton(
                icon: "minus",
                isPressed: $isDecreasePressed,
                disabled: wpm <= RSVPEngine.minWPM,
                onTap: { adjustWPM(by: -step) },
                onHoldStart: { startTimer(isDecrease: true) },
                onHoldEnd: { stopTimer(isDecrease: true) }
            )

            Button {
                sliderValue = Double(wpm)
                withAnimation { isExpanded = true }
            } label: {
                Text("\(wpm) WPM")
                    .font(AppFont.semibold(size: 15))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .frame(minWidth: 90, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            wpmStepperButton(
                icon: "plus",
                isPressed: $isIncreasePressed,
                disabled: wpm >= RSVPEngine.maxWPM,
                onTap: { adjustWPM(by: step) },
                onHoldStart: { startTimer(isDecrease: false) },
                onHoldEnd: { stopTimer(isDecrease: false) }
            )
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private var expandedSlider: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation { isExpanded = false }
            } label: {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)

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
        .background(.regularMaterial, in: Capsule())
    }

    @ViewBuilder
    private func wpmStepperButton(
        icon: String,
        isPressed: Binding<Bool>,
        disabled: Bool,
        onTap: @escaping () -> Void,
        onHoldStart: @escaping () -> Void,
        onHoldEnd: @escaping () -> Void
    ) -> some View {
        Image(systemName: icon)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(disabled ? .tertiary : .primary)
            .frame(width: 44, height: 44)
            .contentShape(Circle())
            .scaleEffect(isPressed.wrappedValue ? 0.88 : 1.0)
            .animation(.easeOut(duration: 0.1), value: isPressed.wrappedValue)
            .opacity(disabled ? 0.5 : 1.0)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !disabled, !isPressed.wrappedValue else { return }
                        isPressed.wrappedValue = true
                        onHoldStart()
                    }
                    .onEnded { _ in
                        let wasHolding = tickCount > 0
                        onHoldEnd()
                        isPressed.wrappedValue = false
                        if !wasHolding && !disabled { onTap() }
                    }
            )
            .allowsHitTesting(!disabled)
            #if os(iOS)
            .sensoryFeedback(.selection, trigger: isPressed.wrappedValue)
            #endif
    }

    private func adjustWPM(by delta: Int) {
        let clamped = min(RSVPEngine.maxWPM, max(RSVPEngine.minWPM, wpm + delta))
        wpm = clamped
        sliderValue = Double(clamped)
    }

    private func startTimer(isDecrease: Bool) {
        tickCount = 0
        let newTimer = Timer.scheduledTimer(
            withTimeInterval: holdDelay,
            repeats: false
        ) { _ in
            Task { @MainActor in
                let active = isDecrease ? isDecreasePressed : isIncreasePressed
                guard active else { return }
                tickCount += 1
                adjustWPM(by: isDecrease ? -step : step)
                continueTimer(isDecrease: isDecrease)
            }
        }
        if isDecrease { decreaseTimer = newTimer } else { increaseTimer = newTimer }
    }

    private func continueTimer(isDecrease: Bool) {
        let interval = currentTickInterval
        if isDecrease {
            decreaseTimer?.invalidate()
        } else {
            increaseTimer?.invalidate()
        }
        let newTimer = Timer.scheduledTimer(
            withTimeInterval: interval,
            repeats: false
        ) { _ in
            Task { @MainActor in
                let active = isDecrease ? isDecreasePressed : isIncreasePressed
                guard active else { return }
                let atLimit = isDecrease
                    ? wpm <= RSVPEngine.minWPM
                    : wpm >= RSVPEngine.maxWPM
                guard !atLimit else { return }
                tickCount += 1
                adjustWPM(by: isDecrease ? -step : step)
                continueTimer(isDecrease: isDecrease)
            }
        }
        if isDecrease { decreaseTimer = newTimer } else { increaseTimer = newTimer }
    }

    private func stopTimer(isDecrease: Bool) {
        if isDecrease {
            decreaseTimer?.invalidate()
            decreaseTimer = nil
        } else {
            increaseTimer?.invalidate()
            increaseTimer = nil
        }
        tickCount = 0
    }

    private var currentTickInterval: TimeInterval {
        if tickCount < 5 { return initialTickInterval }
        let accel = Double(tickCount - 5) * 0.015
        return max(minimumTickInterval, initialTickInterval - accel)
    }
}

// MARK: - Reading Mode Selector

struct ReadingModeSelector: View {
    let currentMode: ReadingMode
    let onModeChange: (ReadingMode) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(ReadingMode.allCases) { mode in
                ModeButton(
                    mode: mode,
                    isSelected: mode == currentMode,
                    action: { onModeChange(mode) }
                )
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

struct ModeButton: View {
    let mode: ReadingMode
    let isSelected: Bool
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
            .foregroundStyle(isSelected ? .primary : .secondary)
            .padding(.horizontal, isSelected ? 12 : 10)
            .padding(.vertical, 7)
            .background {
                if isSelected {
                    Capsule().fill(Color.accentColor.opacity(0.18))
                }
            }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}
