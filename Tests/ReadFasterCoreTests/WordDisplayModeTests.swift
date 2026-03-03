import XCTest
@testable import ReadFasterCore

final class WordDisplayModeTests: XCTestCase {
    func testWordsPerChunkMapping() {
        XCTAssertEqual(WordDisplayMode.singleWord.wordsPerChunk, 1)
        XCTAssertEqual(WordDisplayMode.threeWordChunk.wordsPerChunk, 3)
    }

    func testTitlesAreStable() {
        XCTAssertEqual(WordDisplayMode.singleWord.title, "1 word at a time")
        XCTAssertEqual(WordDisplayMode.threeWordChunk.title, "3-word chunks")
    }
}
