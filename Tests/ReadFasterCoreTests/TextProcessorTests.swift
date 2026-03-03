import XCTest
@testable import ReadFasterCore

final class TextProcessorTests: XCTestCase {
    func testBasicTokenization() {
        let words = TextProcessor.process("Hello world")
        XCTAssertEqual(words, ["Hello", "world"])
    }

    func testMultipleSpaces() {
        let words = TextProcessor.process("Hello   world   test")
        XCTAssertEqual(words, ["Hello", "world", "test"])
    }

    func testNewlines() {
        let words = TextProcessor.process("Hello\nworld\ntest")
        XCTAssertEqual(words, ["Hello", "world", "test"])
    }

    func testPunctuationPreserved() {
        let words = TextProcessor.process("Hello, world! How are you?")
        XCTAssertEqual(words, ["Hello,", "world!", "How", "are", "you?"])
    }

    func testEmptyString() {
        let words = TextProcessor.process("")
        XCTAssertEqual(words, [])
    }

    func testEstimatedReadingTime() {
        let time = TextProcessor.estimatedReadingTime(wordCount: 300, wpm: 300)
        XCTAssertEqual(time, 60.0, accuracy: 0.01)
    }

    func testFormatDuration() {
        XCTAssertEqual(TextProcessor.formatDuration(65), "1:05")
        XCTAssertEqual(TextProcessor.formatDuration(3661), "1:01:01")
        XCTAssertEqual(TextProcessor.formatDuration(30), "0:30")
    }

    func testFormatWordCount() {
        let formatted = TextProcessor.formatWordCount(1234)
        XCTAssertTrue(formatted.contains("1") && formatted.contains("234"))
    }
}
