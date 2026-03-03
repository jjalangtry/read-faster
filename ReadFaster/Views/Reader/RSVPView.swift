import SwiftUI
import SwiftData

// swiftlint:disable type_body_length
struct RSVPView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let book: Book

    @StateObject private var engine = RSVPEngine()
    @State private var showingBookmarks = false
    @State private var showingChapters = false
    @State private var showingSettings = false
    @Namespace private var controlsNamespace

    @AppStorage("defaultWPM") private var defaultWPM: Int = 300
    @AppStorage("pauseOnPunctuation") private var pauseOnPunctuation: Bool = true
    @AppStorage("readerWordDisplayMode") private var wordDisplayModeRaw = WordDisplayMode.singleWord.rawValue
    
    // Platform-adaptive button sizes (larger on macOS for better click targets)
    #if os(macOS)
    private let controlButtonSize: CGFloat = 56
    private let playButtonSize: CGFloat = 72
    #else
    private let controlButtonSize: CGFloat = 52
    private let playButtonSize: CGFloat = 68
    #endif

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background - allows glass to sample content
                #if os(macOS)
                Color(NSColor.windowBackgroundColor)
                    .ignoresSafeArea()
                #else
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
                #endif

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
                        toggleChunkMode()
                    } label: {
                        Image(systemName: wordDisplayMode == .threeWordChunk ? "text.justify" : "text.justify.left")
                    }
                    .help(wordDisplayMode == .threeWordChunk ? "Switch to one-word mode" : "Switch to three-word mode")

                    Button {
                        showingBookmarks = true
                    } label: {
                        Image(systemName: book.bookmarks.isEmpty ? "bookmark" : "bookmark.fill")
                    }

                    if book.hasChapters {
                    Button {
                            showingChapters = true
                    } label: {
                            Image(systemName: "list.bullet.indent")
                        }
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
            BookmarksSheet(book: book, engine: engine) {
                addBookmark()
            }
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
            let mode = WordDisplayMode(rawValue: rawValue) ?? WordDisplayMode.singleWord
            guard mode.rawValue == rawValue else {
                wordDisplayModeRaw = mode.rawValue
                return
            }
            // Defer engine mutation to avoid publishing during view updates.
            Task { @MainActor in
                engine.setWordsPerChunk(mode.wordsPerChunk)
            }
        }
        .onChange(of: pauseOnPunctuation) { _, newValue in
            engine.pauseOnPunctuation = newValue
        }
        .onDisappear {
            engine.pause()
        }
        #if os(macOS)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)) { _ in
            engine.pause()
        }
        // Keyboard shortcuts for macOS
        .onKeyPress(.space) {
            engine.toggle()
            return .handled
        }
        .onKeyPress("k") {
            engine.toggle()
            return .handled
        }
        .onKeyPress(.leftArrow) {
            engine.previousSentence()
            return .handled
        }
        .onKeyPress(.rightArrow) {
            engine.nextSentence()
            return .handled
        }
        .onKeyPress("j") {
            engine.previousSentence()
            return .handled
        }
        .onKeyPress("l") {
            engine.nextSentence()
            return .handled
        }
        .onKeyPress(.upArrow) {
            engine.wordsPerMinute = min(RSVPEngine.maxWPM, engine.wordsPerMinute + 25)
            return .handled
        }
        .onKeyPress(.downArrow) {
            engine.wordsPerMinute = max(RSVPEngine.minWPM, engine.wordsPerMinute - 25)
            return .handled
        }
        .onKeyPress("r") {
            engine.replayCurrentSentence()
            return .handled
        }
        .onKeyPress("3") {
            toggleChunkMode()
            return .handled
        }
        .focusable()
        #else
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            engine.pause()
        }
        #endif
    }

    @ViewBuilder
    private func wordDisplayArea(geometry: GeometryProxy) -> some View {
        VStack(spacing: 12) {
            // Sentence context - dynamic height, clipped to bounds
            if engine.showSentenceContext && !engine.currentSentenceWords.isEmpty {
                SentenceContextView(
                    words: engine.currentSentenceWords,
                    currentWordIndex: engine.currentWordIndexInSentence
                )
                .frame(
                    maxWidth: min(geometry.size.width * 0.95, 640),
                    minHeight: 120,
                    maxHeight: 120,
                    alignment: .top
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
            
            // Main RSVP word - always in the same position
            WordDisplay(
                word: engine.currentWord,
                usesChunkLayout: wordDisplayMode == .threeWordChunk
            )
                .frame(maxWidth: min(geometry.size.width * 0.92, 680))
                .contentShape(Rectangle())
                .onTapGesture {
                    engine.toggle()
                }

            // Status: word count and time remaining
            HStack(spacing: 8) {
                if chapterContext.title != "Whole Book" {
                    statusChip(text: chapterContext.title, systemImage: "book.closed")
                }

                statusChip(text: statusText, systemImage: "textformat.123")

                if let timeRemaining = timeRemainingText {
                    statusChip(text: timeRemaining, systemImage: "clock")
                }
            }
            .padding(.top, 6)
        }
    }

    private var floatingControls: some View {
        VStack(spacing: 16) {
            nowPlayingHeader

            ReadingModeSelector(currentMode: engine.currentMode) { mode in
                engine.applyMode(mode)
            }

            ProgressSlider(
                value: Binding(
                    get: { chapterProgress },
                    set: { seekWithinCurrentChapter(to: $0) }
                ),
                isPlaying: engine.isPlaying,
                leadingLabel: chapterElapsedLabel,
                trailingLabel: chapterRemainingLabel
            )

            HStack(spacing: 20) {
                HoldableButton(
                    icon: "backward.fill",
                    onTap: { engine.previousSentence() },
                    onHoldTick: { engine.previousSentence() },
                    disabled: !engine.hasContent || engine.isAtStart,
                    size: controlButtonSize
                )

                    // Play/Pause - larger, prominent
                HoldableButton(
                    icon: engine.isPlaying ? "pause.fill" : "play.fill",
                    onTap: { engine.toggle() },
                    onHoldTick: { }, // No hold action for play/pause
                    disabled: !engine.hasContent,
                    size: playButtonSize,
                    iconFont: .title,
                    accentedBackground: true
                )
                
                // Forward: tap = next sentence, hold = continuous forward
                HoldableButton(
                    icon: "forward.fill",
                    onTap: { engine.nextSentence() },
                    onHoldTick: { engine.nextSentence() },
                    disabled: engine.isAtEnd,
                    size: controlButtonSize
                )
            }

            WPMControl(wpm: $engine.wordsPerMinute)
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 16)
        .background {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(.clear)
                .glassEffect(
                    .regular.tint(Color.white.opacity(0.08)),
                    in: RoundedRectangle(cornerRadius: 30, style: .continuous)
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.14), radius: 22, y: 10)
    }

    private var nowPlayingHeader: some View {
        HStack(spacing: 12) {
            nowPlayingArtwork

            VStack(alignment: .leading, spacing: 2) {
                Text(chapterContext.title)
                    .font(AppFont.semibold(size: 17))
                    .lineLimit(1)

                Text(nowPlayingSubtitle)
                    .font(AppFont.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(chapterProgressPercentText)
                    .font(AppFont.semibold(size: 13))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                Text(chapterWordPositionText)
                    .font(AppFont.caption2)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
        }
    }

    private var nowPlayingArtwork: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.accentColor.opacity(0.78),
                        Color.accentColor.opacity(0.52)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                Image(systemName: "text.book.closed.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(.white.opacity(0.28), lineWidth: 1)
            }
            .frame(width: 50, height: 50)
    }

    private var nowPlayingSubtitle: String {
        if let author = book.author, !author.isEmpty {
            return "\(book.title) - \(author)"
        }
        return book.title
    }

    private var orderedChapters: [Chapter] {
        book.chapters.flattened.sorted { lhs, rhs in
            if lhs.startWordIndex == rhs.startWordIndex {
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            return lhs.startWordIndex < rhs.startWordIndex
        }
    }

    private var chapterContext: ChapterPlaybackContext {
        let total = engine.totalWords
        guard total > 0 else {
            return ChapterPlaybackContext(title: "Whole Book", startWordIndex: 0, endWordIndexExclusive: 1)
        }

        guard let chapter = book.chapters.currentChapter(for: engine.currentIndex) else {
            return ChapterPlaybackContext(
                title: "Whole Book",
                startWordIndex: 0,
                endWordIndexExclusive: total
            )
        }

        let start = min(max(chapter.startWordIndex, 0), max(0, total - 1))
        let nextStart = orderedChapters
            .map(\.startWordIndex)
            .first(where: { $0 > start }) ?? total
        let end = max(start + 1, min(total, nextStart))
        let title = chapter.title.isEmpty ? "Current Chapter" : chapter.title

        return ChapterPlaybackContext(title: title, startWordIndex: start, endWordIndexExclusive: end)
    }

    private var chapterConsumedWords: Int {
        let context = chapterContext
        let localConsumed = (engine.currentIndex - context.startWordIndex) + engine.currentDisplayWordCount
        return min(context.wordCount, max(0, localConsumed))
    }

    private var chapterRemainingWords: Int {
        max(0, chapterContext.wordCount - chapterConsumedWords)
    }

    private var chapterProgress: Double {
        guard chapterContext.wordCount > 0 else { return 0 }
        return Double(chapterConsumedWords) / Double(chapterContext.wordCount)
    }

    private var chapterProgressPercentText: String {
        let percent = min(100, max(0, Int(chapterProgress * 100)))
        return "\(percent)%"
    }

    private var chapterWordPositionText: String {
        let displayStart = min(max(chapterConsumedWords, 1), chapterContext.wordCount)
        return "\(displayStart)/\(chapterContext.wordCount)"
    }

    private var chapterElapsedLabel: String {
        formattedDuration(forWordCount: chapterConsumedWords)
    }

    private var chapterRemainingLabel: String {
        "-" + formattedDuration(forWordCount: chapterRemainingWords)
    }

    private func seekWithinCurrentChapter(to progress: Double) {
        guard engine.totalWords > 0 else { return }
        let context = chapterContext
        let clampedProgress = min(max(progress, 0), 1)
        let maxOffset = max(0, context.wordCount - 1)
        let offset = Int((Double(maxOffset) * clampedProgress).rounded(.toNearestOrAwayFromZero))
        let targetIndex = min(context.endWordIndexExclusive - 1, context.startWordIndex + offset)
        engine.seek(to: targetIndex)
    }

    private func formattedDuration(forWordCount wordCount: Int) -> String {
        guard engine.wordsPerMinute > 0 else { return "0:00" }
        let totalSeconds = Int((Double(wordCount) / Double(engine.wordsPerMinute)) * 60.0)
        return formattedDuration(seconds: totalSeconds)
    }

    private func formattedDuration(seconds: Int) -> String {
        let clamped = max(0, seconds)
        let hours = clamped / 3600
        let minutes = (clamped % 3600) / 60
        let secs = clamped % 60

        if hours > 0 {
            return "\(hours):\(twoDigit(minutes)):\(twoDigit(secs))"
        }
        return "\(minutes):\(twoDigit(secs))"
    }

    private func twoDigit(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }

    private struct ChapterPlaybackContext {
        let title: String
        let startWordIndex: Int
        let endWordIndexExclusive: Int

        var wordCount: Int {
            max(1, endWordIndexExclusive - startWordIndex)
        }
    }

    private var statusText: String {
        let total = engine.totalWords
        guard total > 0 else { return "0 / 0" }

        let start = min(max(engine.currentIndex + 1, 1), total)
        let end = min(total, start + engine.currentDisplayWordCount - 1)
        let percent = min(100, max(0, Int(engine.displayedProgress * 100)))

        if end > start {
            return "\(start)-\(end) / \(total) (\(percent)%)"
        }

        return "\(start) / \(total) (\(percent)%)"
    }
    
    /// Calculates time remaining based on current WPM and words left
    private var timeRemainingText: String? {
        let wordsRemaining = max(0, engine.totalWords - (engine.currentIndex + engine.currentDisplayWordCount))
        guard wordsRemaining > 0, engine.wordsPerMinute > 0 else { return nil }
        
        let minutesRemaining = Double(wordsRemaining) / Double(engine.wordsPerMinute)
        let totalSeconds = Int(minutesRemaining * 60)
        
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m left"
        } else if minutes > 0 {
            return "\(minutes)m left"
        } else {
            return "<1m left"
        }
    }

    private func setupEngine() {
        engine.load(words: book.words)
        engine.wordsPerMinute = defaultWPM
        engine.pauseOnPunctuation = pauseOnPunctuation
        engine.setWordsPerChunk(wordDisplayMode.wordsPerChunk)

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

    private func migrateLegacyWordDisplayModeIfNeeded() {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: "readerWordDisplayMode") == nil,
              defaults.object(forKey: "wordsPerChunk") != nil else { return }

        let legacyValue = defaults.integer(forKey: "wordsPerChunk")
        wordDisplayModeRaw = (
            legacyValue >= 3 ? WordDisplayMode.threeWordChunk : WordDisplayMode.singleWord
        ).rawValue
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

    private var wordDisplayMode: WordDisplayMode {
        WordDisplayMode(rawValue: wordDisplayModeRaw) ?? WordDisplayMode.singleWord
    }

    private func toggleChunkMode() {
        wordDisplayModeRaw = (
            wordDisplayMode == .threeWordChunk ? WordDisplayMode.singleWord : WordDisplayMode.threeWordChunk
        ).rawValue
    }

    @ViewBuilder
    private func statusChip(text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(AppFont.caption)
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
    }
}
// swiftlint:enable type_body_length

struct WPMControl: View {
    @Binding var wpm: Int
    @State private var isExpanded = false
    @State private var sliderValue: Double = 300
    
    // Hold-to-repeat state
    @State private var decreaseTimer: Timer?
    @State private var increaseTimer: Timer?
    @State private var tickCount = 0
    @State private var isDecreasePressed = false
    @State private var isIncreasePressed = false

    private let step = 25 // Smaller step for smoother control
    private let holdDelay: TimeInterval = 0.25
    private let initialTickInterval: TimeInterval = 0.12
    private let minimumTickInterval: TimeInterval = 0.04

    var body: some View {
        HStack(spacing: 0) {
        if isExpanded {
                // Expanded slider view
            HStack(spacing: 12) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded = false
                        }
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
                    .frame(minWidth: 120, maxWidth: 200)
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
        } else {
                // Compact stepper view with hold-to-repeat
                HStack(spacing: 4) {
                    // Decrease button - holdable
                    wpmButton(
                        icon: "minus",
                        isPressed: $isDecreasePressed,
                        disabled: wpm <= RSVPEngine.minWPM,
                        onTap: { decreaseWPM() },
                        onHoldStart: { startDecreaseTimer() },
                        onHoldEnd: { stopDecreaseTimer() }
                    )

                    // WPM display - tap to expand slider
            Button {
                sliderValue = Double(wpm)
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded = true
                }
            } label: {
                        VStack(spacing: 2) {
                            Text("\(wpm)")
                                .font(AppFont.headline)
                        .monospacedDigit()
                            Text("WPM")
                                .font(AppFont.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 56)
                    }
                    .buttonStyle(.plain)

                    // Increase button - holdable
                    wpmButton(
                        icon: "plus",
                        isPressed: $isIncreasePressed,
                        disabled: wpm >= RSVPEngine.maxWPM,
                        onTap: { increaseWPM() },
                        onHoldStart: { startIncreaseTimer() },
                        onHoldEnd: { stopIncreaseTimer() }
                    )
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }
    
    @ViewBuilder
    private func wpmButton(
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
            .scaleEffect(isPressed.wrappedValue ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.1), value: isPressed.wrappedValue)
            .background {
                Circle()
                    .fill(.clear)
                    .glassEffect(.regular.interactive(), in: Circle())
            }
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
                        
                        if !wasHolding && !disabled {
                            onTap()
                        }
                    }
            )
            .allowsHitTesting(!disabled)
    }
    
    private func decreaseWPM() {
        let newValue = max(RSVPEngine.minWPM, wpm - step)
        wpm = newValue
        sliderValue = Double(newValue)
    }
    
    private func increaseWPM() {
        let newValue = min(RSVPEngine.maxWPM, wpm + step)
        wpm = newValue
        sliderValue = Double(newValue)
    }
    
    private func startDecreaseTimer() {
        tickCount = 0
        decreaseTimer = Timer.scheduledTimer(withTimeInterval: holdDelay, repeats: false) { _ in
            Task { @MainActor in
                guard isDecreasePressed else { return }
                tickCount += 1
                decreaseWPM()
                continueDecreaseTimer()
            }
        }
    }
    
    private func continueDecreaseTimer() {
        let interval = currentTickInterval
        decreaseTimer?.invalidate()
        decreaseTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
            Task { @MainActor in
                guard isDecreasePressed, wpm > RSVPEngine.minWPM else { return }
                tickCount += 1
                decreaseWPM()
                continueDecreaseTimer()
            }
        }
    }
    
    private func stopDecreaseTimer() {
        decreaseTimer?.invalidate()
        decreaseTimer = nil
        tickCount = 0
    }
    
    private func startIncreaseTimer() {
        tickCount = 0
        increaseTimer = Timer.scheduledTimer(withTimeInterval: holdDelay, repeats: false) { _ in
            Task { @MainActor in
                guard isIncreasePressed else { return }
                tickCount += 1
                increaseWPM()
                continueIncreaseTimer()
            }
        }
    }
    
    private func continueIncreaseTimer() {
        let interval = currentTickInterval
        increaseTimer?.invalidate()
        increaseTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
            Task { @MainActor in
                guard isIncreasePressed, wpm < RSVPEngine.maxWPM else { return }
                tickCount += 1
                increaseWPM()
                continueIncreaseTimer()
            }
        }
    }
    
    private func stopIncreaseTimer() {
        increaseTimer?.invalidate()
        increaseTimer = nil
        tickCount = 0
    }
    
    private var currentTickInterval: TimeInterval {
        if tickCount < 5 {
            return initialTickInterval
        } else {
            let acceleration = Double(tickCount - 5) * 0.015
            return max(minimumTickInterval, initialTickInterval - acceleration)
        }
    }
}

// MARK: - Reading Mode Selector

struct ReadingModeSelector: View {
    let currentMode: ReadingMode
    let onModeChange: (ReadingMode) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(ReadingMode.allCases) { mode in
                ModeButton(
                    mode: mode,
                    isSelected: mode == currentMode,
                    action: { onModeChange(mode) }
                )
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background {
            Capsule()
                .fill(.clear)
                .glassEffect(.regular, in: Capsule())
        }
        .overlay {
            Capsule()
                .strokeBorder(.white.opacity(0.16), lineWidth: 1)
        }
    }
}

struct ModeButton: View {
    let mode: ReadingMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: mode.icon)
                    .font(AppFont.subheadline)

                if isSelected {
                    Text(mode.displayName)
                        .font(AppFont.medium(size: 15))
                }
            }
            .foregroundStyle(isSelected ? .primary : .secondary)
            .padding(.horizontal, isSelected ? 12 : 8)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    Capsule()
                        .fill(.white.opacity(0.22))
                }
            }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
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
