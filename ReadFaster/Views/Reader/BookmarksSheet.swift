import SwiftUI
import SwiftData

struct BookmarksSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let book: Book
    let engine: RSVPEngine

    var body: some View {
        NavigationStack {
            Group {
                if book.bookmarks.isEmpty {
                    ContentUnavailableView {
                        Label("No Bookmarks", systemImage: "bookmark")
                    } description: {
                        Text("Tap the bookmark button while reading to save your position.")
                    }
                } else {
                    List {
                        ForEach(book.bookmarks.sorted { $0.wordIndex < $1.wordIndex }) { bookmark in
                            BookmarkRow(bookmark: bookmark)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    engine.seek(to: bookmark.wordIndex)
                                    dismiss()
                                }
                        }
                        .onDelete(perform: deleteBookmarks)
                    }
                }
            }
            .navigationTitle("Bookmarks")
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
        .frame(minWidth: 400, minHeight: 300)
        #endif
    }

    private func deleteBookmarks(at offsets: IndexSet) {
        let sortedBookmarks = book.bookmarks.sorted { $0.wordIndex < $1.wordIndex }
        for index in offsets {
            let bookmark = sortedBookmarks[index]
            modelContext.delete(bookmark)
        }
        try? modelContext.save()
    }
}

struct BookmarkRow: View {
    let bookmark: Bookmark

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "bookmark.fill")
                    .foregroundStyle(Color.accentColor)

                Text("Word \(bookmark.wordIndex + 1)")
                    .font(.headline)

                Spacer()

                Text(bookmark.dateCreated, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let text = bookmark.highlightedText {
                Text("...\(text)...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let note = bookmark.note, !note.isEmpty {
                Text(note)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let book = Book(
        title: "Sample",
        fileName: "sample.txt",
        fileType: .txt,
        content: "Sample content",
        totalWords: 100
    )

    return BookmarksSheet(book: book, engine: RSVPEngine())
        .modelContainer(for: [Book.self, Bookmark.self], inMemory: true)
}
