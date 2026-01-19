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
}
