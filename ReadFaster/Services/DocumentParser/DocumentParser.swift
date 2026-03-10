import Foundation
import SwiftSoup

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
    case invalidRemoteURL
    case networkFailed(String)

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
        case .invalidRemoteURL:
            return "Enter a valid HTTP or HTTPS link."
        case .networkFailed(let reason):
            return "Failed to fetch link: \(reason)"
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

struct RemoteImportedDocument {
    let fileType: FileType
    let fileName: String
    let parsedDocument: ParsedDocument
}

struct RemoteDocumentImporter {
    private enum RemoteContentKind {
        case pdf
        case epub
        case text
        case html
    }

    func importDocument(from remoteURL: URL) async throws -> RemoteImportedDocument {
        guard let scheme = remoteURL.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            throw DocumentParserError.invalidRemoteURL
        }

        var request = URLRequest(url: remoteURL)
        request.timeoutInterval = 30
        request.setValue(
            "Mozilla/5.0 (compatible; ReadFaster/1.0; +https://readfaster.app)",
            forHTTPHeaderField: "User-Agent"
        )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw DocumentParserError.networkFailed(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DocumentParserError.networkFailed("The server response was invalid.")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw DocumentParserError.networkFailed(
                "Server returned \(httpResponse.statusCode) \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))."
            )
        }

        let finalURL = response.url ?? remoteURL
        let suggestedFileName = resolvedFileName(from: response, fallbackURL: finalURL)
        let contentKind = detectContentKind(
            mimeType: response.mimeType,
            pathExtension: finalURL.pathExtension,
            suggestedFileName: suggestedFileName,
            data: data
        )

        switch contentKind {
        case .pdf:
            let parsedDocument = try await parseDownloadedFile(
                data: data,
                preferredExtension: "pdf"
            )
            return RemoteImportedDocument(
                fileType: .pdf,
                fileName: suggestedFileName,
                parsedDocument: parsedDocument
            )
        case .epub:
            let parsedDocument = try await parseDownloadedFile(
                data: data,
                preferredExtension: "epub"
            )
            return RemoteImportedDocument(
                fileType: .epub,
                fileName: suggestedFileName,
                parsedDocument: parsedDocument
            )
        case .text:
            let parsedDocument = try await parseDownloadedFile(
                data: data,
                preferredExtension: normalizedTextExtension(for: suggestedFileName)
            )
            return RemoteImportedDocument(
                fileType: .txt,
                fileName: suggestedFileName,
                parsedDocument: parsedDocument
            )
        case .html:
            let parsedDocument = try parseHTMLDocument(data: data, sourceURL: finalURL)
            return RemoteImportedDocument(
                fileType: .web,
                fileName: suggestedFileName,
                parsedDocument: parsedDocument
            )
        }
    }

    static func normalizedURL(from rawValue: String) throws -> URL {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw DocumentParserError.invalidRemoteURL
        }

        if let explicitURL = URL(string: trimmed),
           let scheme = explicitURL.scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            return explicitURL
        }

        if let httpsURL = URL(string: "https://\(trimmed)"),
           let scheme = httpsURL.scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            return httpsURL
        }

        throw DocumentParserError.invalidRemoteURL
    }

    private func detectContentKind(
        mimeType: String?,
        pathExtension: String,
        suggestedFileName: String,
        data: Data
    ) -> RemoteContentKind {
        let lowercasedMimeType = mimeType?.lowercased() ?? ""
        let lowercasedExtension = pathExtension.lowercased()
        let suggestedExtension = URL(fileURLWithPath: suggestedFileName).pathExtension.lowercased()
        let effectiveExtension = !suggestedExtension.isEmpty ? suggestedExtension : lowercasedExtension

        if effectiveExtension == "pdf" || lowercasedMimeType.contains("pdf") {
            return .pdf
        }

        if effectiveExtension == "epub" || lowercasedMimeType.contains("epub") {
            return .epub
        }

        if ["txt", "text", "md"].contains(effectiveExtension) ||
            lowercasedMimeType == "text/plain" ||
            lowercasedMimeType == "text/markdown" {
            return .text
        }

        if effectiveExtension == "html" || effectiveExtension == "htm" ||
            lowercasedMimeType.contains("html") ||
            lowercasedMimeType.contains("xhtml") {
            return .html
        }

        if let decodedText = Self.decodedString(from: data) {
            let trimmed = decodedText.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.localizedCaseInsensitiveContains("<html") ||
                trimmed.localizedCaseInsensitiveContains("<body") {
                return .html
            }

            return .text
        }

        return .html
    }

    private func parseDownloadedFile(
        data: Data,
        preferredExtension: String
    ) async throws -> ParsedDocument {
        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(preferredExtension)

        try data.write(to: temporaryURL, options: .atomic)
        defer {
            try? FileManager.default.removeItem(at: temporaryURL)
        }

        guard let parser = DocumentParserFactory.parser(for: temporaryURL) else {
            throw DocumentParserError.unsupportedFormat
        }

        return try await parser.parse(url: temporaryURL)
    }

    private func parseHTMLDocument(data: Data, sourceURL: URL) throws -> ParsedDocument {
        guard let html = Self.decodedString(from: data) else {
            throw DocumentParserError.parsingFailed("Could not decode web page content.")
        }

        let document: Document
        do {
            document = try SwiftSoup.parse(html, sourceURL.absoluteString)
            try document.select(
                "script, style, noscript, svg, canvas, iframe, form, button, nav, footer, aside, .sidebar, .related, .advertisement, .ads, .newsletter"
            ).remove()
        } catch {
            throw DocumentParserError.parsingFailed("Could not parse web page HTML.")
        }

        let title = (try? extractTitle(from: document, sourceURL: sourceURL)) ?? fallbackTitle(for: sourceURL)
        let author = try? extractAuthor(from: document)
        let content = try extractReadableContent(from: document)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedContent.isEmpty else {
            throw DocumentParserError.emptyContent
        }

        return ParsedDocument(
            title: title,
            author: author,
            content: trimmedContent,
            coverImage: nil,
            chapters: []
        )
    }

    private func extractTitle(from document: Document, sourceURL: URL) throws -> String {
        let selectors = [
            "meta[property=og:title]",
            "meta[name=twitter:title]",
            "meta[name=parsely-title]",
            "meta[name=title]"
        ]

        for selector in selectors {
            if let title = try metadataContent(from: document, selector: selector), !title.isEmpty {
                return title
            }
        }

        if let articleTitle = try text(forFirstMatchIn: document, selector: "article h1, main h1, h1"), !articleTitle.isEmpty {
            return articleTitle
        }

        if let pageTitle = try text(forFirstMatchIn: document, selector: "title"), !pageTitle.isEmpty {
            return pageTitle
        }

        return fallbackTitle(for: sourceURL)
    }

    private func extractAuthor(from document: Document) throws -> String? {
        let selectors = [
            "meta[name=author]",
            "meta[property=article:author]",
            "meta[name=parsely-author]",
            "meta[name=sailthru.author]",
            "meta[name=dc.creator]"
        ]

        for selector in selectors {
            if let author = try metadataContent(from: document, selector: selector), !author.isEmpty {
                return author
            }
        }

        return try text(forFirstMatchIn: document, selector: "[rel=author], .author, .byline, [itemprop=author]")
    }

    private func extractReadableContent(from document: Document) throws -> String {
        let prioritySelectors = [
            "article",
            "main",
            "[role=main]",
            ".article-body",
            ".entry-content",
            ".post-content",
            ".story-body",
            ".article-content",
            ".content"
        ]

        let priorityCandidates = Array(try document.select(prioritySelectors.joined(separator: ", ")))
        let fallbackCandidates = Array(try document.select("section, div"))
        let candidates = priorityCandidates.isEmpty ? fallbackCandidates : priorityCandidates

        let bestElement = try candidates.max { lhs, rhs in
            try score(for: lhs) < score(for: rhs)
        }

        guard let rootElement = bestElement ?? (try document.body()) else {
            throw DocumentParserError.emptyContent
        }

        let blocks = Array(try rootElement.select("h1, h2, h3, h4, p, li, blockquote, pre"))
            .map { try normalizeInlineText($0.text()) }
            .filter { block in
                block.split(whereSeparator: \.isWhitespace).count >= 4
            }

        if !blocks.isEmpty {
            return deduplicatedBlocks(from: blocks).joined(separator: "\n\n")
        }

        return normalizeInlineText(try rootElement.text())
    }

    private func score(for element: Element) throws -> Int {
        let text = normalizeInlineText(try element.text())
        let paragraphCount = try element.select("p").count
        let linkTextLength = normalizeInlineText(try element.select("a").text()).count
        let headingCount = try element.select("h1, h2, h3").count

        return text.count + (paragraphCount * 250) + (headingCount * 100) - linkTextLength
    }

    private func deduplicatedBlocks(from blocks: [String]) -> [String] {
        var seen = Set<String>()
        return blocks.filter { block in
            let inserted = seen.insert(block).inserted
            return inserted
        }
    }

    private func metadataContent(from document: Document, selector: String) throws -> String? {
        guard let value = try document.select(selector).first()?.attr("content") else {
            return nil
        }

        let normalized = normalizeInlineText(value)
        return normalized.isEmpty ? nil : normalized
    }

    private func text(forFirstMatchIn document: Document, selector: String) throws -> String? {
        guard let text = try document.select(selector).first()?.text() else {
            return nil
        }

        let normalized = normalizeInlineText(text)
        return normalized.isEmpty ? nil : normalized
    }

    private func resolvedFileName(from response: URLResponse, fallbackURL: URL) -> String {
        let suggestedFileName = response.suggestedFilename?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !suggestedFileName.isEmpty {
            return suggestedFileName
        }

        let lastPathComponent = fallbackURL.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
        if !lastPathComponent.isEmpty {
            return lastPathComponent
        }

        return fallbackTitle(for: fallbackURL)
    }

    private func normalizedTextExtension(for fileName: String) -> String {
        let pathExtension = URL(fileURLWithPath: fileName).pathExtension.lowercased()
        return TextParser.supportedExtensions.contains(pathExtension) ? pathExtension : "txt"
    }

    private func fallbackTitle(for url: URL) -> String {
        let lastPathComponent = url.deletingPathExtension().lastPathComponent
        if !lastPathComponent.isEmpty {
            return lastPathComponent
                .replacingOccurrences(of: "-", with: " ")
                .replacingOccurrences(of: "_", with: " ")
        }

        if let host = url.host, !host.isEmpty {
            return host
        }

        return "Web Import"
    }

    private func normalizeInlineText(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func decodedString(from data: Data) -> String? {
        if let utf8 = String(data: data, encoding: .utf8) {
            return utf8
        }

        if let utf16 = String(data: data, encoding: .utf16) {
            return utf16
        }

        if let latin1 = String(data: data, encoding: .isoLatin1) {
            return latin1
        }

        return nil
    }
}
