// swift-tools-version: 5.9
// Package.swift – enables `swift build` and `swift test` on Linux for platform-independent core logic.
// The full app (SwiftUI/SwiftData/PDFKit targets) requires macOS + Xcode; see project.yml / README.md.

import PackageDescription

let package = Package(
    name: "ReadFaster",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "ReadFasterCore", targets: ["ReadFasterCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.0"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.6.0"),
    ],
    targets: [
        .target(
            name: "ReadFasterCore",
            dependencies: [],
            path: "ReadFaster",
            exclude: [
                "App",
                "Views",
                "Resources",
                "Services/StorageService.swift",
                "Services/RSVPEngine.swift",
                "Services/DocumentParser/PDFParser.swift",
                "Services/DocumentParser/OCRParser.swift",
                "Services/DocumentParser/DocumentParser.swift",
                "Services/DocumentParser/TextParser.swift",
                "Services/DocumentParser/EPUBParser.swift",
                "Utilities/AppFont.swift",
                "Models/Book.swift",
                "Models/Bookmark.swift",
                "Models/ReadingProgress.swift",
            ]
        ),
        .testTarget(
            name: "ReadFasterCoreTests",
            dependencies: ["ReadFasterCore"],
            path: "Tests/ReadFasterCoreTests"
        ),
    ]
)
