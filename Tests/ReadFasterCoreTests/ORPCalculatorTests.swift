import XCTest
@testable import ReadFasterCore

final class ORPCalculatorTests: XCTestCase {
    func testSingleCharWord() {
        XCTAssertEqual(ORPCalculator.calculate(for: "I"), 0)
    }

    func testTwoCharWord() {
        XCTAssertEqual(ORPCalculator.calculate(for: "on"), 0)
    }

    func testThreeCharWord() {
        XCTAssertEqual(ORPCalculator.calculate(for: "the"), 1)
    }

    func testMediumWord() {
        XCTAssertEqual(ORPCalculator.calculate(for: "reading"), 2)
    }

    func testLongWord() {
        XCTAssertEqual(ORPCalculator.calculate(for: "comprehension"), 4)
    }

    func testEmptyWord() {
        XCTAssertEqual(ORPCalculator.calculate(for: ""), 0)
    }

    func testSplitWord() {
        let parts = ORPCalculator.split(word: "hello")
        XCTAssertEqual(parts.before, "h")
        XCTAssertEqual(parts.orp, "e")
        XCTAssertEqual(parts.after, "llo")
    }

    func testSplitSingleChar() {
        let parts = ORPCalculator.split(word: "I")
        XCTAssertEqual(parts.before, "")
        XCTAssertEqual(parts.orp, "I")
        XCTAssertEqual(parts.after, "")
    }

    func testSplitEmpty() {
        let parts = ORPCalculator.split(word: "")
        XCTAssertEqual(parts.before, "")
        XCTAssertNil(parts.orp)
        XCTAssertEqual(parts.after, "")
    }

    func testORPWordModel() {
        let orpWord = ORPWord(word: "reading")
        XCTAssertEqual(orpWord.fullWord, "reading")
        XCTAssertEqual(orpWord.leadingCount, 2)
        XCTAssertEqual(orpWord.totalCount, 7)
        XCTAssertEqual(orpWord.focal, "a")
    }
}
