import SwiftUI
import SwiftData

struct RSVPView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let book: Book

    @StateObject private var engine = RSVPEngine()
    @State private var showingBookmarks = false
    @State private var showingSettings = false
    @Namespace private var controlsNamespace

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background - allows glass to sample content
                Color(.systemBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    wordDisplayArea(geometry: geometry)

                    Spacer()

                    // Floating glass controls at bottom
                    floatingControls
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }
            }
        }
        .navigationTitle(book.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 8) {
                    Button {
                        addBookmark()
                    } label: {
                        Image(systemName: "bookmark")
                    }
                    .badge(book.bookmarks.count > 0 ? "\(book.bookmarks.count)" : nil)

                    Button {
                        showingBookmarks = true
                    } label: {
                        Image(systemName: "list.bullet")
                    }

                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
        }
        .sheet(isPresented: $showingBookmarks) {
            BookmarksSheet(book: book, engine: engine)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingSettings) {
            ReaderSettingsSheet(engine: engine)
                .presentationDetents([.medium])
        }
        .onAppear {
            setupEngine()
        }
        .onDisappear {
            engine.pause()
        }
        #if os(macOS)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)) { _ in
            engine.pause()
        }
        #else
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            engine.pause()
        }
        #endif
    }

    @ViewBuilder
    private func wordDisplayArea(geometry: GeometryProxy) -> some View {
        VStack(spacing: 20) {
            WordDisplay(word: engine.currentWord)
                .frame(maxWidth: min(geometry.size.width * 0.9, 600))
                .contentShape(Rectangle())
                .onTapGesture {
                    engine.toggle()
                }

            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var floatingControls: some View {
        VStack(spacing: 16) {
            // Progress bar
            ProgressSlider(
                value: Binding(
                    get: { engine.progress },
                    set: { engine.seekToProgress($0) }
                ),
                isPlaying: engine.isPlaying
            )

            // Playback controls with Liquid Glass
            GlassEffectContainer {
                HStack(spacing: 24) {
                    // Skip backward
                    Button {
                        engine.previousSentence()
                    } label: {
                        Image(systemName: "backward.end.fill")
                            .font(.title3)
                            .frame(width: 44, height: 44)
                    }
                    .glassEffect(.regular.interactive())
                    .disabled(!engine.hasContent)

                    Button {
                        engine.skipBackward()
                    } label: {
                        Image(systemName: "gobackward.10")
                            .font(.title3)
                            .frame(width: 44, height: 44)
                    }
                    .glassEffect(.regular.interactive())
                    .disabled(engine.isAtStart)

                    // Play/Pause - larger, prominent
                    Button {
                        engine.toggle()
                    } label: {
                        Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title)
                            .frame(width: 64, height: 64)
                    }
                    .glassEffect(.regular.tint(.accentColor).interactive())
                    .disabled(!engine.hasContent)

                    Button {
                        engine.skipForward()
                    } label: {
                        Image(systemName: "goforward.10")
                            .font(.title3)
                            .frame(width: 44, height: 44)
                    }
                    .glassEffect(.regular.interactive())
                    .disabled(engine.isAtEnd)

                    // Skip forward
                    Button {
                        engine.nextSentence()
                    } label: {
                        Image(systemName: "forward.end.fill")
                            .font(.title3)
                            .frame(width: 44, height: 44)
                    }
                    .glassEffect(.regular.interactive())
                    .disabled(!engine.hasContent)
                }
            }

            // WPM control with glass
            WPMControl(wpm: $engine.wordsPerMinute)
        }
    }

    private var statusText: String {
        let current = engine.currentIndex + 1
        let total = engine.totalWords
        let percent = Int(engine.progress * 100)
        return "\(current) / \(total) (\(percent)%)"
    }

    private func setupEngine() {
        engine.load(words: book.words)

        // Resume from saved position
        if let progress = book.progress {
            engine.seek(to: progress.currentWordIndex)
        }

        // Setup progress callback
        engine.onProgressUpdate = { [weak engine] wordIndex, sessionTime, wordsRead in
            guard engine != nil else { return }
            Task { @MainActor in
                let storage = StorageService(modelContext: modelContext)
                try? storage.updateProgress(
                    for: book,
                    wordIndex: wordIndex,
                    sessionTime: sessionTime,
                    wordsRead: wordsRead
                )
            }
        }

        // Start session
        Task {
            let storage = StorageService(modelContext: modelContext)
            try? storage.startReadingSession(for: book)
        }
    }

    private func addBookmark() {
        let storage = StorageService(modelContext: modelContext)
        let words = book.words
        let startIndex = max(0, engine.currentIndex - 5)
        let endIndex = min(words.count, engine.currentIndex + 5)
        let context = words[startIndex..<endIndex].joined(separator: " ")

        try? storage.addBookmark(
            to: book,
            at: engine.currentIndex,
            highlightedText: context
        )
    }
}

struct WPMControl: View {
    @Binding var wpm: Int
    @State private var isExpanded = false
    @Namespace private var wpmNamespace

    var body: some View {
        GlassEffectContainer(spacing: 20) {
            if isExpanded {
                // Expanded slider view
                HStack(spacing: 12) {
                    Text("\(RSVPEngine.minWPM)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Slider(
                        value: Binding(
                            get: { Double(wpm) },
                            set: { wpm = Int($0) }
                        ),
                        in: Double(RSVPEngine.minWPM)...Double(RSVPEngine.maxWPM),
                        step: 25
                    )
                    .frame(width: 200)

                    Text("\(RSVPEngine.maxWPM)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button {
                        withAnimation(.bouncy) {
                            isExpanded = false
                        }
                    } label: {
                        Image(systemName: "checkmark")
                            .frame(width: 32, height: 32)
                    }
                    .glassEffect(.regular.interactive())
                    .glassEffectID("wpmToggle", in: wpmNamespace)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .glassEffect(.regular, in: .capsule)
            } else {
                // Collapsed button
                Button {
                    withAnimation(.bouncy) {
                        isExpanded = true
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "speedometer")
                        Text("\(wpm) WPM")
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .glassEffect(.regular.interactive())
                .glassEffectID("wpmToggle", in: wpmNamespace)
            }
        }
    }
}

#Preview {
    NavigationStack {
        RSVPView(book: Book(
            title: "Sample Book",
            author: "Author",
            fileName: "sample.txt",
            fileType: .txt,
            content: "This is a sample book with some content to display in the RSVP reader. It contains multiple words that will be shown one at a time.",
            totalWords: 25
        ))
    }
    .modelContainer(for: [Book.self, ReadingProgress.self, Bookmark.self], inMemory: true)
}
