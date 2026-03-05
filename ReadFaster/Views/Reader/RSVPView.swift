import SwiftUI
import SwiftData

struct RSVPView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let book: Book

    @StateObject private var engine = RSVPEngine()
    @State private var showingBookmarks = false
    @State private var showingSettings = false
    @State private var controlsVisible = true
    @State private var hideControlsTask: Task<Void, Never>?
    @State private var scrubbing = false
    @State private var scrubValue: Double = 0
    @State private var chapterPositions: [UUID: Int] = [:]
    @State private var lastChapterID: UUID?

    @AppStorage("defaultWPM") private var defaultWPM: Int = 300
    @AppStorage("pauseOnPunctuation") private var pauseOnPunctuation: Bool = true
    @AppStorage("readerWordDisplayMode")
    private var wordDisplayModeRaw = WordDisplayMode.singleWord.rawValue

    var body: some View {
        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height

            ZStack {
                backgroundGradient.ignoresSafeArea()

                if isLandscape {
                    landscapeLayout(geometry: geo)
                } else {
                    portraitLayout(geometry: geo)
                }
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
        .sheet(isPresented: $showingSettings) {
            ReaderSettingsSheet(engine: engine)
                .presentationDetents([.medium])
        }
        .onAppear {
            migrateLegacyWordDisplayModeIfNeeded()
            setupEngine()
            lastChapterID = currentChapter?.id
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
        .onChange(of: engine.currentIndex) { _, _ in
            trackChapterChange()
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

    // MARK: - Layouts

    @ViewBuilder
    private func portraitLayout(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 4)
            rsvpHero(geometry: geometry)
            Spacer(minLength: 24)
            controlStack(geometry: geometry)
                .padding(.bottom, 10)
        }
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private func landscapeLayout(geometry: GeometryProxy) -> some View {
        HStack(alignment: .center, spacing: 20) {
            rsvpHero(geometry: geometry)
                .frame(
                    maxWidth: geometry.size.width * 0.48,
                    maxHeight: .infinity
                )

            ScrollView(.vertical, showsIndicators: false) {
                controlStack(geometry: geometry)
                    .padding(.vertical, 8)
            }
            .frame(maxWidth: geometry.size.width * 0.48)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Toolbar (… menu only)

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button { showingBookmarks = true } label: {
                    Label(
                        "Bookmarks",
                        systemImage: book.bookmarks.isEmpty
                            ? "bookmark" : "bookmark.fill"
                    )
                }
                Button { showingSettings = true } label: {
                    Label("Settings", systemImage: "gear")
                }
            } label: {
                Image(systemName: "ellipsis")
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
                    Color.accentColor.opacity(0.06),
                    Color.accentColor.opacity(0.02),
                    .clear
                ],
                startPoint: .top,
                endPoint: .center
            )
        }
    }

    // MARK: - RSVP Hero

    @ViewBuilder
    private func rsvpHero(geometry: GeometryProxy) -> some View {
        let heroWidth = min(geometry.size.width - 48, 640.0)

        VStack(spacing: 0) {
            if engine.showSentenceContext {
                SentenceContextView(
                    allBookWords: book.words,
                    globalWordIndex: engine.currentIndex,
                    highlightCount: engine.currentDisplayWordCount
                )
                .frame(maxWidth: heroWidth)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            Spacer(minLength: 20).frame(maxHeight: 24)

            WordDisplay(
                word: engine.currentWord,
                usesChunkLayout: wordDisplayMode == .threeWordChunk
            )
            .frame(maxWidth: heroWidth)
            .contentShape(Rectangle())
            .onTapGesture { tapToggle() }
        }
    }

    // MARK: - Control Stack

    @ViewBuilder
    private func controlStack(geometry: GeometryProxy) -> some View {
        let maxW = min(geometry.size.width - 48, 500.0)

        VStack(spacing: 0) {
            titleRow
                .frame(maxWidth: maxW, alignment: .leading)
                .opacity(controlsOpacity)
                .padding(.bottom, 14)

            chapterScrubBar
                .frame(maxWidth: maxW)
                .opacity(controlsOpacity)

            metadataRow
                .frame(maxWidth: maxW)
                .opacity(controlsOpacity)
                .padding(.bottom, 18)

            transportControls
                .frame(maxWidth: maxW)
                .padding(.bottom, 20)

            WPMControl(wpm: $engine.wordsPerMinute)
                .frame(maxWidth: maxW)
                .opacity(controlsOpacity)
                .padding(.bottom, 12)

            DisplayModeBar(
                wordDisplayModeRaw: $wordDisplayModeRaw,
                showContext: $engine.showSentenceContext
            )
            .opacity(controlsOpacity)
        }
    }

    // MARK: - Title Row

    private var titleRow: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(.system(size: 21, weight: .bold))
                    .lineLimit(1)

                if let author = book.author, !author.isEmpty {
                    Text(author)
                        .font(.system(size: 21, weight: .regular))
                        .lineLimit(1)
                        .foregroundStyle(Color.accentColor)
                }
            }

            Spacer(minLength: 4)

            if book.hasChapters {
                chapterButton
            }
        }
    }

    // MARK: - Chapter Button (glass circle, same as … button)

    private var chapterButton: some View {
        Menu {
            ForEach(book.chapters.flattened) { chapter in
                Button {
                    selectChapter(chapter)
                } label: {
                    HStack {
                        Text(chapter.title)
                        Spacer()
                        Text(chapterProgress(chapter))
                    }
                }
            }
        } label: {
            Image(systemName: "list.bullet")
                .frame(width: 34, height: 34)
                .contentShape(Circle())
        }
        .buttonStyle(.glass)
        #if os(iOS)
        .sensoryFeedback(.selection, trigger: currentChapter?.id)
        #endif
    }

    // MARK: - Per-Chapter Scrub Bar

    private var chapterScrubBar: some View {
        Slider(
            value: Binding(
                get: {
                    scrubbing ? scrubValue : chapterRelativeProgress
                },
                set: { newValue in
                    scrubValue = newValue
                    if !scrubbing { scrubbing = true }
                }
            ),
            in: 0...1
        ) { editing in
            if !editing {
                seekToChapterRelative(scrubValue)
                scrubbing = false
            }
        }
        .tint(.primary)
    }

    // MARK: - Metadata Row

    private var metadataRow: some View {
        HStack(spacing: 0) {
            Text(chapterPositionText)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)

            if let chapter = currentChapter {
                Text("  ·  ")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
                Text(chapter.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(timeRemainingText ?? "")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.top, 2)
    }

    // MARK: - Transport Controls

    private var transportControls: some View {
        GlassEffectContainer {
            HStack {
                Spacer()
                TransportButton(
                    icon: "backward.fill",
                    disabled: !engine.hasContent || engine.isAtStart,
                    size: 44
                ) { engine.previousSentence() }
                Spacer()
                PlayPauseButton(
                    isPlaying: engine.isPlaying,
                    disabled: !engine.hasContent,
                    size: 56
                ) { engine.toggle() }
                Spacer()
                TransportButton(
                    icon: "forward.fill",
                    disabled: engine.isAtEnd,
                    size: 44
                ) { engine.nextSentence() }
                Spacer()
            }
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

// MARK: - Chapter Helpers

extension RSVPView {
    var currentChapter: Chapter? {
        book.chapters.currentChapter(for: engine.currentIndex)
    }

    var chapterStartIndex: Int {
        currentChapter?.startWordIndex ?? 0
    }

    var chapterEndIndex: Int {
        let flat = book.chapters.flattened
        guard let chapter = currentChapter,
              let idx = flat.firstIndex(where: { $0.id == chapter.id })
        else { return engine.totalWords }
        return idx + 1 < flat.count
            ? flat[idx + 1].startWordIndex
            : engine.totalWords
    }

    var chapterRelativeProgress: Double {
        let length = max(1, chapterEndIndex - chapterStartIndex)
        let pos = max(0, engine.currentIndex - chapterStartIndex)
        return Double(min(pos, length)) / Double(length)
    }

    func seekToChapterRelative(_ progress: Double) {
        let length = chapterEndIndex - chapterStartIndex
        let target = chapterStartIndex + Int(progress * Double(length))
        engine.seek(
            to: min(max(target, chapterStartIndex), chapterEndIndex - 1)
        )
    }

    func selectChapter(_ chapter: Chapter) {
        if let curID = currentChapter?.id {
            chapterPositions[curID] = engine.currentIndex
        }
        scrubbing = false
        if let saved = chapterPositions[chapter.id] {
            engine.seek(to: saved)
        } else {
            engine.seek(to: chapter.startWordIndex)
        }
        lastChapterID = chapter.id
    }

    func trackChapterChange() {
        guard let curID = currentChapter?.id else { return }
        if curID != lastChapterID {
            if let oldID = lastChapterID {
                chapterPositions[oldID] = engine.currentIndex
            }
            lastChapterID = curID
        }
        chapterPositions[curID] = engine.currentIndex
    }

    func chapterProgress(_ chapter: Chapter) -> String {
        let flat = book.chapters.flattened
        guard let idx = flat.firstIndex(where: { $0.id == chapter.id })
        else { return "" }

        let start = chapter.startWordIndex
        let end = idx + 1 < flat.count
            ? flat[idx + 1].startWordIndex
            : engine.totalWords
        let length = max(1, end - start)

        let posInChapter: Int
        if let saved = chapterPositions[chapter.id] {
            posInChapter = max(0, min(saved - start, length))
        } else if let cur = currentChapter, cur.id == chapter.id {
            posInChapter = max(0, min(engine.currentIndex - start, length))
        } else {
            return "0%"
        }
        let pct = Int(Double(posInChapter) / Double(length) * 100)
        return "\(max(0, min(100, pct)))%"
    }
}

// MARK: - Text Helpers & Engine Setup

extension RSVPView {
    var chapterPositionText: String {
        if book.hasChapters {
            let length = max(1, chapterEndIndex - chapterStartIndex)
            let pos = max(0, engine.currentIndex - chapterStartIndex)
            let pct = min(
                100, max(0, Int(chapterRelativeProgress * 100))
            )
            return "\(min(pos + 1, length)) / \(length) · \(pct)%"
        }
        let total = engine.totalWords
        guard total > 0 else { return "0 / 0" }
        let cur = min(max(engine.currentIndex + 1, 1), total)
        let pct = min(100, max(0, Int(engine.displayedProgress * 100)))
        return "\(cur) / \(total) · \(pct)%"
    }

    var timeRemainingText: String? {
        let left: Int
        if book.hasChapters {
            left = max(0, chapterEndIndex - engine.currentIndex)
        } else {
            left = max(
                0,
                engine.totalWords
                    - (engine.currentIndex + engine.currentDisplayWordCount)
            )
        }
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
              defaults.object(forKey: "wordsPerChunk") != nil
        else { return }
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
        try? svc.addBookmark(
            to: book, at: engine.currentIndex, highlightedText: ctx
        )
    }

    var wordDisplayMode: WordDisplayMode {
        WordDisplayMode(rawValue: wordDisplayModeRaw) ?? .singleWord
    }

    func toggleChunkMode() {
        wordDisplayModeRaw = (wordDisplayMode == .threeWordChunk
            ? WordDisplayMode.singleWord : .threeWordChunk).rawValue
    }
}

#Preview {
    NavigationStack {
        RSVPView(book: Book(
            title: "Sample Book",
            author: "Author",
            fileName: "sample.txt",
            fileType: .txt,
            content: "This is a sample book with content for RSVP.",
            totalWords: 9
        ))
    }
    .modelContainer(
        for: [Book.self, ReadingProgress.self, Bookmark.self],
        inMemory: true
    )
}
