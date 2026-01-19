import Foundation

struct ParsedDocument {
    let title: String
    let author: String?
    let content: String
    let coverImage: Data?
    let chapters: [Chapter]

    init(
        title: String,
        author: String? = nil,
        content: String,
        coverImage: Data? = nil,
        chapters: [Chapter] = []
    ) {
        self.title = title
        self.author = author
        self.content = content
        self.coverImage = coverImage
        self.chapters = chapters
    }

    var wordCount: Int {
        content.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
    }
}

protocol DocumentParser {
    func parse(url: URL) async throws -> ParsedDocument
    static var supportedExtensions: [String] { get }
}

enum DocumentParserError: LocalizedError {
    case unsupportedFormat
    case fileNotFound
    case parsingFailed(String)
    case emptyContent

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "This file format is not supported."
        case .fileNotFound:
            return "The file could not be found."
        case .parsingFailed(let reason):
            return "Failed to parse document: \(reason)"
        case .emptyContent:
            return "The document appears to be empty."
        }
    }
}

struct DocumentParserFactory {
    static func parser(for url: URL) -> DocumentParser? {
        let ext = url.pathExtension.lowercased()

        if TextParser.supportedExtensions.contains(ext) {
            return TextParser()
        } else if EPUBParser.supportedExtensions.contains(ext) {
            return EPUBParser()
        } else if PDFParser.supportedExtensions.contains(ext) {
            return PDFParser()
        }

        return nil
    }

    static var supportedExtensions: [String] {
        TextParser.supportedExtensions +
        EPUBParser.supportedExtensions +
        PDFParser.supportedExtensions
    }
}
