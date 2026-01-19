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

        // 2. Parse the OPF file to get metadata and spine
        let (metadata, spine, basePath) = try parseOPF(archive: archive, opfPath: rootFilePath)

        // 3. Extract text content in spine order
        let content = try extractContent(archive: archive, spine: spine, basePath: basePath)

        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DocumentParserError.emptyContent
        }

        // 4. Try to extract cover image
        let coverImage = try? extractCover(archive: archive, metadata: metadata, basePath: basePath)

        return ParsedDocument(
            title: metadata.title ?? url.deletingPathExtension().lastPathComponent,
            author: metadata.author,
            content: content,
            coverImage: coverImage
        )
    }

    private func findRootFile(in archive: Archive) throws -> String {
        guard let containerEntry = archive["META-INF/container.xml"] else {
            throw DocumentParserError.parsingFailed("Missing container.xml")
        }

        var containerData = Data()
        _ = try archive.extract(containerEntry) { data in
            containerData.append(data)
        }

        guard let containerXML = String(data: containerData, encoding: .utf8) else {
            throw DocumentParserError.parsingFailed("Could not read container.xml")
        }

        let doc = try SwiftSoup.parse(containerXML, "", Parser.xmlParser())
        guard let rootFile = try doc.select("rootfile").first(),
              let fullPath = try? rootFile.attr("full-path"),
              !fullPath.isEmpty else {
            throw DocumentParserError.parsingFailed("Could not find root file path")
        }

        return fullPath
    }

    private func parseOPF(archive: Archive, opfPath: String) throws -> (EPUBMetadata, [SpineItem], String) {
        guard let opfEntry = archive[opfPath] else {
            throw DocumentParserError.parsingFailed("Missing OPF file at \(opfPath)")
        }

        var opfData = Data()
        _ = try archive.extract(opfEntry) { data in
            opfData.append(data)
        }

        guard let opfXML = String(data: opfData, encoding: .utf8) else {
            throw DocumentParserError.parsingFailed("Could not read OPF file")
        }

        let basePath = (opfPath as NSString).deletingLastPathComponent

        let doc = try SwiftSoup.parse(opfXML, "", Parser.xmlParser())

        // Extract metadata
        let title = try doc.select("metadata title, dc\\:title").first()?.text()
        let author = try doc.select("metadata creator, dc\\:creator").first()?.text()
        let coverId = try doc.select("meta[name=cover]").first()?.attr("content")

        // Build manifest
        var manifest: [String: ManifestItem] = [:]
        for item in try doc.select("manifest item") {
            let id = try item.attr("id")
            let href = try item.attr("href")
            let mediaType = try item.attr("media-type")
            manifest[id] = ManifestItem(id: id, href: href, mediaType: mediaType)
        }

        // Build spine
        var spine: [SpineItem] = []
        for itemRef in try doc.select("spine itemref") {
            let idref = try itemRef.attr("idref")
            if let item = manifest[idref] {
                spine.append(SpineItem(id: idref, href: item.href))
            }
        }

        let metadata = EPUBMetadata(title: title, author: author, coverId: coverId, coverHref: manifest[coverId ?? ""]?.href)

        return (metadata, spine, basePath)
    }

    private func extractContent(archive: Archive, spine: [SpineItem], basePath: String) throws -> String {
        var fullContent = ""

        for item in spine {
            let itemPath = basePath.isEmpty ? item.href : "\(basePath)/\(item.href)"

            guard let entry = archive[itemPath] else { continue }

            var data = Data()
            _ = try archive.extract(entry) { chunk in
                data.append(chunk)
            }

            guard let html = String(data: data, encoding: .utf8) else { continue }

            do {
                let doc = try SwiftSoup.parse(html)
                let text = try doc.body()?.text() ?? ""
                if !text.isEmpty {
                    fullContent += text + "\n\n"
                }
            } catch {
                continue
            }
        }

        return fullContent.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractCover(archive: Archive, metadata: EPUBMetadata, basePath: String) throws -> Data? {
        guard let coverHref = metadata.coverHref else { return nil }

        let coverPath = basePath.isEmpty ? coverHref : "\(basePath)/\(coverHref)"

        guard let entry = archive[coverPath] else { return nil }

        var data = Data()
        _ = try archive.extract(entry) { chunk in
            data.append(chunk)
        }

        return data
    }
}

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
}

private struct SpineItem {
    let id: String
    let href: String
}
