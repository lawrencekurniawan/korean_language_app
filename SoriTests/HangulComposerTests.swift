import XCTest
@testable import Sori

final class HangulComposerTests: XCTestCase {
    private func type(_ keys: [TypingKey]) -> String {
        var input = TypingInputState()
        for key in keys {
            input.press(key)
        }
        return input.text
    }

    func testBasicSyllable() {
        XCTAssertEqual(type([.consonant(0), .vowel(0)]), "가")
    }

    func testFinalConsonant() {
        XCTAssertEqual(type([.consonant(0), .vowel(0), .consonant(2)]), "간")
    }

    func testFinalConsonantMovesToNextSyllable() {
        XCTAssertEqual(
            type([.consonant(0), .vowel(0), .consonant(2), .vowel(0)]),
            "가나"
        )
    }

    func testCompoundFinalSplitsWhenVowelFollows() {
        XCTAssertEqual(
            type([
                .consonant(3), .vowel(0), .consonant(5), .consonant(0), .vowel(0)
            ]),
            "달가"
        )
    }

    func testConsonantAfterFinalStartsNextSyllable() {
        XCTAssertEqual(
            type([
                .consonant(18), .vowel(0), .consonant(2), .consonant(0),
                .vowel(18), .consonant(5)
            ]),
            "한글"
        )
    }

    func testCompoundVowel() {
        XCTAssertEqual(type([.vowel(8), .vowel(0)]), "와")
    }

    func testDoubleConsonant() {
        XCTAssertEqual(type([.consonant(1), .vowel(0)]), "까")
    }

    func testTwoConsonantsRemainSeparate() {
        XCTAssertEqual(type([.consonant(0), .consonant(0)]), "ㄱㄱ")
    }

    func testBackspaceRemovesFinalThenMedialThenInitial() {
        var input = TypingInputState()
        input.press(.consonant(3))
        input.press(.vowel(0))
        input.press(.consonant(5))
        input.press(.consonant(0))
        XCTAssertEqual(input.text, "닭")

        input.press(.backspace)
        XCTAssertEqual(input.text, "달")
        input.press(.backspace)
        XCTAssertEqual(input.text, "다")
        input.press(.backspace)
        XCTAssertEqual(input.text, "ㄷ")
        input.press(.backspace)
        XCTAssertEqual(input.text, "")
    }

    func testBackspaceSplitsCompoundVowel() {
        var input = TypingInputState()
        input.press(.vowel(8))
        input.press(.vowel(0))
        XCTAssertEqual(input.text, "와")

        input.press(.backspace)
        XCTAssertEqual(input.text, "오")
        input.press(.backspace)
        XCTAssertEqual(input.text, "")
    }

    func testAutoInitialBackspaceRemovesWholeSyllable() {
        var input = TypingInputState()
        input.press(.vowel(0))
        XCTAssertEqual(input.text, "아")
        input.press(.backspace)
        XCTAssertEqual(input.text, "")
    }

    func testExplicitInitialIsKeptAfterBackspace() {
        var input = TypingInputState()
        input.press(.consonant(11))
        input.press(.vowel(0))
        XCTAssertEqual(input.text, "아")
        input.press(.backspace)
        XCTAssertEqual(input.text, "ㅇ")
    }

    func testKoreanWordWithExplicitInitial() {
        XCTAssertEqual(
            type([
                .consonant(18), .vowel(0), .consonant(2), .consonant(0),
                .vowel(13), .consonant(0), .consonant(11), .vowel(4)
            ]),
            "한국어"
        )
    }

    func testSentenceWithSpaces() {
        XCTAssertEqual(
            type([
                .consonant(11), .vowel(0), .consonant(2),
                .consonant(2), .vowel(6), .consonant(11),
                .space,
                .consonant(18), .vowel(0),
                .consonant(9), .vowel(5),
                .consonant(11), .vowel(12)
            ]),
            "안녕 하세요"
        )
    }

    func testSpaceAndPunctuationCommitCurrentSyllable() {
        var input = TypingInputState()
        input.press(.consonant(0))
        input.press(.vowel(0))
        input.press(.space)
        input.press(.literal("."))
        XCTAssertEqual(input.text, "가 .")
    }

    func testResetClearsEverything() {
        var input = TypingInputState()
        input.press(.consonant(0))
        input.press(.vowel(0))
        input.press(.space)
        input.press(.literal("."))
        input.reset()
        XCTAssertEqual(input.text, "")
    }
}
