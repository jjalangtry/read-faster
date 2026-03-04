import SwiftUI

struct ControlsView: View {
    @ObservedObject var engine: RSVPEngine

    var body: some View {
        VStack(spacing: 16) {
            ReadingModeSelector(currentMode: engine.currentMode) { mode in
                engine.applyMode(mode)
            }

            GlassEffectContainer {
                HStack(spacing: 24) {
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

    @State private var isDragging = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 6)

                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: max(6, geometry.size.width * value), height: 6)

                if isDragging || !isPlaying {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 20, height: 20)
                        .shadow(color: .accentColor.opacity(0.3), radius: 4)
                        .offset(x: max(0, min(geometry.size.width - 20, (geometry.size.width - 20) * value)))
                }
            }
            .frame(height: 24)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        isDragging = true
                        let newValue = gesture.location.x / geometry.size.width
                        value = min(max(newValue, 0), 1)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
        }
        .frame(height: 24)
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
