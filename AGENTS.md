# AGENTS.md

## Cursor Cloud specific instructions

### Project overview

ReadFaster is a native Swift/SwiftUI speed-reading app for **macOS and iOS** using RSVP (Rapid Serial Visual Presentation). See `README.md` for features and `PLAN.md` for architecture.

### Platform constraint

The full app requires **macOS with Xcode 26+** and **XcodeGen** to build and run (see `project.yml`). It uses Apple-only frameworks: SwiftUI, SwiftData, PDFKit, Vision, Combine. **The full app cannot be built or run on Linux.**

### What works on Linux (Cloud Agent VM)

A `Package.swift` provides a `ReadFasterCore` library target containing the platform-independent core logic (Foundation-only files):

- `ReadFaster/Utilities/ORPCalculator.swift` — ORP calculation
- `ReadFaster/Utilities/TextProcessor.swift` — text tokenization/formatting
- `ReadFaster/Models/Chapter.swift` — chapter data model
- `ReadFaster/Models/ReadingMode.swift` — reading mode settings

**Commands (require Swift 6.0+ on PATH):**

| Task | Command |
|------|---------|
| Build core | `swift build` |
| Run tests | `swift test` |
| Lint | `swiftlint lint` |

### Swift toolchain

Swift 6.0.3 is installed at `/opt/swift/usr/bin`. The update script adds it to PATH via `~/.bashrc`. If `swift` is not found, run `export PATH="/opt/swift/usr/bin:$PATH"`.

### Linting

SwiftLint 0.57.1 is installed at `/usr/local/bin/swiftlint`. Run `swiftlint lint` from the repo root. Pre-existing violations (127 warnings, 7 serious) are in the existing codebase — do not treat these as regressions.

### Tests

Test files are in `Tests/ReadFasterCoreTests/`. These cover `ORPCalculator`, `TextProcessor`, `Chapter`, and `ReadingMode`. Run with `swift test`.

### Files that cannot compile on Linux

Any file importing SwiftUI, SwiftData, PDFKit, Vision, Combine, AppKit, or UIKit. This includes all Views, the App entry point, SwiftData models (Book, Bookmark, ReadingProgress), StorageService, RSVPEngine, PDFParser, OCRParser, and AppFont.

### Full build (macOS only)

On macOS with Xcode installed:
```bash
xcodegen generate   # regenerate .xcodeproj from project.yml
open ReadFaster.xcodeproj
# Build and run ReadFaster-iOS or ReadFaster-macOS scheme
```
