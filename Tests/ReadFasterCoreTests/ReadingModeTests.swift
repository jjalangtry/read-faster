import XCTest
@testable import ReadFasterCore

final class ReadingModeTests: XCTestCase {
    func testAllCases() {
        XCTAssertEqual(ReadingMode.allCases.count, 3)
    }

    func testSkimSettings() {
        let settings = ReadingMode.skim.settings
        XCTAssertEqual(settings.baseWPM, 600)
        XCTAssertFalse(settings.showSentenceContext)
        XCTAssertFalse(settings.adaptivePacingEnabled)
    }

    func testNormalSettings() {
        let settings = ReadingMode.normal.settings
        XCTAssertEqual(settings.baseWPM, 350)
        XCTAssertTrue(settings.showSentenceContext)
        XCTAssertTrue(settings.adaptivePacingEnabled)
    }

    func testStudySettings() {
        let settings = ReadingMode.study.settings
        XCTAssertEqual(settings.baseWPM, 250)
        XCTAssertTrue(settings.showSentenceContext)
        XCTAssertTrue(settings.adaptivePacingEnabled)
    }

    func testDisplayNames() {
        XCTAssertEqual(ReadingMode.skim.displayName, "Skim")
        XCTAssertEqual(ReadingMode.normal.displayName, "Normal")
        XCTAssertEqual(ReadingMode.study.displayName, "Study")
    }

    func testIcons() {
        XCTAssertEqual(ReadingMode.skim.icon, "hare")
        XCTAssertEqual(ReadingMode.normal.icon, "figure.walk")
        XCTAssertEqual(ReadingMode.study.icon, "book")
    }
}
