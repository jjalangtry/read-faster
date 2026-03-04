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

### Versioning

The app version follows **semver** (`major.minor.patch`). The source of truth is `MARKETING_VERSION` in `project.yml`.

Xcode Cloud auto-bumps the version on every build using `ci_scripts/ci_post_clone.sh`. The bump level is determined by the **commit subject line** (first line only, not the body) of the push to `main`:

| Tag in commit message | Bump | Example |
|---|---|---|
| `[major]` | major | 0.11.3 → 1.0.0 |
| `[minor]` | minor | 0.11.3 → 0.12.0 |
| _(anything else)_ | patch | 0.11.3 → 0.11.4 |

**Do not manually edit version numbers** in `project.yml` or `project.pbxproj` — the CI script handles it. The `CURRENT_PROJECT_VERSION` (build number) is set to the Xcode Cloud `CI_BUILD_NUMBER` automatically.

When writing commit messages, include `[minor]` or `[major]` in the **subject line** (first line) if the change warrants it. Never put these tags in the commit body — only the subject is checked. Most commits should bump patch (no tag needed).

**Important:** The script reads the base version from `project.yml`. After any push, you **must update `project.yml` and `project.pbxproj`** to match the new version so subsequent builds start from the correct base. Always include the version update in the same commit.

### Full build (macOS only)

On macOS with Xcode installed:
```bash
xcodegen generate   # regenerate .xcodeproj from project.yml
open ReadFaster.xcodeproj
# Build and run ReadFaster-iOS or ReadFaster-macOS scheme
```
