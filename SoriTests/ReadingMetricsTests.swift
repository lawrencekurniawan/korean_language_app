import XCTest
@testable import Sori

final class ReadingMetricsTests: XCTestCase {
    private let sentences = [
        PracticeSentence(id: 1, text: "안녕하세요", difficulty: 1),
        PracticeSentence(id: 2, text: "오늘은 날씨가 좋습니다", difficulty: 1),
        PracticeSentence(id: 3, text: "저는 한국어를 공부해요", difficulty: 1)
    ]

    func testCPMUsesNonWhitespaceCharactersOfCompletedSentences() {
        let metrics = ReadingMetrics.calculate(
            sentences: sentences,
            completedCount: 2,
            elapsedSeconds: 60
        )

        XCTAssertEqual(metrics.completedCharacters, 15)
        XCTAssertEqual(metrics.completedSentences, 2)
        XCTAssertEqual(metrics.cpm, 15, accuracy: 0.001)
    }

    func testCPMUsesFurthestCompletedPrefixAndElapsedMinutes() {
        let metrics = ReadingMetrics.calculate(
            sentences: sentences,
            completedCount: 3,
            elapsedSeconds: 120
        )

        XCTAssertEqual(metrics.completedCharacters, 25)
        XCTAssertEqual(metrics.completedSentences, 3)
        XCTAssertEqual(metrics.cpm, 12.5, accuracy: 0.001)
    }

    func testCPMClampsCompletedCountToAvailableSentences() {
        let metrics = ReadingMetrics.calculate(
            sentences: sentences,
            completedCount: 99,
            elapsedSeconds: 60
        )

        XCTAssertEqual(metrics.completedCharacters, 25)
        XCTAssertEqual(metrics.completedSentences, 3)
    }

    func testNoCompletedSentencesProducesZeroCPM() {
        let metrics = ReadingMetrics.calculate(
            sentences: sentences,
            completedCount: 0,
            elapsedSeconds: 30
        )

        XCTAssertEqual(metrics.completedCharacters, 0)
        XCTAssertEqual(metrics.completedSentences, 0)
        XCTAssertEqual(metrics.cpm, 0, accuracy: 0.001)
    }
}
