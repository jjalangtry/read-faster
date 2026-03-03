import Foundation

/// Represents a chapter or section in a book with hierarchical support for subsections.
struct Chapter: Codable, Identifiable, Hashable {
    let id: UUID
    let title: String
    let startWordIndex: Int
    var children: [Chapter]

    init(id: UUID = UUID(), title: String, startWordIndex: Int, children: [Chapter] = []) {
        self.id = id
        self.title = title
        self.startWordIndex = startWordIndex
        self.children = children
    }

    /// Returns true if this chapter has subsections
    var hasChildren: Bool {
        !children.isEmpty
    }

    /// Flattens the chapter hierarchy into a single array
    var flattened: [Chapter] {
        [self] + children.flatMap { $0.flattened }
    }
}

// MARK: - Encoding/Decoding Helpers

extension [Chapter] {
    /// Encodes the chapter array to JSON data for storage
    func encoded() -> Data? {
        try? JSONEncoder().encode(self)
    }

    /// Decodes a chapter array from JSON data
    static func decoded(from data: Data) -> [Chapter]? {
        try? JSONDecoder().decode([Chapter].self, from: data)
    }

    /// Flattens a chapter hierarchy list into a single array.
    var flattened: [Chapter] {
        flatMap { $0.flattened }
    }

    /// Finds the most specific chapter for a given word index.
    /// Chapters are evaluated by ascending start index.
    func currentChapter(for wordIndex: Int) -> Chapter? {
        let ordered = flattened
            .enumerated()
            .sorted { lhs, rhs in
                if lhs.element.startWordIndex == rhs.element.startWordIndex {
                    return lhs.offset < rhs.offset
                }
                return lhs.element.startWordIndex < rhs.element.startWordIndex
            }
            .map(\.element)

        guard let first = ordered.first else { return nil }
        if wordIndex <= first.startWordIndex {
            return first
        }

        for idx in ordered.indices {
            let chapter = ordered[idx]
            let nextStart = idx + 1 < ordered.count ? ordered[idx + 1].startWordIndex : Int.max
            if wordIndex >= chapter.startWordIndex && wordIndex < nextStart {
                return chapter
            }
        }

        return ordered.last
    }

    /// Filters chapters by title while preserving hierarchy.
    /// Matching parent chapters are kept with only matching descendants.
    func filtered(matching query: String) -> [Chapter] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return self }

        return compactMap { $0.filtered(matching: trimmedQuery) }
    }
}

private extension Chapter {
    func filtered(matching query: String) -> Chapter? {
        let titleMatches = title.localizedCaseInsensitiveContains(query)
        if titleMatches {
            return self
        }

        let filteredChildren = children.filtered(matching: query)
        guard !filteredChildren.isEmpty else { return nil }

        return Chapter(
            id: id,
            title: title,
            startWordIndex: startWordIndex,
            children: filteredChildren
        )
    }
}
