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
    @Namespace private var controlsNamespace
    
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
            BookmarksSheet(book: book, engine: engine)
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
            setupEngine()
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
        .focusable()
        #else
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            engine.pause()
        }
        #endif
    }

    @ViewBuilder
    private func wordDisplayArea(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // Sentence context - fixed box above RSVP word
            Group {
                if engine.showSentenceContext && !engine.currentSentenceWords.isEmpty {
                    SentenceContextView(
                        words: engine.currentSentenceWords,
                        currentWordIndex: engine.currentWordIndexInSentence
                    )
                    .frame(maxWidth: min(geometry.size.width * 0.95, 600))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .frame(height: 132) // Fixed height for ~3 lines of sentence context
            .padding(.bottom, 16)
            
            // Main RSVP word - always in the same position
            WordDisplay(word: engine.currentWord)
                .frame(maxWidth: min(geometry.size.width * 0.9, 600))
                .contentShape(Rectangle())
                .onTapGesture {
                    engine.toggle()
                }

            // Status text
            Text(statusText)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.top, 16)
        }
    }

    private var floatingControls: some View {
        VStack(spacing: 16) {
            // Reading mode selector
            ReadingModeSelector(currentMode: engine.currentMode) { mode in
                engine.applyMode(mode)
            }

            // Progress bar
            ProgressSlider(
                value: Binding(
                    get: { engine.progress },
                    set: { engine.seekToProgress($0) }
                ),
                isPlaying: engine.isPlaying
            )

            // Playback controls - streamlined 3-button layout
            HStack(spacing: 20) {
                // Back: tap = previous sentence, hold = continuous rewind
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
        .background(.regularMaterial, in: Capsule())
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
                        .fill(Color.accentColor.opacity(0.2))
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
