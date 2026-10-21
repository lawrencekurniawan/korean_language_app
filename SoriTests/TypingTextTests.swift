import XCTest
@testable import Sori

final class TypingTextTests: XCTestCase {
    func testModernKoreanIsTypeable() {
        XCTAssertTrue(TypingText.isTypeable("안녕하세요."))
        XCTAssertTrue(TypingText.isTypeable("한글 123!?"))
        XCTAssertTrue(TypingText.isTypeable("가, 나?"))
        XCTAssertTrue(TypingText.isTypeable("가~요."))
        XCTAssertTrue(
            TypingText.isTypeable("가나.,?!'\"()-:;/@#%&*+=~0123456789.")
        )
    }

    func testLatinTextIsNotTypeable() {
        XCTAssertFalse(TypingText.isTypeable("Hello"))
        XCTAssertFalse(TypingText.isTypeable("한글 ABC"))
    }

    func testClassicalJamoAndHanjaAreNotTypeable() {
        XCTAssertFalse(TypingText.isTypeable("옛한글 ᄒᆞ"))
        XCTAssertFalse(TypingText.isTypeable("漢字"))
    }

    func testUnsupportedPunctuationIsRejected() {
        XCTAssertFalse(TypingText.isTypeable("문장…"))
        XCTAssertFalse(TypingText.isTypeable("가·나"))
        XCTAssertFalse(TypingText.isTypeable("“따옴표”"))
    }

    func testEmptyOrWhitespaceOnlyIsNotTypeable() {
        XCTAssertFalse(TypingText.isTypeable(""))
        XCTAssertFalse(TypingText.isTypeable("   "))
    }
}
