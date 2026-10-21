import XCTest
@testable import Sori

final class CorpusTests: XCTestCase {
    func testNormalizerCanonicalisesWhitespace() {
        let result = TextNormalizer.normalize("  안녕하세요.\r\n\r\n\r\n오늘은\u{00A0}날씨가 좋아요.  ")
        XCTAssertEqual(result, "안녕하세요.\n\n오늘은 날씨가 좋아요.")
    }

    func testHashingIgnoresWhitespaceAndCase() {
        XCTAssertEqual(
            TextNormalizer.normalizedForHash("안녕 하세요"),
            TextNormalizer.normalizedForHash("안녕하세요")
        )
        XCTAssertEqual(
            TextNormalizer.normalizedForHash("Hello World"),
            TextNormalizer.normalizedForHash("hello   world")
        )
        XCTAssertEqual(TextNormalizer.sha256("소리").count, 64)
    }

    func testCPMCountsOnlyNonWhitespaceCharacters() {
        XCTAssertEqual(TextNormalizer.nonWhitespaceCount("안녕 하세요.\n반갑습니다."), 12)
        XCTAssertEqual(TextNormalizer.eojeolCount("안녕 하세요.\n반갑습니다."), 3)
    }

    func testHangulRatio() {
        XCTAssertEqual(TextNormalizer.hangulRatio("안녕하세요"), 1.0, accuracy: 0.001)
        XCTAssertGreaterThan(TextNormalizer.hangulRatio("안녕하세요 Hello"), 0.49)
        XCTAssertEqual(TextNormalizer.hangulRatio("Hello"), 0.0, accuracy: 0.001)
        XCTAssertTrue(TextNormalizer.containsHangul("ABC 한글"))
        XCTAssertFalse(TextNormalizer.containsHangul("ABC"))
    }

    func testSentenceSegmenterSplitsKoreanPunctuation() {
        let sentences = SentenceSegmenter.sentences(
            from: "안녕하세요. 만나서 반갑습니다! 오늘 날씨가 좋네요?"
        )
        XCTAssertEqual(sentences, [
            "안녕하세요.",
            "만나서 반갑습니다!",
            "오늘 날씨가 좋네요?"
        ])
    }

    func testSentenceSegmenterKeepsDecimalTogether() {
        let sentences = SentenceSegmenter.sentences(
            from: "그는 3.5킬로미터를 달렸다. 그리고 잠시 쉬었다."
        )
        XCTAssertEqual(sentences.count, 2)
        XCTAssertTrue(sentences[0].contains("3.5"))
    }

    func testSentenceSegmenterHandlesQuotes() {
        let sentences = SentenceSegmenter.sentences(
            from: "“밥 먹었어?”라고 물었다. “네.”라고 대답했다."
        )
        XCTAssertEqual(sentences.count, 2)
        XCTAssertTrue(sentences[0].hasSuffix("물었다."))
    }

    func testSentenceSegmenterJoinsSingleNewlines() {
        let sentences = SentenceSegmenter.sentences(
            from: "첫 문장입니다.\n둘째 문장입니다."
        )
        XCTAssertEqual(sentences, ["첫 문장입니다.", "둘째 문장입니다."])
    }

    func testSentenceSegmenterSplitsVeryLongText() {
        let long = String(repeating: "한국어를 공부하는 것은 즐겁습니다, ", count: 20) + "끝."
        let sentences = SentenceSegmenter.sentences(from: long)
        XCTAssertGreaterThan(sentences.count, 1)
        XCTAssertTrue(sentences.allSatisfy { $0.count <= 220 })
    }

    func testDifficultyEstimatorIsDeterministicAndBounded() {
        let low = DifficultyEstimator.estimate("안녕하세요.")
        let high = DifficultyEstimator.estimate(
            "그러나 경제적·사회적 조건이 서로 다른 사람들이 동일한 제도적 틀 안에서 협력하려면, 상당히 복잡한 절차와 오랜 시간이 필요하다."
        )
        XCTAssertEqual(low, DifficultyEstimator.estimate("안녕하세요."))
        XCTAssertTrue((1...6).contains(low))
        XCTAssertTrue((1...6).contains(high))
        XCTAssertGreaterThanOrEqual(high, low)
    }

    func testSRTParsingRemovesTagsAndSDH() throws {
        let srt = """
        1
        00:00:01,000 --> 00:00:03,500
        <i>안녕하세요.</i>

        2
        00:00:04,000 --> 00:00:06,000
        [음악] 오늘은 날씨가 좋습니다.
        """
        let cues = SubtitleImporter.parse(srt, format: .srt)
        XCTAssertEqual(cues.count, 2)
        XCTAssertEqual(SubtitleImporter.cleanCueText(cues[0].text), "안녕하세요.")
        XCTAssertEqual(SubtitleImporter.cleanCueText(cues[1].text), "오늘은 날씨가 좋습니다.")

        let data = srt.data(using: .utf8)!
        let document = try SubtitleImporter.document(
            from: data,
            title: "Test",
            format: .srt
        )
        XCTAssertTrue(document.text.contains("안녕하세요."))
        XCTAssertFalse(document.text.contains("<i>"))
        XCTAssertFalse(document.text.contains("[음악]"))
    }

    func testVTTParsingHandlesHeader() {
        let vtt = """
        WEBVTT

        00:00:01.000 --> 00:00:03.000
        안녕하세요.

        00:00:04.000 --> 00:00:06.000
        반갑습니다.
        """
        let cues = SubtitleImporter.parse(vtt, format: .vtt)
        XCTAssertEqual(cues.count, 2)
        XCTAssertEqual(cues[0].start, 1.0, accuracy: 0.001)
        XCTAssertEqual(cues[0].end, 3.0, accuracy: 0.001)
    }

    func testSubtitleRejectsTextWithoutKorean() {
        let srt = """
        1
        00:00:01,000 --> 00:00:03,500
        Hello there.
        """
        XCTAssertThrowsError(
            try SubtitleImporter.document(
                from: srt.data(using: .utf8)!,
                title: "Test",
                format: .srt
            )
        ) { error in
            XCTAssertEqual(error as? ImportError, .noSubtitles)
        }
    }
}
