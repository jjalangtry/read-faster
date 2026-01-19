import Foundation
import Combine

@MainActor
final class RSVPEngine: ObservableObject {
    // MARK: - Published State
    @Published private(set) var currentWord: String = ""
    @Published private(set) var currentIndex: Int = 0
    @Published private(set) var isPlaying: Bool = false
    @Published var wordsPerMinute: Int = 300 {
        didSet {
            let clamped = min(max(wordsPerMinute, Self.minWPM), Self.maxWPM)
            if wordsPerMinute != clamped {
                wordsPerMinute = clamped
            }
            // Don't restart timer on every change - it will pick up new speed on next word
        }
    }

    // MARK: - Configuration
    static let minWPM = 200
    static let maxWPM = 1000
    @Published var pauseOnPunctuation: Bool = true
    @Published var showSentenceContext: Bool = true
    @Published var adaptivePacingEnabled: Bool = true
    @Published var adaptivePacingIntensity: Double = 1.0 // 0.0 = off, 1.0 = normal, 2.0 = aggressive
    @Published private(set) var currentMode: ReadingMode = .normal

    // MARK: - Private State
    private var words: [String] = []
    private var timer: Timer?
    private var sessionStartTime: Date?
    private var wordsReadInSession: Int = 0
    
    // MARK: - Ramp-Up State
    /// Number of words remaining in the ramp-up period (starts slow, accelerates to target speed)
    private var rampUpWordsRemaining: Int = 0
    /// Total words in the ramp-up period
    private let rampUpLength: Int = 5

    // MARK: - Sentence Tracking
    /// Indices where each sentence starts (first word of each sentence) - using Set for O(1) lookups
    private var sentenceStartIndices: Set<Int> = []
    /// Ordered list of sentence start indices for navigation
    private var sentenceStartList: [Int] = []
    /// Pre-computed dialogue state for each word (true if inside quotes)
    private var isWordInDialogue: [Bool] = []
    /// Complexity score for each word (0.0 - 1.0), used for adaptive pacing
    private var wordComplexityScores: [Double] = []

    // MARK: - Callbacks
    var onProgressUpdate: ((Int, TimeInterval, Int) -> Void)?

    // MARK: - Computed Properties
    var totalWords: Int { words.count }

    var progress: Double {
        guard totalWords > 0 else { return 0 }
        return Double(currentIndex) / Double(totalWords)
    }

    var hasContent: Bool { !words.isEmpty }
    var isAtEnd: Bool { currentIndex >= totalWords }
    var isAtStart: Bool { currentIndex == 0 }

    private var baseInterval: TimeInterval {
        60.0 / Double(wordsPerMinute)
    }

    // MARK: - Sentence Context Properties

    /// The index of the current sentence (0-based)
    var currentSentenceIndex: Int {
        guard !sentenceStartList.isEmpty else { return 0 }
        // Find the last sentence start that is <= currentIndex
        var sentenceIdx = 0
        for (idx, startIndex) in sentenceStartList.enumerated() {
            if startIndex <= currentIndex {
                sentenceIdx = idx
            } else {
                break
            }
        }
        return sentenceIdx
    }

    /// The start index of the current sentence
    var currentSentenceStartIndex: Int {
        guard !sentenceStartList.isEmpty else { return 0 }
        return sentenceStartList[currentSentenceIndex]
    }

    /// The end index of the current sentence (exclusive)
    var currentSentenceEndIndex: Int {
        guard !sentenceStartList.isEmpty else { return totalWords }
        let sentenceIdx = currentSentenceIndex
        if sentenceIdx + 1 < sentenceStartList.count {
            return sentenceStartList[sentenceIdx + 1]
        }
        return totalWords
    }

    /// Words in the current sentence
    var currentSentenceWords: [String] {
        guard hasContent else { return [] }
        let start = currentSentenceStartIndex
        let end = currentSentenceEndIndex
        return Array(words[start..<end])
    }

    /// Position of current word within the current sentence (0-based)
    var currentWordIndexInSentence: Int {
        currentIndex - currentSentenceStartIndex
    }

    /// Total number of sentences
    var totalSentences: Int {
        sentenceStartList.count
    }

    // MARK: - Public Methods
    func load(content: String) {
        words = content.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        detectSentenceBoundaries()
        computeDialogueState()
        computeWordComplexity()
        currentIndex = 0
        currentWord = words.first ?? ""
        isPlaying = false
    }

    func load(words: [String]) {
        self.words = words
        detectSentenceBoundaries()
        computeDialogueState()
        computeWordComplexity()
        currentIndex = 0
        currentWord = words.first ?? ""
        isPlaying = false
    }

    // MARK: - Reading Mode

    /// Applies a reading mode, configuring all related settings
    func applyMode(_ mode: ReadingMode) {
        currentMode = mode
        let settings = mode.settings

        wordsPerMinute = settings.baseWPM
        showSentenceContext = settings.showSentenceContext
        adaptivePacingEnabled = settings.adaptivePacingEnabled
        adaptivePacingIntensity = settings.adaptivePacingIntensity
        pauseOnPunctuation = settings.pauseOnPunctuation
    }

    // MARK: - Sentence Detection

    private func detectSentenceBoundaries() {
        sentenceStartIndices = []
        sentenceStartList = []
        guard !words.isEmpty else { return }

        // First word is always a sentence start
        sentenceStartIndices.insert(0)
        sentenceStartList.append(0)

        for i in 0..<words.count - 1 {
            let word = words[i]
            // Check if this word ends a sentence
            if isSentenceEnding(word) {
                // Next word starts a new sentence
                sentenceStartIndices.insert(i + 1)
                sentenceStartList.append(i + 1)
            }
        }
    }
    
    /// Pre-compute dialogue state for all words in O(N) time
    private func computeDialogueState() {
        isWordInDialogue = []
        guard !words.isEmpty else { return }
        
        var quoteCount = 0
        for word in words {
            // Count quote marks in this word
            let quotes = word.filter { $0 == "\"" || $0 == "\u{201C}" || $0 == "\u{201D}" }.count
            quoteCount += quotes
            // Odd count means we're inside quotes
            isWordInDialogue.append(quoteCount % 2 == 1)
        }
    }

    private func isSentenceEnding(_ word: String) -> Bool {
        // Remove any trailing quotes or parentheses to check the actual punctuation
        // Using Unicode escapes for curly quotes: " " ' ' » «
        let quoteChars = "\"\'\u{201C}\u{201D}\u{2018}\u{2019}\u{00BB}\u{00AB})]}"
        let trimmed = word.trimmingCharacters(in: CharacterSet(charactersIn: quoteChars))
        return trimmed.hasSuffix(".") || trimmed.hasSuffix("?") || trimmed.hasSuffix("!")
    }

    // MARK: - Complexity Analysis

    private func computeWordComplexity() {
        wordComplexityScores = words.enumerated().map { index, word in
            computeComplexityScore(for: word, at: index)
        }
    }

    private func computeComplexityScore(for word: String, at index: Int) -> Double {
        var score = 0.0

        // Factor 1: Word length (longer words are more complex)
        let length = word.count
        if length > 12 {
            score += 0.4
        } else if length > 8 {
            score += 0.25
        } else if length > 6 {
            score += 0.1
        }

        // Factor 2: Sentence start (new context requires more processing)
        if sentenceStartIndices.contains(index) {
            score += 0.2
        }

        // Factor 3: Dialogue (inside quotes requires tracking speaker)
        if isInsideDialogue(at: index) {
            score += 0.1
        }

        // Factor 4: Complex punctuation in surrounding context
        if hasComplexPunctuation(at: index) {
            score += 0.15
        }

        // Factor 5: Capitalized word mid-sentence (proper noun, requires attention)
        if index > 0 && !sentenceStartIndices.contains(index) {
            let firstChar = word.first
            if firstChar?.isUppercase == true {
                score += 0.1
            }
        }

        // Cap at 1.0
        return min(score, 1.0)
    }

    private func isInsideDialogue(at index: Int) -> Bool {
        // Use pre-computed dialogue state for O(1) lookup
        guard index < isWordInDialogue.count else { return false }
        return isWordInDialogue[index]
    }

    private func hasComplexPunctuation(at index: Int) -> Bool {
        // Check current word and neighbors for complex punctuation
        let range = max(0, index - 1)...min(words.count - 1, index + 1)
        for i in range {
            let word = words[i]
            if word.contains(";") || word.contains(":") || word.contains("—") || word.contains("–") {
                return true
            }
            // Multiple commas in close proximity suggests complex clause structure
            if word.contains(",") && i != index {
                return true
            }
        }
        return false
    }

    func play() {
        guard hasContent, !isAtEnd else { return }
        isPlaying = true
        sessionStartTime = Date()
        wordsReadInSession = 0
        // Start ramp-up: first few words are slower to ease back in
        rampUpWordsRemaining = rampUpLength
        scheduleNextWord()
    }

    func pause() {
        isPlaying = false
        timer?.invalidate()
        timer = nil
        saveProgress()
    }

    func toggle() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func seek(to index: Int) {
        let clampedIndex = min(max(index, 0), totalWords - 1)
        currentIndex = clampedIndex
        currentWord = words[safe: clampedIndex] ?? ""

        if isPlaying {
            timer?.invalidate()
            scheduleNextWord()
        }
    }

    func seekToProgress(_ progress: Double) {
        let index = Int(progress * Double(totalWords))
        seek(to: index)
    }

    func skipForward(words count: Int = 10) {
        seek(to: currentIndex + count)
    }

    func skipBackward(words count: Int = 10) {
        seek(to: currentIndex - count)
    }

    func nextSentence() {
        guard !sentenceStartList.isEmpty else { return }

        let currentSentence = currentSentenceIndex
        if currentSentence + 1 < sentenceStartList.count {
            seek(to: sentenceStartList[currentSentence + 1])
        } else {
            // Already at last sentence, go to end
            seek(to: totalWords - 1)
        }
    }

    func previousSentence() {
        guard !sentenceStartList.isEmpty, currentIndex > 0 else { return }

        let currentSentence = currentSentenceIndex
        let currentSentenceStart = sentenceStartList[currentSentence]

        // If we're at the start of a sentence, go to the previous sentence
        // Otherwise, go to the start of the current sentence
        if currentIndex == currentSentenceStart && currentSentence > 0 {
            seek(to: sentenceStartList[currentSentence - 1])
        } else {
            seek(to: currentSentenceStart)
        }
    }

    /// Replays the current sentence from the beginning
    func replayCurrentSentence() {
        seek(to: currentSentenceStartIndex)
        // Trigger ramp-up for smooth re-entry
        rampUpWordsRemaining = rampUpLength
        if !isPlaying {
            play()
        }
    }

    /// Goes to the previous sentence and starts playing
    func replayPreviousSentence() {
        previousSentence()
        // Trigger ramp-up for smooth re-entry
        rampUpWordsRemaining = rampUpLength
        if !isPlaying {
            play()
        }
    }

    func restart() {
        seek(to: 0)
    }

    // MARK: - Private Methods
    private func scheduleNextWord() {
        guard isPlaying, currentIndex < totalWords else {
            if isAtEnd {
                pause()
            }
            return
        }

        let interval = intervalForCurrentWord()

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.advanceToNextWord()
            }
        }
    }

    private func advanceToNextWord() {
        currentIndex += 1
        wordsReadInSession += 1

        if currentIndex < totalWords {
            currentWord = words[currentIndex]
            scheduleNextWord()
        } else {
            currentWord = ""
            pause()
        }
    }

    private func intervalForCurrentWord() -> TimeInterval {
        var interval = baseInterval
        
        // Apply ramp-up slowdown after resume/rewind
        // This eases the reader back into the flow
        if rampUpWordsRemaining > 0 {
            let rampUpMultiplier = rampUpMultiplierForCurrentPosition()
            interval *= rampUpMultiplier
            rampUpWordsRemaining -= 1
        }

        // Apply adaptive pacing based on complexity
        if adaptivePacingEnabled && currentIndex < wordComplexityScores.count {
            let complexity = wordComplexityScores[currentIndex]
            // Scale: complexity 0.0 = no change, complexity 1.0 = up to 2x slower based on intensity
            let slowdownFactor = 1.0 + (complexity * adaptivePacingIntensity)
            interval *= slowdownFactor
        }

        // Apply punctuation pauses (these stack with adaptive pacing)
        if pauseOnPunctuation {
            let word = currentWord
            // Using Unicode escapes for curly quotes
            let quoteChars = "\"\'\u{201C}\u{201D}\u{2018}\u{2019}\u{00BB}\u{00AB})]}"
            let trimmedWord = word.trimmingCharacters(in: CharacterSet(charactersIn: quoteChars))

            // Longer pause at sentence endings
            if trimmedWord.hasSuffix(".") || trimmedWord.hasSuffix("?") || trimmedWord.hasSuffix("!") {
                interval *= 2.0
            }
            // Medium pause at clause breaks
            else if trimmedWord.hasSuffix(",") || trimmedWord.hasSuffix(";") || trimmedWord.hasSuffix(":") {
                interval *= 1.5
            }
        }

        // Cap maximum interval to prevent jarring pauses (max 4x base)
        return min(interval, baseInterval * 4.0)
    }
    
    /// Returns the slowdown multiplier for ramp-up based on position in the ramp
    /// Word 1 (5 remaining): 2.0x slower
    /// Word 2 (4 remaining): 1.6x slower
    /// Word 3 (3 remaining): 1.35x slower
    /// Word 4 (2 remaining): 1.15x slower
    /// Word 5 (1 remaining): 1.05x slower
    private func rampUpMultiplierForCurrentPosition() -> Double {
        switch rampUpWordsRemaining {
        case 5: return 2.0
        case 4: return 1.6
        case 3: return 1.35
        case 2: return 1.15
        case 1: return 1.05
        default: return 1.0
        }
    }

    private func saveProgress() {
        guard let startTime = sessionStartTime else { return }
        let sessionDuration = Date().timeIntervalSince(startTime)
        onProgressUpdate?(currentIndex, sessionDuration, wordsReadInSession)
        sessionStartTime = nil
        wordsReadInSession = 0
    }
}

// MARK: - Array Extension
private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
