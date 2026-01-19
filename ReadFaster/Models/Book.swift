import Foundation
import SwiftData

enum FileType: String, Codable {
    case txt
    case epub
    case pdf
}

@Model
final class Book {
    var id: UUID
    var title: String
    var author: String?
    var fileName: String
    var fileType: FileType
    @Attribute(.externalStorage) var coverImage: Data?
    var dateAdded: Date
    var lastOpened: Date?
    var totalWords: Int
    @Attribute(.externalStorage) var content: String
    @Attribute(.externalStorage) var chaptersData: Data?

    @Relationship(deleteRule: .cascade, inverse: \ReadingProgress.book)
    var progress: ReadingProgress?

    @Relationship(deleteRule: .cascade, inverse: \Bookmark.book)
    var bookmarks: [Bookmark] = []

    init(
        id: UUID = UUID(),
        title: String,
        author: String? = nil,
        fileName: String,
        fileType: FileType,
        coverImage: Data? = nil,
        content: String,
        totalWords: Int,
        chapters: [Chapter] = []
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.fileName = fileName
        self.fileType = fileType
        self.coverImage = coverImage
        self.dateAdded = Date()
        self.lastOpened = nil
        self.totalWords = totalWords
        self.content = content
        self.chaptersData = chapters.encoded()
    }

    /// Decoded chapters from stored JSON data
    var chapters: [Chapter] {
        guard let data = chaptersData, !data.isEmpty else { return [] }
        return [Chapter].decoded(from: data) ?? []
    }

    /// Whether this book has chapter navigation available
    var hasChapters: Bool {
        guard let data = chaptersData, !data.isEmpty else { return false }
        return true
    }

    var words: [String] {
        content.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
    }

    var percentComplete: Double {
        guard let progress = progress, totalWords > 0 else { return 0 }
        return Double(progress.currentWordIndex) / Double(totalWords) * 100
    }
}
