import SwiftUI
import SwiftData

struct RSVPView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let book: Book

    @StateObject private var engine = RSVPEngine()
    @State private var showingBookmarks = false
    @State private var showingChapters = false
    @State private var showingSettings = false
    @State private var controlsVisible = true
    @State private var hideControlsTask: Task<Void, Never>?

    @AppStorage("defaultWPM") private var defaultWPM: Int = 300
    @AppStorage("pauseOnPunctuation") private var pauseOnPunctuation: Bool = true
    @AppStorage("readerWordDisplayMode")
    private var wordDisplayModeRaw = WordDisplayMode.singleWord.rawValue

    #if os(macOS)
    private let playButtonSize: CGFloat = 72
    private let controlButtonSize: CGFloat = 52
    #else
    private let playButtonSize: CGFloat = 70
    private let controlButtonSize: CGFloat = 48
    #endif

    var body: some View {
        GeometryReader { geo in
            ZStack {
                backgroundGradient.ignoresSafeArea()

                VStack(spacing: 0) {
                    bookHeader
                        .padding(.top, 8)
                        .opacity(controlsOpacity)

                    Spacer(minLength: 16)

                    rsvpFocalArea(geometry: geo)

                    Spacer(minLength: 16)

                    nowPlayingControls(geometry: geo)
                        .opacity(controlsOpacity)
                        .padding(.bottom, 8)
                }
                .padding(.horizontal, 20)
            }
            .contentShape(Rectangle())
            #if os(iOS)
            .gesture(swipeGestures)
            #endif
        }
        .navigationTitle("")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        #endif
        .toolbar { toolbarContent }
        .sheet(isPresented: $showingBookmarks) {
            BookmarksSheet(book: book, engine: engine) { addBookmark() }
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingChapters) {
            ChaptersSheet(book: book, engine: engine)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingSettings) {
            ReaderSettingsSheet(engine: engine)
                .presentationDetents([.medium])
        }
        .onAppear {
            migrateLegacyWordDisplayModeIfNeeded()
            setupEngine()
        }
        .onChange(of: wordDisplayModeRaw) { _, rawValue in
            let mode = WordDisplayMode(rawValue: rawValue) ?? .singleWord
            guard mode.rawValue == rawValue else {
                wordDisplayModeRaw = mode.rawValue
                return
            }
            Task { @MainActor in
                engine.setWordsPerChunk(mode.wordsPerChunk)
            }
        }
        .onChange(of: pauseOnPunctuation) { _, newValue in
            engine.pauseOnPunctuation = newValue
        }
        .onChange(of: engine.isPlaying) { _, playing in
            scheduleAutoHide(playing: playing)
        }
        .onDisappear { engine.pause() }
        #if os(macOS)
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSApplication.willResignActiveNotification
            )
        ) { _ in engine.pause() }
        .onKeyPress(.space) { engine.toggle(); return .handled }
        .onKeyPress("k") { engine.toggle(); return .handled }
        .onKeyPress(.leftArrow) { engine.previousSentence(); return .handled }
        .onKeyPress(.rightArrow) { engine.nextSentence(); return .handled }
        .onKeyPress("j") { engine.previousSentence(); return .handled }
        .onKeyPress("l") { engine.nextSentence(); return .handled }
        .onKeyPress(.upArrow) {
            engine.wordsPerMinute = min(RSVPEngine.maxWPM, engine.wordsPerMinute + 25)
            return .handled
        }
        .onKeyPress(.downArrow) {
            engine.wordsPerMinute = max(RSVPEngine.minWPM, engine.wordsPerMinute - 25)
            return .handled
        }
        .onKeyPress("r") { engine.replayCurrentSentence(); return .handled }
        .onKeyPress("3") { toggleChunkMode(); return .handled }
        .focusable()
        #else
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIApplication.willResignActiveNotification
            )
        ) { _ in engine.pause() }
        #endif
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            HStack(spacing: 8) {
                Button { toggleChunkMode() } label: {
                    Image(systemName: wordDisplayMode == .threeWordChunk
                          ? "text.justify" : "text.justify.left")
                }

                Button { showingBookmarks = true } label: {
                    Image(systemName: book.bookmarks.isEmpty
                          ? "bookmark" : "bookmark.fill")
                }

                if book.hasChapters {
                    Button { showingChapters = true } label: {
                        Image(systemName: "list.bullet.indent")
                    }
                }

                Button { showingSettings = true } label: {
                    Image(systemName: "gear")
                }
            }
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        ZStack {
            #if os(macOS)
            Color(NSColor.windowBackgroundColor)
            #else
            Color(UIColor.systemBackground)
            #endif

            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.08),
                    Color.accentColor.opacity(0.03),
                    .clear
                ],
                startPoint: .top,
                endPoint: .center
            )
        }
    }

    // MARK: - Book Header

    private var bookHeader: some View {
        VStack(spacing: 4) {
            Text(book.title)
                .font(AppFont.headline)
                .lineLimit(1)
                .foregroundStyle(.primary)

            if let author = book.author, !author.isEmpty {
                Text(author)
                    .font(AppFont.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - RSVP Focal Area

    @ViewBuilder
    private func rsvpFocalArea(geometry: GeometryProxy) -> some View {
        VStack(spacing: 20) {
            if engine.showSentenceContext
                && !engine.currentSentenceWords.isEmpty {
                SentenceContextView(
                    words: engine.currentSentenceWords,
                    currentWordIndex: engine.currentWordIndexInSentence
                )
                .frame(
                    maxWidth: min(geometry.size.width * 0.92, 600),
                    maxHeight: 80,
                    alignment: .top
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .opacity(controlsOpacity)
            }

            WordDisplay(
                word: engine.currentWord,
                usesChunkLayout: wordDisplayMode == .threeWordChunk
            )
            .frame(maxWidth: min(geometry.size.width * 0.92, 640))
            .contentShape(Rectangle())
            .onTapGesture { tapToggle() }
        }
    }

    // MARK: - Now Playing Controls

    @ViewBuilder
    private func nowPlayingControls(geometry: GeometryProxy) -> some View {
        let maxW = min(geometry.size.width - 40, 500.0)

        VStack(spacing: 20) {
            progressSection.frame(maxWidth: maxW)
            playbackButtons.frame(maxWidth: maxW)
            WPMControl(wpm: $engine.wordsPerMinute).frame(maxWidth: maxW)

            ReadingModeSelector(currentMode: engine.currentMode) { mode in
                engine.applyMode(mode)
            }
        }
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        VStack(spacing: 6) {
            NowPlayingProgressBar(
                value: Binding(
                    get: { engine.displayedProgress },
                    set: { engine.seekToProgress($0) }
                ),
                isPlaying: engine.isPlaying
            )

            HStack {
                Text(elapsedPositionText)
                    .font(AppFont.caption).monospacedDigit()
                    .foregroundStyle(.secondary)
                Spacer()
                Text(timeRemainingText ?? "")
                    .font(AppFont.caption).monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Playback Buttons

    private var playbackButtons: some View {
        HStack(spacing: 0) {
            Spacer()
            HoldableButton(
                icon: "backward.fill",
                onTap: { engine.previousSentence() },
                onHoldTick: { engine.previousSentence() },
                disabled: !engine.hasContent || engine.isAtStart,
                size: controlButtonSize, iconFont: .title3
            )
            Spacer()
            PlayPauseButton(
                isPlaying: engine.isPlaying,
                disabled: !engine.hasContent,
                size: playButtonSize
            ) { engine.toggle() }
            Spacer()
            HoldableButton(
                icon: "forward.fill",
                onTap: { engine.nextSentence() },
                onHoldTick: { engine.nextSentence() },
                disabled: engine.isAtEnd,
                size: controlButtonSize, iconFont: .title3
            )
            Spacer()
        }
    }
}

// MARK: - Auto-Hide & Gestures

extension RSVPView {
    var controlsOpacity: Double {
        controlsVisible || !engine.isPlaying ? 1 : 0.15
    }

    func scheduleAutoHide(playing: Bool) {
        hideControlsTask?.cancel()
        if playing {
            hideControlsTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled, engine.isPlaying else { return }
                withAnimation(.easeOut(duration: 0.5)) {
                    controlsVisible = false
                }
            }
        } else {
            withAnimation(.easeOut(duration: 0.3)) {
                controlsVisible = true
            }
        }
    }

    func tapToggle() {
        if engine.isPlaying && !controlsVisible {
            withAnimation(.easeOut(duration: 0.25)) { controlsVisible = true }
            scheduleAutoHide(playing: true)
            return
        }
        engine.toggle()
    }

    #if os(iOS)
    var swipeGestures: some Gesture {
        DragGesture(minimumDistance: 50, coordinateSpace: .local)
            .onEnded { value in
                let hori = value.translation.width
                let vert = value.translation.height
                if abs(hori) > abs(vert) {
                    if hori < -50 {
                        engine.nextSentence()
                    } else if hori > 50 {
                        engine.previousSentence()
                    }
                } else if vert > 80 {
                    dismiss()
                }
            }
    }
    #endif
}

// MARK: - Text Helpers & Engine Setup

extension RSVPView {
    var elapsedPositionText: String {
        let total = engine.totalWords
        guard total > 0 else { return "0 / 0" }
        let cur = min(max(engine.currentIndex + 1, 1), total)
        let pct = min(100, max(0, Int(engine.displayedProgress * 100)))
        return "\(cur) / \(total)  ·  \(pct)%"
    }

    var timeRemainingText: String? {
        let left = max(
            0, engine.totalWords - (engine.currentIndex + engine.currentDisplayWordCount)
        )
        guard left > 0, engine.wordsPerMinute > 0 else { return nil }
        let secs = Int(Double(left) / Double(engine.wordsPerMinute) * 60)
        let hours = secs / 3600
        let mins = (secs % 3600) / 60
        if hours > 0 { return "-\(hours)h \(mins)m" }
        if mins > 0 { return "-\(mins)m" }
        return "-<1m"
    }

    func setupEngine() {
        engine.load(words: book.words)
        engine.wordsPerMinute = defaultWPM
        engine.pauseOnPunctuation = pauseOnPunctuation
        engine.setWordsPerChunk(wordDisplayMode.wordsPerChunk)

        if let progress = book.progress {
            engine.seek(to: progress.currentWordIndex)
        }

        engine.onProgressUpdate = { [weak engine] idx, time, count in
            guard engine != nil else { return }
            Task { @MainActor in
                let svc = StorageService(modelContext: modelContext)
                try? svc.updateProgress(
                    for: book, wordIndex: idx,
                    sessionTime: time, wordsRead: count
                )
            }
        }

        Task {
            let svc = StorageService(modelContext: modelContext)
            try? svc.startReadingSession(for: book)
        }
    }

    func migrateLegacyWordDisplayModeIfNeeded() {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: "readerWordDisplayMode") == nil,
              defaults.object(forKey: "wordsPerChunk") != nil else { return }
        let legacy = defaults.integer(forKey: "wordsPerChunk")
        wordDisplayModeRaw = (legacy >= 3
            ? WordDisplayMode.threeWordChunk : .singleWord).rawValue
    }

    func addBookmark() {
        let svc = StorageService(modelContext: modelContext)
        let allWords = book.words
        let start = max(0, engine.currentIndex - 5)
        let end = min(allWords.count, engine.currentIndex + 5)
        let ctx = allWords[start..<end].joined(separator: " ")
        try? svc.addBookmark(to: book, at: engine.currentIndex, highlightedText: ctx)
    }

    var wordDisplayMode: WordDisplayMode {
        WordDisplayMode(rawValue: wordDisplayModeRaw) ?? .singleWord
    }

    func toggleChunkMode() {
        wordDisplayModeRaw = (wordDisplayMode == .threeWordChunk
            ? WordDisplayMode.singleWord : .threeWordChunk).rawValue
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        RSVPView(book: Book(
            title: "Sample Book",
            author: "Author",
            fileName: "sample.txt",
            fileType: .txt,
            content: "This is a sample book with some content for RSVP.",
            totalWords: 10
        ))
    }
    .modelContainer(
        for: [Book.self, ReadingProgress.self, Bookmark.self],
        inMemory: true
    )
}
