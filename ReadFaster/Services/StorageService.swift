import Foundation
import SwiftData

@MainActor
final class StorageService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Book Operations

    func importBook(from url: URL) async throws -> Book {
        guard let parser = DocumentParserFactory.parser(for: url) else {
            throw DocumentParserError.unsupportedFormat
        }

        let document = try await parser.parse(url: url)

        let fileType: FileType
        switch url.pathExtension.lowercased() {
        case "epub": fileType = .epub
        case "pdf": fileType = .pdf
        default: fileType = .txt
        }

        return try saveBook(
            document: document,
            fileName: url.lastPathComponent,
            fileType: fileType
        )
    }

    func importBook(fromRemoteURL remoteURL: URL) async throws -> Book {
        let importedDocument = try await RemoteDocumentImporter().importDocument(from: remoteURL)
        return try saveBook(
            document: importedDocument.parsedDocument,
            fileName: importedDocument.fileName,
            fileType: importedDocument.fileType
        )
    }

    func importBook(fromRemoteURLString rawValue: String) async throws -> Book {
        let remoteURL = try RemoteDocumentImporter.normalizedURL(from: rawValue)
        return try await importBook(fromRemoteURL: remoteURL)
    }

    func deleteBook(_ book: Book) throws {
        modelContext.delete(book)
        try modelContext.save()
    }

    func fetchAllBooks() throws -> [Book] {
        let descriptor = FetchDescriptor<Book>(
            sortBy: [SortDescriptor(\.lastOpened, order: .reverse), SortDescriptor(\.dateAdded, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    // MARK: - Progress Operations

    func updateProgress(for book: Book, wordIndex: Int, sessionTime: TimeInterval, wordsRead: Int) throws {
        if book.progress == nil {
            let progress = ReadingProgress()
            book.progress = progress
        }

        book.progress?.updateProgress(
            wordIndex: wordIndex,
            sessionTime: sessionTime,
            wordsInSession: wordsRead
        )
        book.lastOpened = Date()

        try modelContext.save()
    }

    func startReadingSession(for book: Book) throws {
        if book.progress == nil {
            let progress = ReadingProgress()
            book.progress = progress
        }

        book.progress?.startNewSession()
        book.lastOpened = Date()

        try modelContext.save()
    }

    // MARK: - Bookmark Operations

    func addBookmark(to book: Book, at wordIndex: Int, note: String? = nil, highlightedText: String? = nil) throws {
        let bookmark = Bookmark(
            wordIndex: wordIndex,
            note: note,
            highlightedText: highlightedText
        )
        bookmark.book = book
        book.bookmarks.append(bookmark)

        try modelContext.save()
    }

    func deleteBookmark(_ bookmark: Bookmark) throws {
        modelContext.delete(bookmark)
        try modelContext.save()
    }

    func fetchBookmarks(for book: Book) -> [Bookmark] {
        return book.bookmarks.sorted { $0.wordIndex < $1.wordIndex }
    }

    private func saveBook(document: ParsedDocument, fileName: String, fileType: FileType) throws -> Book {
        let book = Book(
            title: document.title,
            author: document.author,
            fileName: fileName,
            fileType: fileType,
            coverImage: document.coverImage,
            content: document.content,
            totalWords: document.wordCount,
            chapters: document.chapters
        )

        let progress = ReadingProgress()
        book.progress = progress

        modelContext.insert(book)
        try modelContext.save()

        return book
    }
}
