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
            Chapter(title: "Ch2", startWordIndex: 500)
        ]
        let data = chapters.encoded()
        XCTAssertNotNil(data)

        let decoded = [Chapter].decoded(from: data!)
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded!.count, 2)
        XCTAssertEqual(decoded![0].title, "Ch1")
        XCTAssertEqual(decoded![1].title, "Ch2")
    }

    func testCurrentChapterLinearLookup() {
        let chapters = [
            Chapter(title: "Intro", startWordIndex: 0),
            Chapter(title: "Middle", startWordIndex: 120),
            Chapter(title: "End", startWordIndex: 260)
        ]

        XCTAssertEqual(chapters.currentChapter(for: 0)?.title, "Intro")
        XCTAssertEqual(chapters.currentChapter(for: 119)?.title, "Intro")
        XCTAssertEqual(chapters.currentChapter(for: 120)?.title, "Middle")
        XCTAssertEqual(chapters.currentChapter(for: 500)?.title, "End")
    }

    func testCurrentChapterUsesMostSpecificNestedChapter() {
        let partOne = Chapter(
            title: "Part One",
            startWordIndex: 0,
            children: [
                Chapter(title: "Chapter 1", startWordIndex: 30),
                Chapter(title: "Chapter 2", startWordIndex: 90)
            ]
        )
        let partTwo = Chapter(title: "Part Two", startWordIndex: 150)

        let chapters = [partOne, partTwo]

        XCTAssertEqual(chapters.currentChapter(for: 10)?.title, "Part One")
        XCTAssertEqual(chapters.currentChapter(for: 35)?.title, "Chapter 1")
        XCTAssertEqual(chapters.currentChapter(for: 130)?.title, "Chapter 2")
        XCTAssertEqual(chapters.currentChapter(for: 155)?.title, "Part Two")
    }

    func testFilteringKeepsMatchingParentAndMatchingChildrenOnly() {
        let chapters = [
            Chapter(
                title: "Part One",
                startWordIndex: 0,
                children: [
                    Chapter(title: "Origins", startWordIndex: 10),
                    Chapter(title: "Discovery", startWordIndex: 20)
                ]
            ),
            Chapter(title: "Appendix", startWordIndex: 200)
        ]

        let filtered = chapters.filtered(matching: "orig")
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered[0].title, "Part One")
        XCTAssertEqual(filtered[0].children.map(\.title), ["Origins"])
    }

    func testFilteringByParentTitleKeepsChildrenHierarchy() {
        let chapters = [
            Chapter(
                title: "Part One",
                startWordIndex: 0,
                children: [
                    Chapter(title: "Origins", startWordIndex: 10),
                    Chapter(title: "Discovery", startWordIndex: 20)
                ]
            )
        ]

        let filtered = chapters.filtered(matching: "part")
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered[0].title, "Part One")
        XCTAssertEqual(filtered[0].children.count, 2)
    }

    func testFilteringWithNoMatchesReturnsEmpty() {
        let chapters = [
            Chapter(title: "Intro", startWordIndex: 0),
            Chapter(title: "Middle", startWordIndex: 100)
        ]

        XCTAssertTrue(chapters.filtered(matching: "zzzz").isEmpty)
    }
}
