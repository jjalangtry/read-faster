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

// MARK: - WPM Presets

private struct WPMPreset: Identifiable {
    let wpm: Int
    let icon: String
    var id: Int { wpm }

    var normalizedPosition: Double {
        let range = Double(RSVPEngine.maxWPM - RSVPEngine.minWPM)
        return Double(wpm - RSVPEngine.minWPM) / range
    }
}

private let wpmPresets: [WPMPreset] = [
    WPMPreset(wpm: 200, icon: "tortoise.fill"),
    WPMPreset(wpm: 400, icon: "figure.walk"),
    WPMPreset(wpm: 700, icon: "hare.fill"),
    WPMPreset(wpm: 1000, icon: "bolt.fill")
]

private let wpmSnapThreshold = 40

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

    private var expandedSlider: some View {
        VStack(spacing: 0) {
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

                Text("\(wpm) WPM")
                    .font(AppFont.semibold(size: 14))
                    .monospacedDigit()

                Spacer()
            }
            .padding(.bottom, 8)

            ZStack(alignment: .leading) {
                Slider(
                    value: $sliderValue,
                    in: Double(RSVPEngine.minWPM)...Double(RSVPEngine.maxWPM),
                    step: Double(step)
                )
                .onChange(of: sliderValue) { _, newValue in
                    let rounded = Int(newValue)
                    wpm = rounded
                    snapIfClose(rounded)
                }

                presetMarkers
                    .allowsHitTesting(false)
            }
            .padding(.bottom, 4)

            presetIcons
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 18))
        #if os(iOS)
        .sensoryFeedback(.impact(weight: .medium), trigger: lastSnappedPreset)
        #endif
    }

    private var presetMarkers: some View {
        GeometryReader { geo in
            let inset: CGFloat = 16
            let usable = geo.size.width - inset * 2

            ForEach(wpmPresets) { preset in
                Circle()
                    .fill(
                        isNear(preset.wpm)
                            ? Color.accentColor
                            : Color.secondary.opacity(0.5)
                    )
                    .frame(width: 6, height: 6)
                    .position(
                        x: inset + usable * preset.normalizedPosition,
                        y: geo.size.height / 2
                    )
            }
        }
        .frame(height: 28)
    }

    private var presetIcons: some View {
        GeometryReader { geo in
            let inset: CGFloat = 16
            let usable = geo.size.width - inset * 2

            ForEach(wpmPresets) { preset in
                Button {
                    sliderValue = Double(preset.wpm)
                    wpm = preset.wpm
                    lastSnappedPreset = preset.wpm
                } label: {
                    Image(systemName: preset.icon)
                        .font(.system(size: 10))
                        .foregroundStyle(
                            isNear(preset.wpm)
                                ? Color.accentColor : .secondary
                        )
                }
                .buttonStyle(.plain)
                .position(
                    x: inset + usable * preset.normalizedPosition,
                    y: geo.size.height / 2
                )
            }
        }
        .frame(height: 16)
    }

    private func isNear(_ target: Int) -> Bool {
        abs(wpm - target) <= wpmSnapThreshold
    }

    private func snapIfClose(_ value: Int) {
        for preset in wpmPresets
        where abs(value - preset.wpm) <= wpmSnapThreshold {
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
        let clamped = min(
            RSVPEngine.maxWPM, max(RSVPEngine.minWPM, wpm + delta)
        )
        wpm = clamped
        sliderValue = Double(clamped)
    }
}

// MARK: - Display Mode Bar (icon-only for toolbar)

struct DisplayModeBar: View {
    @Binding var wordDisplayModeRaw: String
    @Binding var showContext: Bool

    private var wordMode: WordDisplayMode {
        WordDisplayMode(rawValue: wordDisplayModeRaw) ?? .singleWord
    }

    var body: some View {
        HStack(spacing: 2) {
            iconToggle(
                icon: "1.circle",
                active: wordMode == .singleWord
            ) {
                wordDisplayModeRaw = WordDisplayMode.singleWord.rawValue
            }

            iconToggle(
                icon: "3.circle",
                active: wordMode == .threeWordChunk
            ) {
                wordDisplayModeRaw = WordDisplayMode.threeWordChunk.rawValue
            }

            iconToggle(
                icon: "text.alignleft",
                active: showContext
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showContext.toggle()
                }
            }
        }
        #if os(iOS)
        .sensoryFeedback(.selection, trigger: wordDisplayModeRaw)
        .sensoryFeedback(.selection, trigger: showContext)
        #endif
    }

    @ViewBuilder
    private func iconToggle(
        icon: String,
        active: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: active ? icon + ".fill" : icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(active ? .primary : .secondary)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
