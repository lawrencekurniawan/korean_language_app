import XCTest
@testable import Sori

final class TypingMetricsTests: XCTestCase {
    func testNetCPMCountsOnlyCorrectCharacters() {
        let metrics = TypingMetrics.calculate(
            target: "안녕하세요",
            input: "안녕하세여",
            completedCorrectCharacters: 0,
            completedTypedCharacters: 0,
            elapsedSeconds: 60
        )

        XCTAssertEqual(metrics.correctCharacters, 4)
        XCTAssertEqual(metrics.typedCharacters, 5)
        XCTAssertEqual(metrics.errorCharacters, 1)
        XCTAssertEqual(metrics.netCPM, 4, accuracy: 0.001)
        XCTAssertEqual(metrics.grossCPM, 5, accuracy: 0.001)
        XCTAssertEqual(metrics.accuracy, 0.8, accuracy: 0.001)
    }

    func testSpacesAreExcludedFromCPM() {
        let metrics = TypingMetrics.calculate(
            target: "안녕 하세요",
            input: "안녕 하세요",
            completedCorrectCharacters: 0,
            completedTypedCharacters: 0,
            elapsedSeconds: 60
        )

        XCTAssertEqual(metrics.correctCharacters, 5)
        XCTAssertEqual(metrics.typedCharacters, 5)
        XCTAssertEqual(metrics.netCPM, 5, accuracy: 0.001)
        XCTAssertEqual(metrics.accuracy, 1, accuracy: 0.001)
    }

    func testPartialSentenceIsCountedImmediately() {
        let metrics = TypingMetrics.calculate(
            target: "가나",
            input: "가",
            completedCorrectCharacters: 0,
            completedTypedCharacters: 0,
            elapsedSeconds: 60
        )

        XCTAssertEqual(metrics.correctCharacters, 1)
        XCTAssertEqual(metrics.typedCharacters, 1)
        XCTAssertEqual(metrics.errorCharacters, 0)
        XCTAssertEqual(metrics.netCPM, 1, accuracy: 0.001)
    }

    func testExtraCharactersAreErrors() {
        let metrics = TypingMetrics.calculate(
            target: "가나",
            input: "가나다",
            completedCorrectCharacters: 0,
            completedTypedCharacters: 0,
            elapsedSeconds: 60
        )

        XCTAssertEqual(metrics.correctCharacters, 2)
        XCTAssertEqual(metrics.typedCharacters, 3)
        XCTAssertEqual(metrics.errorCharacters, 1)
        XCTAssertEqual(metrics.accuracy, 2.0 / 3.0, accuracy: 0.001)
    }

    func testCompletedSentencesAddToLiveMetrics() {
        let metrics = TypingMetrics.calculate(
            target: "가나",
            input: "가",
            completedCorrectCharacters: 10,
            completedTypedCharacters: 12,
            elapsedSeconds: 60
        )

        XCTAssertEqual(metrics.correctCharacters, 11)
        XCTAssertEqual(metrics.typedCharacters, 13)
        XCTAssertEqual(metrics.errorCharacters, 2)
        XCTAssertEqual(metrics.netCPM, 11, accuracy: 0.001)
        XCTAssertEqual(metrics.grossCPM, 13, accuracy: 0.001)
        XCTAssertEqual(metrics.accuracy, 11.0 / 13.0, accuracy: 0.001)
    }

    func testWhitespaceMismatchesAreReportedAsErrors() {
        let metrics = TypingMetrics.calculate(
            target: "가 나",
            input: "가  나",
            completedCorrectCharacters: 0,
            completedTypedCharacters: 0,
            elapsedSeconds: 60
        )

        // The extra space shifts the final character, so only the first
        // character is in the correct position. The error count still includes
        // both the shifted character and the extra whitespace.
        XCTAssertEqual(metrics.correctCharacters, 1)
        XCTAssertEqual(metrics.typedCharacters, 2)
        XCTAssertEqual(metrics.errorCharacters, 2)
    }

    func testWrongOrderDoesNotCountAsCorrect() {
        let metrics = TypingMetrics.calculate(
            target: "가나",
            input: "나가",
            completedCorrectCharacters: 0,
            completedTypedCharacters: 0,
            elapsedSeconds: 60
        )

        XCTAssertEqual(metrics.correctCharacters, 0)
        XCTAssertEqual(metrics.typedCharacters, 2)
        XCTAssertEqual(metrics.errorCharacters, 2)
        XCTAssertEqual(metrics.accuracy, 0, accuracy: 0.001)
    }

    func testNoInputProducesZeroMetrics() {
        let metrics = TypingMetrics.calculate(
            target: "가나",
            input: "",
            completedCorrectCharacters: 0,
            completedTypedCharacters: 0,
            elapsedSeconds: 30
        )

        XCTAssertEqual(metrics.correctCharacters, 0)
        XCTAssertEqual(metrics.typedCharacters, 0)
        XCTAssertEqual(metrics.errorCharacters, 0)
        XCTAssertEqual(metrics.netCPM, 0)
        XCTAssertEqual(metrics.accuracy, 0)
    }
}
