# Read Faster - RSVP Speed Reading App

## Overview
A native SwiftUI app for macOS and iOS that enables Rapid Serial Visual Presentation (RSVP) reading with configurable speed and a focal point system.

## Core Concept
Words appear one at a time in a fixed position. One letter (the Optimal Recognition Point - typically ~30% into the word) is highlighted in red to anchor the eye, eliminating saccadic movement and dramatically increasing reading speed.

---

## Architecture

### Tech Stack
- **SwiftUI** - Shared UI across macOS and iOS
- **Swift** - Core logic
- **PDFKit** - PDF text extraction
- **Vision** - OCR for scanned PDFs
- **ZIPFoundation** - EPUB extraction (EPUBs are ZIP archives)
- **SwiftSoup** - HTML parsing for EPUB content
- **CloudKit** - iCloud sync for library and progress
- **SwiftData** - Local persistence

### Project Structure
```
ReadFaster/
├── App/
│   ├── ReadFasterApp.swift
│   └── ContentView.swift
├── Models/
│   ├── Book.swift              # Book metadata model
│   ├── ReadingProgress.swift   # Position, stats tracking
│   └── Bookmark.swift          # Saved positions/highlights
├── Services/
│   ├── DocumentParser/
│   │   ├── DocumentParser.swift      # Protocol
│   │   ├── TextParser.swift          # Plain text
│   │   ├── EPUBParser.swift          # EPUB extraction
│   │   ├── PDFParser.swift           # Digital PDF
│   │   └── OCRParser.swift           # Scanned PDF via Vision
│   ├── RSVPEngine.swift        # Core RSVP timing/display logic
│   ├── CloudSyncService.swift  # iCloud sync
│   └── StorageService.swift    # SwiftData management
├── Views/
│   ├── Library/
│   │   ├── LibraryView.swift   # Book collection
│   │   └── BookCard.swift      # Individual book display
│   ├── Reader/
│   │   ├── RSVPView.swift      # Main RSVP display
│   │   ├── WordDisplay.swift   # Single word with ORP highlight
│   │   └── ControlsView.swift  # Play/pause, speed, progress
│   ├── Import/
│   │   └── ImportView.swift    # File picker, drag-drop
│   └── Settings/
│       └── SettingsView.swift  # WPM, theme, etc.
├── Utilities/
│   ├── ORPCalculator.swift     # Optimal Recognition Point logic
│   └── TextProcessor.swift     # Sentence/word tokenization
└── Resources/
    └── Assets.xcassets
```

---

## Features

### Phase 1: Core RSVP Reader
- [ ] **Document Import**
  - File picker supporting .txt, .epub, .pdf
  - Drag-and-drop support (macOS)
  - Share sheet integration (iOS)

- [ ] **Document Parsing**
  - Plain text extraction
  - EPUB parsing (unzip → parse HTML → extract text)
  - PDF text extraction via PDFKit
  - OCR fallback for scanned PDFs via Vision framework

- [ ] **RSVP Display**
  - Single word display with fixed position
  - ORP (Optimal Recognition Point) calculation
  - Red letter highlight at ORP
  - Configurable WPM: 200-1000 (slider)
  - Play/pause controls
  - Tap to pause (iOS), spacebar (macOS)

- [ ] **Basic Navigation**
  - Progress bar showing position in book
  - Scrub to position
  - Previous/next sentence jump

### Phase 2: Library & Persistence
- [ ] **Library View**
  - Grid/list of imported books
  - Cover extraction from EPUB metadata
  - Sort by title, author, last read, progress

- [ ] **Progress Tracking**
  - Auto-save position on pause/close
  - Resume from last position
  - Reading statistics (WPM average, time spent, words read)

- [ ] **Bookmarks & Highlights**
  - Tap to bookmark current position
  - Long-press to highlight passage
  - Bookmark list view with jump-to

### Phase 3: Sync & Polish
- [ ] **iCloud Sync**
  - Sync library metadata across devices
  - Sync reading progress
  - Sync bookmarks/highlights
  - Optional: sync actual book files

- [ ] **Settings**
  - Default WPM
  - Theme (light/dark/system)
  - Font size for word display
  - ORP position adjustment
  - Pause on punctuation (longer pause at periods)

- [ ] **Platform-Specific Polish**
  - macOS: keyboard shortcuts, menu bar
  - iOS: haptic feedback, gesture controls

---

## Technical Details

### Optimal Recognition Point (ORP) Algorithm
The ORP is where the eye naturally fixates. Research suggests it's roughly 30% into a word, adjusted for word length:

```swift
func calculateORP(word: String) -> Int {
    let length = word.count
    switch length {
    case 1: return 0
    case 2...5: return 1
    case 6...9: return 2
    case 10...13: return 3
    default: return 4
    }
}
```

### WPM Timing
```swift
let baseInterval = 60.0 / Double(wpm)  // seconds per word

// Adjust for punctuation
func intervalForWord(_ word: String) -> TimeInterval {
    if word.hasSuffix(".") || word.hasSuffix("?") || word.hasSuffix("!") {
        return baseInterval * 2.0  // Pause longer at sentence ends
    } else if word.hasSuffix(",") || word.hasSuffix(";") || word.hasSuffix(":") {
        return baseInterval * 1.5  // Slight pause at clause breaks
    }
    return baseInterval
}
```

### EPUB Parsing Strategy
```swift
// 1. EPUBs are ZIP files
let archive = Archive(url: epubURL, accessMode: .read)

// 2. Parse container.xml to find content.opf
let containerPath = "META-INF/container.xml"

// 3. Parse content.opf to get spine (reading order)
// 4. Extract and parse each HTML file in spine order
// 5. Use SwiftSoup to extract text from HTML
```

### OCR Pipeline
```swift
// Use Vision framework for scanned PDFs
func performOCR(on image: CGImage) async throws -> String {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.recognitionLanguages = ["en-US"]

    let handler = VNImageRequestHandler(cgImage: image)
    try handler.perform([request])

    return request.results?
        .compactMap { $0.topCandidates(1).first?.string }
        .joined(separator: " ") ?? ""
}
```

---

## Data Models

### Book
```swift
@Model
class Book {
    var id: UUID
    var title: String
    var author: String?
    var filePath: String
    var fileType: FileType  // .txt, .epub, .pdf
    var coverImage: Data?
    var dateAdded: Date
    var lastOpened: Date?
    var totalWords: Int

    @Relationship var progress: ReadingProgress?
    @Relationship var bookmarks: [Bookmark]
}
```

### ReadingProgress
```swift
@Model
class ReadingProgress {
    var currentWordIndex: Int
    var percentComplete: Double
    var totalReadingTime: TimeInterval
    var averageWPM: Int
    var lastUpdated: Date
}
```

### Bookmark
```swift
@Model
class Bookmark {
    var id: UUID
    var wordIndex: Int
    var note: String?
    var highlightedText: String?
    var dateCreated: Date
}
```

---

## UI Mockup (ASCII)

### RSVP Reader View
```
┌─────────────────────────────────────┐
│                                     │
│                                     │
│                                     │
│          ───────────────            │
│            recog|n|ition            │  ← Red 'n' at ORP
│          ───────────────            │
│                                     │
│                                     │
│                                     │
├─────────────────────────────────────┤
│  ◀◀   ▶/⏸   ▶▶      450 WPM   ═══  │
│  ━━━━━━━━━━●━━━━━━━━━━━━━━━━  62%  │
└─────────────────────────────────────┘
```

### Library View
```
┌─────────────────────────────────────┐
│  📚 Library                    [+]  │
├─────────────────────────────────────┤
│  ┌─────┐  ┌─────┐  ┌─────┐        │
│  │     │  │     │  │     │        │
│  │ 📖  │  │ 📖  │  │ 📖  │        │
│  │     │  │     │  │     │        │
│  └─────┘  └─────┘  └─────┘        │
│  Dune     1984     Project        │
│  ━━━━     ━━━━━━   ━               │
│  45%      100%     12%             │
└─────────────────────────────────────┘
```

---

## Dependencies

```swift
// Package.swift dependencies
.package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.0"),
.package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.6.0"),
```

---

## Xcode Cloud / App Store Deployment

### App Group prerequisite (Share Extension)

Xcode Cloud export will fail if the App Group `group.com.jakoblangtry.readfaster` is not enabled in Apple Developer for both App IDs.

**In Apple Developer (developer.apple.com):**

1. **Main app** – App ID `com.jakoblangtry.readfaster`:
   - Enable **App Groups**
   - Add group: `group.com.jakoblangtry.readfaster`

2. **Share extension** – App ID `com.jakoblangtry.readfaster.share`:
   - Create this App ID if it does not exist (App type: App)
   - Enable **App Groups**
   - Add the same group: `group.com.jakoblangtry.readfaster`

### After changing project.yml

The Share Extension target is defined in `project.yml`. Regenerate the Xcode project before shipping:

```bash
xcodegen generate
```

Then commit the updated `.xcodeproj` (including `project.pbxproj`, workspace data, and schemes).

### Pre-export checklist

1. Enable App Groups for both App IDs in Apple Developer (see above)
2. Run `xcodegen generate` and commit the regenerated project
3. Open the project in Xcode and confirm both targets have correct signing and capabilities
4. Push to `main` and re-run Xcode Cloud

---

## Open Questions

1. **Chunk mode?** - Some RSVP readers show 2-3 words at a time for very high speeds. Worth adding as an option?

2. **Spritz patents** - The original Spritz company held patents on some RSVP techniques. The ORP concept is based on research, but the specific red-letter implementation should be reviewed. (Patents may have expired or be limited in scope.)

3. **Accessibility** - VoiceOver compatibility for the library, but RSVP itself is inherently visual. Consider audio speed-reading alternative?

4. **File storage** - Store imported files in app sandbox, or reference original location? Sandbox is safer for iCloud sync.

---

## MVP Scope

For v0.1, focus on:
1. Import .txt and .epub files
2. Basic RSVP display with ORP
3. WPM slider (200-1000)
4. Play/pause
5. Progress bar with position memory

Skip for MVP:
- PDF support (add in v0.2)
- OCR (add in v0.3)
- iCloud sync (add in v0.4)
- Bookmarks/highlights (add in v0.2)
