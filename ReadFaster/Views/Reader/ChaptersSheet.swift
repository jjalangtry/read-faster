import SwiftUI

struct ChaptersSheet: View {
    @Environment(\.dismiss) private var dismiss

    let book: Book
    let engine: RSVPEngine

    var body: some View {
        NavigationStack {
            Group {
                if book.chapters.isEmpty {
                    ContentUnavailableView {
                        Label("No Chapters", systemImage: "list.bullet.indent")
                    } description: {
                        Text("This book doesn't have chapter information available.")
                    }
                } else {
                    List {
                        ChapterListContent(
                            chapters: book.chapters,
                            currentWordIndex: engine.currentIndex,
                            totalWords: engine.totalWords,
                            onSelect: { chapter in
                                engine.seek(to: chapter.startWordIndex)
                                dismiss()
                            }
                        )
                    }
                    #if os(iOS)
                    .listStyle(.insetGrouped)
                    #endif
                }
            }
            .navigationTitle("Chapters")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 400)
        #endif
    }
}

/// Recursive chapter list content
struct ChapterListContent: View {
    let chapters: [Chapter]
    let currentWordIndex: Int
    let totalWords: Int
    let onSelect: (Chapter) -> Void
    var indentLevel: Int = 0

    var body: some View {
        ForEach(chapters) { chapter in
            ChapterRow(
                chapter: chapter,
                currentWordIndex: currentWordIndex,
                totalWords: totalWords,
                indentLevel: indentLevel,
                onSelect: onSelect
            )

            if chapter.hasChildren {
                ChapterListContent(
                    chapters: chapter.children,
                    currentWordIndex: currentWordIndex,
                    totalWords: totalWords,
                    onSelect: onSelect,
                    indentLevel: indentLevel + 1
                )
            }
        }
    }
}

struct ChapterRow: View {
    let chapter: Chapter
    let currentWordIndex: Int
    let totalWords: Int
    let indentLevel: Int
    let onSelect: (Chapter) -> Void

    private var isCurrentChapter: Bool {
        // Check if this is the current chapter (current word is >= this chapter's start
        // and < next chapter's start or end of book)
        currentWordIndex >= chapter.startWordIndex
    }

    private var progressPercent: Int {
        guard totalWords > 0 else { return 0 }
        return Int(Double(chapter.startWordIndex) / Double(totalWords) * 100)
    }

    var body: some View {
        Button {
            onSelect(chapter)
        } label: {
            HStack(spacing: 12) {
                // Indent for hierarchy
                if indentLevel > 0 {
                    Spacer()
                        .frame(width: CGFloat(indentLevel) * 20)
                }

                // Current chapter indicator
                Circle()
                    .fill(isCurrentChapter ? Color.accentColor : Color.clear)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(chapter.title)
                        .font(indentLevel == 0 ? .headline : .subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Text("\(progressPercent)% into book")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(isCurrentChapter ? Color.accentColor.opacity(0.1) : nil)
    }
}

// MARK: - Preview

#Preview("With Chapters") {
    let book = Book(
        title: "Sample Book",
        fileName: "sample.epub",
        fileType: .epub,
        content: String(repeating: "word ", count: 10000),
        totalWords: 10000,
        chapters: [
            Chapter(title: "Introduction", startWordIndex: 0, children: []),
            Chapter(title: "Part One: The Beginning", startWordIndex: 500, children: [
                Chapter(title: "Chapter 1: Origins", startWordIndex: 500),
                Chapter(title: "Chapter 2: Discovery", startWordIndex: 1200),
                Chapter(title: "Chapter 3: Growth", startWordIndex: 2000)
            ]),
            Chapter(title: "Part Two: The Journey", startWordIndex: 3500, children: [
                Chapter(title: "Chapter 4: The Road", startWordIndex: 3500),
                Chapter(title: "Chapter 5: Challenges", startWordIndex: 4500),
                Chapter(title: "Chapter 6: Triumph", startWordIndex: 5500)
            ]),
            Chapter(title: "Conclusion", startWordIndex: 8000, children: []),
            Chapter(title: "Epilogue", startWordIndex: 9500, children: [])
        ]
    )

    let engine = RSVPEngine()
    engine.load(content: book.content)
    engine.seek(to: 1500)

    return ChaptersSheet(book: book, engine: engine)
        .modelContainer(for: [Book.self], inMemory: true)
}

#Preview("No Chapters") {
    let book = Book(
        title: "Plain Text Book",
        fileName: "sample.txt",
        fileType: .txt,
        content: "Sample content",
        totalWords: 100
    )

    return ChaptersSheet(book: book, engine: RSVPEngine())
        .modelContainer(for: [Book.self], inMemory: true)
}
