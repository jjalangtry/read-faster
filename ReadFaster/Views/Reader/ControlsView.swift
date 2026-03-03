import SwiftUI

struct ControlsView: View {
    @ObservedObject var engine: RSVPEngine

    var body: some View {
        VStack(spacing: 16) {
            // Reading mode selector
            ReadingModeSelector(currentMode: engine.currentMode) { mode in
                engine.applyMode(mode)
            }

            // Playback controls with glass effect
            GlassEffectContainer {
                HStack(spacing: 24) {
                    // Replay previous sentence
                    Button {
                        engine.replayPreviousSentence()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.title2)
                            .foregroundStyle(.primary)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: Circle())
                    .disabled(!engine.hasContent || engine.isAtStart)

                    // Previous sentence
                    Button {
                        engine.previousSentence()
                    } label: {
                        Image(systemName: "backward.end.fill")
                            .font(.title2)
                            .foregroundStyle(.primary)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: Circle())
                    .disabled(!engine.hasContent || engine.isAtStart)

                    // Play/Pause
                    Button {
                        engine.toggle()
                    } label: {
                        Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.primary)
                            .frame(width: 64, height: 64)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.tint(.accentColor).interactive(), in: Circle())
                    .disabled(!engine.hasContent)

                    // Next sentence
                    Button {
                        engine.nextSentence()
                    } label: {
                        Image(systemName: "forward.end.fill")
                            .font(.title2)
                            .foregroundStyle(.primary)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: Circle())
                    .disabled(engine.isAtEnd)
                }
            }

            // WPM slider
            WPMSlider(wpm: $engine.wordsPerMinute)
        }
    }
}

struct WPMSlider: View {
    @Binding var wpm: Int

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(RSVPEngine.minWPM)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Slider(
                    value: Binding(
                        get: { Double(wpm) },
                        set: { wpm = Int($0) }
                    ),
                    in: Double(RSVPEngine.minWPM)...Double(RSVPEngine.maxWPM),
                    step: 25
                )

                Text("\(RSVPEngine.maxWPM)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text("\(wpm) WPM")
                .font(.headline)
                .monospacedDigit()
        }
    }
}

struct ProgressSlider: View {
    @Binding var value: Double
    let isPlaying: Bool
    var leadingLabel: String = ""
    var trailingLabel: String = ""

    @State private var isDragging = false

    var body: some View {
        VStack(spacing: 7) {
            GeometryReader { geometry in
                let clampedValue = min(max(value, 0), 1)
                let width = max(1, geometry.size.width)
                let fillWidth = max(10, width * clampedValue)
                let thumbOffset = max(0, min(width - 18, (width - 18) * clampedValue))

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.18))
                        .frame(height: 8)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor.opacity(0.58), Color.accentColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: fillWidth, height: 8)

                    Circle()
                        .fill(.white.opacity(0.96))
                        .frame(
                            width: (isDragging || !isPlaying) ? 18 : 15,
                            height: (isDragging || !isPlaying) ? 18 : 15
                        )
                        .overlay {
                            Circle()
                                .strokeBorder(.white.opacity(0.5), lineWidth: 1)
                        }
                        .shadow(color: .black.opacity(0.18), radius: 5, y: 1)
                        .offset(x: thumbOffset)
                }
                .animation(.spring(response: 0.2, dampingFraction: 0.82), value: clampedValue)
                .frame(height: 24)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            isDragging = true
                            let newValue = gesture.location.x / width
                            value = min(max(newValue, 0), 1)
                        }
                        .onEnded { _ in
                            isDragging = false
                        }
                )
            }
            .frame(height: 24)

            if !leadingLabel.isEmpty || !trailingLabel.isEmpty {
                HStack {
                    Text(leadingLabel)
                        .font(AppFont.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()

                    Spacer()

                    Text(trailingLabel)
                        .font(AppFont.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
    }
}

#Preview {
    VStack {
        ControlsView(engine: {
            let engine = RSVPEngine()
            engine.load(content: "Sample content for testing the controls view with multiple words.")
            return engine
        }())
    }
    .padding()
}
