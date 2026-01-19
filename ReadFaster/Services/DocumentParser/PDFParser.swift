import Foundation
import PDFKit

struct PDFParser: DocumentParser {
    static let supportedExtensions = ["pdf"]

    func parse(url: URL) async throws -> ParsedDocument {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw DocumentParserError.fileNotFound
        }

        guard let pdfDocument = PDFDocument(url: url) else {
            throw DocumentParserError.parsingFailed("Could not open PDF document.")
        }

        // Extract text and track word counts per page
        let (content, pageWordPositions) = extractTextWithPagePositions(from: pdfDocument)

        var finalContent = content

        // If no extractable text, this might be a scanned PDF - attempt OCR
        if finalContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            finalContent = try await performOCR(on: pdfDocument)
        }

        let trimmed = finalContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw DocumentParserError.emptyContent
        }

        // Extract title from PDF metadata or filename
        let title = pdfDocument.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String
            ?? url.deletingPathExtension().lastPathComponent

        let author = pdfDocument.documentAttributes?[PDFDocumentAttribute.authorAttribute] as? String

        // Try to get cover image from first page
        let coverImage = extractCoverImage(from: pdfDocument)

        // Extract chapters from PDF outline
        let chapters = extractChapters(from: pdfDocument, pageWordPositions: pageWordPositions)

        return ParsedDocument(
            title: title,
            author: author,
            content: trimmed,
            coverImage: coverImage,
            chapters: chapters
        )
    }

    // MARK: - Text Extraction with Page Positions

    private func extractTextWithPagePositions(from document: PDFDocument) -> (String, [Int: Int]) {
        var fullText = ""
        var currentWordIndex = 0
        var pageWordPositions: [Int: Int] = [:]

        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }

            // Record the starting word index for this page
            pageWordPositions[pageIndex] = currentWordIndex

            if let pageText = page.string, !pageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let words = pageText.components(separatedBy: .whitespacesAndNewlines)
                    .filter { !$0.isEmpty }
                currentWordIndex += words.count

                fullText += pageText + "\n\n"
            }
        }

        return (fullText, pageWordPositions)
    }

    // MARK: - Chapter Extraction from PDF Outline

    private func extractChapters(from document: PDFDocument, pageWordPositions: [Int: Int]) -> [Chapter] {
        guard let outlineRoot = document.outlineRoot else {
            return []
        }

        return extractOutlineItems(from: outlineRoot, document: document, pageWordPositions: pageWordPositions)
    }

    private func extractOutlineItems(
        from outline: PDFOutline,
        document: PDFDocument,
        pageWordPositions: [Int: Int]
    ) -> [Chapter] {
        var chapters: [Chapter] = []

        for i in 0..<outline.numberOfChildren {
            guard let child = outline.child(at: i) else { continue }

            let title = child.label ?? "Untitled"

            // Get the destination page
            var wordIndex = 0
            if let destination = child.destination,
               let page = destination.page {
                let pageIndex = document.index(for: page)
                wordIndex = pageWordPositions[pageIndex] ?? 0
            }

            // Recursively get children
            let children = extractOutlineItems(from: child, document: document, pageWordPositions: pageWordPositions)

            let chapter = Chapter(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                startWordIndex: wordIndex,
                children: children
            )

            // Only add if has a title
            if !chapter.title.isEmpty {
                chapters.append(chapter)
            }
        }

        return chapters
    }

    // MARK: - OCR

    private func performOCR(on document: PDFDocument) async throws -> String {
        return try await OCRParser().performOCR(on: document)
    }

    // MARK: - Cover Image Extraction

    private func extractCoverImage(from document: PDFDocument) -> Data? {
        guard let firstPage = document.page(at: 0) else { return nil }

        let pageRect = firstPage.bounds(for: .mediaBox)
        let scale: CGFloat = 0.5
        let scaledSize = CGSize(
            width: pageRect.width * scale,
            height: pageRect.height * scale
        )

        #if os(macOS)
        let image = NSImage(size: scaledSize)
        image.lockFocus()
        if let context = NSGraphicsContext.current?.cgContext {
            context.setFillColor(NSColor.white.cgColor)
            context.fill(CGRect(origin: .zero, size: scaledSize))
            context.scaleBy(x: scale, y: scale)
            firstPage.draw(with: .mediaBox, to: context)
        }
        image.unlockFocus()
        return image.tiffRepresentation
        #else
        let renderer = UIGraphicsImageRenderer(size: scaledSize)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: scaledSize))
            context.cgContext.scaleBy(x: scale, y: scale)
            firstPage.draw(with: .mediaBox, to: context.cgContext)
        }
        return image.pngData()
        #endif
    }
}
