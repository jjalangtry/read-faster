import XCTest
@testable import ReadFasterCore

final class ChapterTests: XCTestCase {
    func testChapterCreation() {
        let chapter = Chapter(title: "Introduction", startWordIndex: 0)
        XCTAssertEqual(chapter.title, "Introduction")
        XCTAssertEqual(chapter.startWordIndex, 0)
        XCTAssertFalse(chapter.hasChildren)
    }

    func testChapterWithChildren() {
        let sub1 = Chapter(title: "Section 1.1", startWordIndex: 100)
        let sub2 = Chapter(title: "Section 1.2", startWordIndex: 200)
        let parent = Chapter(title: "Chapter 1", startWordIndex: 0, children: [sub1, sub2])

        XCTAssertTrue(parent.hasChildren)
        XCTAssertEqual(parent.children.count, 2)
    }

    func testFlatten() {
        let sub = Chapter(title: "Section 1.1", startWordIndex: 100)
        let parent = Chapter(title: "Chapter 1", startWordIndex: 0, children: [sub])

        let flat = parent.flattened
        XCTAssertEqual(flat.count, 2)
        XCTAssertEqual(flat[0].title, "Chapter 1")
        XCTAssertEqual(flat[1].title, "Section 1.1")
    }

    func testEncodeDecode() {
        let chapters = [
            Chapter(title: "Ch1", startWordIndex: 0),
            Chapter(title: "Ch2", startWordIndex: 500),
        ]
        let data = chapters.encoded()
        XCTAssertNotNil(data)

        let decoded = [Chapter].decoded(from: data!)
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded!.count, 2)
        XCTAssertEqual(decoded![0].title, "Ch1")
        XCTAssertEqual(decoded![1].title, "Ch2")
    }
}
