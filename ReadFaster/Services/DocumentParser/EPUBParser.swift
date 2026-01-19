import Foundation
import ZIPFoundation
import SwiftSoup

struct EPUBParser: DocumentParser {
    static let supportedExtensions = ["epub"]

    func parse(url: URL) async throws -> ParsedDocument {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw DocumentParserError.fileNotFound
        }

        let archive: Archive
        do {
            archive = try Archive(url: url, accessMode: .read)
        } catch {
            throw DocumentParserError.parsingFailed("Could not open EPUB archive: \(error.localizedDescription)")
        }

        // 1. Find the root file path from container.xml
        let rootFilePath = try findRootFile(in: archive)

        // 2. Parse the OPF file to get metadata, spine, manifest, and TOC reference
        let opfResult = try parseOPF(archive: archive, opfPath: rootFilePath)

        // 3. Extract text content in spine order, tracking word positions per spine item
        let (content, spineWordPositions) = try extractContentWithPositions(
            archive: archive,
            spine: opfResult.spine,
            basePath: opfResult.basePath
        )

        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DocumentParserError.emptyContent
        }

        // 4. Try to extract cover image
        let coverImage = try? extractCover(archive: archive, metadata: opfResult.metadata, basePath: opfResult.basePath)

        // 5. Extract table of contents and map to word positions
        let chapters = try extractChapters(
            archive: archive,
            opfResult: opfResult,
            spineWordPositions: spineWordPositions
        )

        return ParsedDocument(
            title: opfResult.metadata.title ?? url.deletingPathExtension().lastPathComponent,
            author: opfResult.metadata.author,
            content: content,
            coverImage: coverImage,
            chapters: chapters
        )
    }

    // MARK: - Container Parsing

    private func findRootFile(in archive: Archive) throws -> String {
        guard let containerEntry = archive["META-INF/container.xml"] else {
            throw DocumentParserError.parsingFailed("Missing container.xml")
        }

        var containerData = Data()
        do {
            _ = try archive.extract(containerEntry) { data in
                containerData.append(data)
            }
        } catch {
            throw DocumentParserError.parsingFailed("Could not extract container.xml: \(error.localizedDescription)")
        }

        guard let containerXML = String(data: containerData, encoding: .utf8) else {
            throw DocumentParserError.parsingFailed("Could not read container.xml as UTF-8")
        }

        do {
            let doc = try SwiftSoup.parse(containerXML, "", Parser.xmlParser())
            let rootFiles = try doc.select("rootfile")

            guard let rootFile = rootFiles.first() else {
                throw DocumentParserError.parsingFailed("No rootfile element found in container.xml")
            }

            let fullPath = try rootFile.attr("full-path")
            guard !fullPath.isEmpty else {
                throw DocumentParserError.parsingFailed("Empty full-path attribute in rootfile")
            }

            return fullPath
        } catch let error as DocumentParserError {
            throw error
        } catch {
            throw DocumentParserError.parsingFailed("Failed to parse container.xml: \(error.localizedDescription)")
        }
    }

    // MARK: - OPF Parsing

    private func parseOPF(archive: Archive, opfPath: String) throws -> OPFResult {
        guard let opfEntry = archive[opfPath] else {
            throw DocumentParserError.parsingFailed("Missing OPF file at \(opfPath)")
        }

        var opfData = Data()
        do {
            _ = try archive.extract(opfEntry) { data in
                opfData.append(data)
            }
        } catch {
            throw DocumentParserError.parsingFailed("Could not extract OPF file: \(error.localizedDescription)")
        }

        guard let opfXML = String(data: opfData, encoding: .utf8) else {
            throw DocumentParserError.parsingFailed("Could not read OPF file as UTF-8")
        }

        let basePath = (opfPath as NSString).deletingLastPathComponent

        do {
            let doc = try SwiftSoup.parse(opfXML, "", Parser.xmlParser())

            // Extract metadata
            var title: String?
            var author: String?
            var coverId: String?

            if let titleEl = try doc.select("title").first() {
                title = try titleEl.text()
            }
            if title == nil || title?.isEmpty == true {
                if let titleEl = try doc.select("dc|title").first() {
                    title = try titleEl.text()
                }
            }

            if let authorEl = try doc.select("creator").first() {
                author = try authorEl.text()
            }
            if author == nil || author?.isEmpty == true {
                if let authorEl = try doc.select("dc|creator").first() {
                    author = try authorEl.text()
                }
            }

            if let metaEl = try doc.select("meta[name=cover]").first() {
                coverId = try metaEl.attr("content")
            }

            // Build manifest
            var manifest: [String: ManifestItem] = [:]
            let items = try doc.select("item")
            for item in items {
                let id = try item.attr("id")
                let href = try item.attr("href")
                let mediaType = try item.attr("media-type")
                let properties = try item.attr("properties")
                if !id.isEmpty && !href.isEmpty {
                    manifest[id] = ManifestItem(id: id, href: href, mediaType: mediaType, properties: properties)
                }
            }

            // Build spine
            var spine: [SpineItem] = []
            let itemRefs = try doc.select("itemref")
            for itemRef in itemRefs {
                let idref = try itemRef.attr("idref")
                if let item = manifest[idref] {
                    spine.append(SpineItem(id: idref, href: item.href))
                }
            }

            // Find TOC reference
            // EPUB3: Look for nav item with properties="nav"
            var tocHref: String?
            var tocType: TOCType = .none

            for (_, item) in manifest {
                if item.properties.contains("nav") {
                    tocHref = item.href
                    tocType = .nav
                    break
                }
            }

            // EPUB2: Look for NCX in spine toc attribute or manifest
            if tocType == .none {
                if let spineEl = try doc.select("spine").first() {
                    let tocId = try spineEl.attr("toc")
                    if !tocId.isEmpty, let ncxItem = manifest[tocId] {
                        tocHref = ncxItem.href
                        tocType = .ncx
                    }
                }
            }

            // Fallback: look for .ncx file in manifest
            if tocType == .none {
                for (_, item) in manifest {
                    if item.mediaType == "application/x-dtbncx+xml" || item.href.hasSuffix(".ncx") {
                        tocHref = item.href
                        tocType = .ncx
                        break
                    }
                }
            }

            let coverHref = coverId.flatMap { manifest[$0]?.href }
            let metadata = EPUBMetadata(title: title, author: author, coverId: coverId, coverHref: coverHref)

            return OPFResult(
                metadata: metadata,
                manifest: manifest,
                spine: spine,
                basePath: basePath,
                tocHref: tocHref,
                tocType: tocType
            )
        } catch let error as DocumentParserError {
            throw error
        } catch {
            throw DocumentParserError.parsingFailed("Failed to parse OPF file: \(error.localizedDescription)")
        }
    }

    // MARK: - Content Extraction with Word Positions

    private func extractContentWithPositions(
        archive: Archive,
        spine: [SpineItem],
        basePath: String
    ) throws -> (String, [String: Int]) {
        var fullContent = ""
        var currentWordIndex = 0
        var spineWordPositions: [String: Int] = [:]
        var foundMainContent = false

        let skipPatterns = [
            "cover", "title", "toc", "nav", "copyright", "dedication",
            "frontmatter", "front-matter", "halftitle", "half-title",
            "series", "praise", "about", "colophon", "credits"
        ]

        for item in spine {
            let hrefLower = item.href.lowercased()
            let shouldSkip = skipPatterns.contains { pattern in
                hrefLower.contains(pattern)
            }

            if !foundMainContent && shouldSkip {
                continue
            }

            let decodedHref = item.href.removingPercentEncoding ?? item.href
            let itemPath = basePath.isEmpty ? decodedHref : "\(basePath)/\(decodedHref)"

            var text: String?

            if let entry = archive[itemPath] {
                text = extractTextFromEntry(archive: archive, entry: entry)
            } else if let fallbackEntry = archive[decodedHref] {
                text = extractTextFromEntry(archive: archive, entry: fallbackEntry)
            }

            if let extractedText = text, !extractedText.isEmpty {
                if extractedText.count > 100 {
                    foundMainContent = true
                }

                if foundMainContent {
                    // Record the word position for this spine item
                    // Use the href (without fragment) as the key
                    let baseHref = decodedHref.components(separatedBy: "#").first ?? decodedHref
                    spineWordPositions[baseHref] = currentWordIndex

                    // Count words and append
                    let words = extractedText.components(separatedBy: .whitespacesAndNewlines)
                        .filter { !$0.isEmpty }
                    currentWordIndex += words.count

                    fullContent += extractedText + "\n\n"
                }
            }
        }

        return (fullContent.trimmingCharacters(in: .whitespacesAndNewlines), spineWordPositions)
    }

    private func extractTextFromEntry(archive: Archive, entry: Entry) -> String? {
        var data = Data()
        do {
            _ = try archive.extract(entry) { chunk in
                data.append(chunk)
            }
        } catch {
            return nil
        }

        let html: String
        if let utf8 = String(data: data, encoding: .utf8) {
            html = utf8
        } else if let latin1 = String(data: data, encoding: .isoLatin1) {
            html = latin1
        } else {
            return nil
        }

        do {
            let doc = try SwiftSoup.parse(html)
            return try doc.body()?.text()
        } catch {
            return nil
        }
    }

    // MARK: - Chapter Extraction

    private func extractChapters(
        archive: Archive,
        opfResult: OPFResult,
        spineWordPositions: [String: Int]
    ) throws -> [Chapter] {
        guard let tocHref = opfResult.tocHref else {
            return []
        }

        let decodedTocHref = tocHref.removingPercentEncoding ?? tocHref
        let tocPath = opfResult.basePath.isEmpty ? decodedTocHref : "\(opfResult.basePath)/\(decodedTocHref)"

        guard let tocEntry = archive[tocPath] ?? archive[decodedTocHref] else {
            return []
        }

        var tocData = Data()
        do {
            _ = try archive.extract(tocEntry) { chunk in
                tocData.append(chunk)
            }
        } catch {
            return []
        }

        guard let tocXML = String(data: tocData, encoding: .utf8) else {
            return []
        }

        switch opfResult.tocType {
        case .nav:
            return parseNavTOC(xml: tocXML, basePath: opfResult.basePath, spineWordPositions: spineWordPositions)
        case .ncx:
            return parseNCXTOC(xml: tocXML, basePath: opfResult.basePath, spineWordPositions: spineWordPositions)
        case .none:
            return []
        }
    }

    private func parseNavTOC(xml: String, basePath: String, spineWordPositions: [String: Int]) -> [Chapter] {
        do {
            let doc = try SwiftSoup.parse(xml)

            // Find the nav element with epub:type="toc" or just the first nav with ol
            let navElements = try doc.select("nav")
            var tocNav: Element?

            for nav in navElements {
                let epubType = try nav.attr("epub:type")
                if epubType.contains("toc") {
                    tocNav = nav
                    break
                }
            }

            // Fallback to first nav with ordered list
            if tocNav == nil {
                tocNav = navElements.first()
            }

            guard let nav = tocNav,
                  let ol = try nav.select("ol").first() else {
                return []
            }

            return parseNavOL(ol: ol, basePath: basePath, spineWordPositions: spineWordPositions)
        } catch {
            return []
        }
    }

    private func parseNavOL(ol: Element, basePath: String, spineWordPositions: [String: Int]) -> [Chapter] {
        var chapters: [Chapter] = []

        do {
            let listItems = ol.children().filter { $0.tagName() == "li" }

            for li in listItems {
                guard let anchor = try li.select("a").first() else { continue }

                let title = try anchor.text().trimmingCharacters(in: .whitespacesAndNewlines)
                let href = try anchor.attr("href")

                guard !title.isEmpty else { continue }

                // Resolve href to find word position
                let wordIndex = resolveHrefToWordIndex(href: href, basePath: basePath, spineWordPositions: spineWordPositions)

                // Check for nested ol (subsections)
                var children: [Chapter] = []
                if let nestedOL = try li.select("> ol").first() {
                    children = parseNavOL(ol: nestedOL, basePath: basePath, spineWordPositions: spineWordPositions)
                }

                let chapter = Chapter(
                    title: title,
                    startWordIndex: wordIndex,
                    children: children
                )
                chapters.append(chapter)
            }
        } catch {
            // Ignore parsing errors for individual items
        }

        return chapters
    }

    private func parseNCXTOC(xml: String, basePath: String, spineWordPositions: [String: Int]) -> [Chapter] {
        do {
            let doc = try SwiftSoup.parse(xml, "", Parser.xmlParser())

            guard let navMap = try doc.select("navMap").first() else {
                return []
            }

            return parseNavPoints(parent: navMap, basePath: basePath, spineWordPositions: spineWordPositions)
        } catch {
            return []
        }
    }

    private func parseNavPoints(parent: Element, basePath: String, spineWordPositions: [String: Int]) -> [Chapter] {
        var chapters: [Chapter] = []

        do {
            let navPoints = parent.children().filter { $0.tagName() == "navpoint" }

            for navPoint in navPoints {
                let title = try navPoint.select("navlabel text").first()?.text() ?? ""
                let href = try navPoint.select("content").first()?.attr("src") ?? ""

                guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }

                let wordIndex = resolveHrefToWordIndex(href: href, basePath: basePath, spineWordPositions: spineWordPositions)

                // Parse nested navPoints
                let children = parseNavPoints(parent: navPoint, basePath: basePath, spineWordPositions: spineWordPositions)

                let chapter = Chapter(
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    startWordIndex: wordIndex,
                    children: children
                )
                chapters.append(chapter)
            }
        } catch {
            // Ignore parsing errors
        }

        return chapters
    }

    private func resolveHrefToWordIndex(href: String, basePath: String, spineWordPositions: [String: Int]) -> Int {
        let decodedHref = href.removingPercentEncoding ?? href

        // Remove fragment identifier
        let baseHref = decodedHref.components(separatedBy: "#").first ?? decodedHref

        // Try direct match
        if let position = spineWordPositions[baseHref] {
            return position
        }

        // Try with base path
        let fullPath = basePath.isEmpty ? baseHref : "\(basePath)/\(baseHref)"
        if let position = spineWordPositions[fullPath] {
            return position
        }

        // Try matching just the filename
        let filename = (baseHref as NSString).lastPathComponent
        for (key, position) in spineWordPositions {
            if (key as NSString).lastPathComponent == filename {
                return position
            }
        }

        // Return 0 if we can't resolve
        return 0
    }

    // MARK: - Cover Extraction

    private func extractCover(archive: Archive, metadata: EPUBMetadata, basePath: String) throws -> Data? {
        guard let coverHref = metadata.coverHref else { return nil }

        let decodedHref = coverHref.removingPercentEncoding ?? coverHref
        let coverPath = basePath.isEmpty ? decodedHref : "\(basePath)/\(decodedHref)"

        let entry = archive[coverPath] ?? archive[decodedHref]
        guard let coverEntry = entry else { return nil }

        var data = Data()
        _ = try archive.extract(coverEntry) { chunk in
            data.append(chunk)
        }

        return data
    }
}

// MARK: - Private Types

private struct EPUBMetadata {
    let title: String?
    let author: String?
    let coverId: String?
    let coverHref: String?
}

private struct ManifestItem {
    let id: String
    let href: String
    let mediaType: String
    let properties: String
}

private struct SpineItem {
    let id: String
    let href: String
}

private enum TOCType {
    case ncx      // EPUB2
    case nav      // EPUB3
    case none
}

private struct OPFResult {
    let metadata: EPUBMetadata
    let manifest: [String: ManifestItem]
    let spine: [SpineItem]
    let basePath: String
    let tocHref: String?
    let tocType: TOCType
}
