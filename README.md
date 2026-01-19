# ReadFaster

A speed reading app for macOS and iOS using RSVP (Rapid Serial Visual Presentation) with comprehension-enhancing features.

**Version 0.5**

## Features

- **RSVP Reading**: Words displayed one at a time with optimal recognition point (ORP) highlighting
- **Multi-format Support**: TXT, EPUB, and PDF files
- **Chapter Navigation**: Hierarchical TOC extraction from EPUBs and PDFs
- **Adaptive Pacing**: Automatically slows down for complex words and sentence structures
- **Reading Modes**: Skim (600 WPM), Normal (350 WPM), Study (250 WPM)
- **Sentence Context**: Horizontal scrolling display of the current sentence
- **Speed Ramp-Up**: Gradual acceleration after pause/rewind for smooth re-entry
- **Hold-to-Repeat Controls**: Continuous navigation and WPM adjustment when held

## Algorithms & Complexity

### Document Parsing

| Algorithm | Purpose | Time Complexity | Space Complexity |
|-----------|---------|-----------------|------------------|
| Text Tokenization | Split content into words | O(n) | O(n) |
| EPUB Extraction | Unzip and parse XML/HTML | O(n) | O(n) |
| PDF Text Extraction | Extract text via PDFKit | O(p) | O(n) |
| TOC/Outline Parsing | Build chapter hierarchy | O(c) | O(c) |

Where: `n` = characters in document, `p` = pages, `c` = chapters/sections

### Sentence Detection

```
detectSentenceBoundaries() → O(n)
```

Single pass through all words, checking for sentence-ending punctuation (`.`, `?`, `!`) while handling edge cases like quotes and parentheses.

```swift
for i in 0..<words.count - 1 {
    if isSentenceEnding(words[i]) {
        sentenceStartIndices.insert(i + 1)  // O(1) Set insertion
        sentenceStartList.append(i + 1)     // O(1) amortized
    }
}
```

**Data Structures**:
- `Set<Int>` for O(1) membership checks during complexity analysis
- `[Int]` for O(1) indexed access during navigation

### Dialogue State Pre-computation

```
computeDialogueState() → O(n)
```

Tracks quote parity in a single pass to determine if each word is inside dialogue:

```swift
var quoteCount = 0
for word in words {
    quoteCount += word.filter { isQuoteChar($0) }.count
    isWordInDialogue.append(quoteCount % 2 == 1)  // O(1)
}
```

**Previous implementation was O(n²)** — for each word, it counted all quotes in preceding words. Fixed by pre-computing in linear time.

### Word Complexity Analysis

```
computeWordComplexity() → O(n)
```

Assigns a complexity score (0.0–1.0) to each word based on:

| Factor | Weight | Lookup Complexity |
|--------|--------|-------------------|
| Word length (>6, >8, >12 chars) | 0.1–0.4 | O(1) |
| Sentence start | 0.2 | O(1) via Set |
| Inside dialogue | 0.1 | O(1) via pre-computed array |
| Complex punctuation nearby | 0.15 | O(1) — checks ±1 neighbors |
| Proper noun (capitalized mid-sentence) | 0.1 | O(1) |

Total per word: O(1) → Total: O(n)

### Sentence Navigation

```
currentSentenceIndex → O(s)
previousSentence() → O(s)
nextSentence() → O(1)
```

Where `s` = number of sentences. Linear scan through sentence boundaries to find current position. Could be optimized to O(log s) with binary search if needed.

### Interval Calculation (Per Word)

```
intervalForCurrentWord() → O(1)
```

Computes display duration with stacked multipliers:

```
baseInterval = 60 / WPM

if rampUpActive:
    interval *= rampUpMultiplier[wordsRemaining]  // 2.0x → 1.05x

if adaptivePacing:
    interval *= (1 + complexity * intensity)      // up to 2x

if pauseOnPunctuation:
    interval *= punctuationMultiplier             // 1.5x–2.0x

return min(interval, baseInterval * 4)            // cap at 4x
```

### Chapter Lookup

```
Book.chapters → O(c) JSON decode (cached after first access)
Book.hasChapters → O(1) nil check on data
```

Chapters stored as JSON blob in SwiftData with `@Attribute(.externalStorage)` for large hierarchies.

### EPUB TOC Parsing

```
parseTableOfContents() → O(c × d)
```

Where `c` = chapters, `d` = average DOM depth. Parses NCX (EPUB 2) or Nav (EPUB 3) documents using SwiftSoup HTML parser.

### PDF Outline Extraction

```
extractOutlineItems() → O(c)
```

Recursive traversal of `PDFOutline` tree structure via PDFKit.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                      RSVPView                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐  │
│  │ WordDisplay │  │ SentenceCtx │  │ PlaybackControls│  │
│  └─────────────┘  └─────────────┘  └─────────────────┘  │
└───────────────────────────┬─────────────────────────────┘
                            │
                    ┌───────▼───────┐
                    │  RSVPEngine   │
                    │ (ObservableObj)│
                    └───────┬───────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
┌───────▼───────┐  ┌────────▼────────┐  ┌───────▼───────┐
│ SentenceTrack │  │ ComplexityCalc  │  │  RampUpState  │
│ Set + Array   │  │ Pre-computed[]  │  │  Counter      │
└───────────────┘  └─────────────────┘  └───────────────┘
```

## Requirements

- macOS 15.0+ / iOS 18.0+
- Xcode 16.0+
- Swift 6.0+

## Building

```bash
# Generate Xcode project
xcodegen generate

# Open in Xcode
open ReadFaster.xcodeproj
```

## Dependencies

- **ZIPFoundation** — EPUB extraction
- **SwiftSoup** — HTML/XML parsing for EPUB content

## License

MIT
