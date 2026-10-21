import XCTest
@testable import Sori

final class KoreanTextTests: XCTestCase {
    func testWordsDropWhitespaceAndPunctuationOnlyTokens() {
        let text = "  안녕하세요   만나서\n반갑습니다. 백한우 : 하얀 한우이다. "
        XCTAssertEqual(
            KoreanText.words(in: text),
            ["안녕하세요", "만나서", "반갑습니다.", "백한우", "하얀", "한우이다."]
        )
        XCTAssertEqual(KoreanText.eojeolCount("백한우 : 하얀 한우이다."), 3)
    }

    func testContainsHangul() {
        XCTAssertTrue(KoreanText.containsHangul("안녕"))
        XCTAssertFalse(KoreanText.containsHangul("Hello 123"))
        XCTAssertFalse(KoreanText.containsHangul("漢字"))
    }

    func testSpeakablePhraseLimit() {
        XCTAssertTrue(KoreanText.isSpeakablePhrase("백한우 : 하얀 한우이다."))
        XCTAssertFalse(KoreanText.isSpeakablePhrase("가 나 다 라 마 바 사 아 자 차 카."))
        XCTAssertFalse(KoreanText.isSpeakablePhrase("문장이 끝나지 않음"))
        XCTAssertFalse(KoreanText.isSpeakablePhrase("Hello."))
        XCTAssertFalse(KoreanText.isSpeakablePhrase(""))
    }

    func testNaturalPhraseRejectsNotationHeavyText() {
        XCTAssertTrue(KoreanText.isNaturalPhrase("하고 제 맘대로 분부를 한다."))
        XCTAssertFalse(KoreanText.isNaturalPhrase("백한우 : 하얀 한우이다."))
        XCTAssertFalse(
            KoreanText.isNaturalPhrase("②자음앞에 있는 때는 《ㄴ》받침글자로 적는다.")
        )
        XCTAssertFalse(KoreanText.isNaturalPhrase("2024년의 기록이다."))
    }
}

@MainActor
final class SpeakPlayerTests: XCTestCase {
    func testPlayPassesVoiceRateAndText() {
        let engine = MockSpeechEngine()
        let player = SpeakPlayer(engine: engine)

        player.play(
            "  안녕하세요.  ",
            repeatCount: 1,
            voiceIdentifier: "yuna",
            rate: 0.4
        )

        XCTAssertTrue(player.isSpeaking)
        XCTAssertEqual(player.speakingText, "안녕하세요.")
        XCTAssertEqual(engine.requests.count, 1)
        XCTAssertEqual(engine.requests[0].text, "안녕하세요.")
        XCTAssertEqual(engine.requests[0].voiceIdentifier, "yuna")
        XCTAssertEqual(engine.requests[0].rate, 0.4, accuracy: 0.001)
    }

    func testRepeatCountRepeatsThenStops() {
        let engine = MockSpeechEngine()
        let player = SpeakPlayer(engine: engine)

        player.play("안녕하세요.", repeatCount: 3, voiceIdentifier: "", rate: 0.5)
        XCTAssertEqual(engine.requests.count, 1)

        engine.completeLast(true)
        XCTAssertEqual(engine.requests.count, 2)
        XCTAssertTrue(player.isSpeaking)

        engine.completeLast(true)
        XCTAssertEqual(engine.requests.count, 3)
        XCTAssertTrue(player.isSpeaking)

        engine.completeLast(true)
        XCTAssertEqual(engine.requests.count, 3)
        XCTAssertFalse(player.isSpeaking)
        XCTAssertNil(player.speakingText)
    }

    func testZeroRepeatLoopsUntilStopped() {
        let engine = MockSpeechEngine()
        let player = SpeakPlayer(engine: engine)

        player.play("안녕하세요.", repeatCount: 0, voiceIdentifier: "", rate: 0.5)
        engine.completeLast(true)
        engine.completeLast(true)

        XCTAssertEqual(engine.requests.count, 3)
        XCTAssertTrue(player.isSpeaking)

        player.stop()
        XCTAssertFalse(player.isSpeaking)
        XCTAssertNil(player.speakingText)
    }

    func testStopPreventsLateCompletionFromRestarting() {
        let engine = MockSpeechEngine()
        let player = SpeakPlayer(engine: engine)

        player.play("안녕하세요.", repeatCount: 3, voiceIdentifier: "", rate: 0.5)
        player.stop()
        engine.completeLast(true)

        XCTAssertEqual(engine.requests.count, 1)
        XCTAssertFalse(player.isSpeaking)
    }

    func testCancelledUtteranceStopsPlayback() {
        let engine = MockSpeechEngine()
        let player = SpeakPlayer(engine: engine)

        player.play("안녕하세요.", repeatCount: 3, voiceIdentifier: "", rate: 0.5)
        engine.completeLast(false)

        XCTAssertEqual(engine.requests.count, 1)
        XCTAssertFalse(player.isSpeaking)
        XCTAssertNil(player.speakingText)
    }

    func testMissingVoiceReportsAnError() {
        let engine = MockSpeechEngine()
        engine.voices = []
        let player = SpeakPlayer(engine: engine)

        player.play("안녕하세요.", repeatCount: 1, voiceIdentifier: "", rate: 0.5)

        XCTAssertFalse(player.isSpeaking)
        XCTAssertTrue(engine.requests.isEmpty)
        XCTAssertNotNil(player.errorMessage)
    }

    func testUnableToStartReportsAnError() {
        let engine = MockSpeechEngine()
        engine.shouldStart = false
        let player = SpeakPlayer(engine: engine)

        player.play("안녕하세요.", repeatCount: 1, voiceIdentifier: "", rate: 0.5)

        XCTAssertFalse(player.isSpeaking)
        XCTAssertNotNil(player.errorMessage)
    }

    func testResolvedVoicePrefersQualityOverYuna() {
        let engine = MockSpeechEngine()
        engine.voices = [
            SpeechVoice(id: "yuna", name: "Yuna", language: "ko-KR", quality: .standard),
            SpeechVoice(id: "other", name: "Minsu", language: "ko-KR", quality: .enhanced)
        ]
        let player = SpeakPlayer(engine: engine)

        XCTAssertEqual(player.resolvedVoice(for: nil)?.id, "other")
        XCTAssertEqual(player.bestVoice?.id, "other")
        XCTAssertTrue(player.hasEnhancedVoice)
    }

    func testResolvedVoicePrefersYunaOnQualityTie() {
        let engine = MockSpeechEngine()
        engine.voices = [
            SpeechVoice(id: "other", name: "Minsu", language: "ko-KR", quality: .enhanced),
            SpeechVoice(id: "yuna", name: "Yuna", language: "ko-KR", quality: .enhanced)
        ]
        let player = SpeakPlayer(engine: engine)

        XCTAssertEqual(player.resolvedVoice(for: nil)?.id, "yuna")
    }

    func testResolvedVoicePrefersPremiumOverEnhanced() {
        let engine = MockSpeechEngine()
        engine.voices = [
            SpeechVoice(id: "yuna", name: "Yuna", language: "ko-KR", quality: .enhanced),
            SpeechVoice(id: "premium", name: "Minsu", language: "ko-KR", quality: .premium)
        ]
        let player = SpeakPlayer(engine: engine)

        XCTAssertEqual(player.resolvedVoice(for: nil)?.id, "premium")
    }

    func testResolvedVoiceHonoursExplicitChoiceAndFallsBack() {
        let engine = MockSpeechEngine()
        engine.voices = [
            SpeechVoice(id: "other", name: "Minsu", language: "ko-KR", quality: .enhanced),
            SpeechVoice(id: "yuna", name: "Yuna", language: "ko-KR", quality: .standard)
        ]
        let player = SpeakPlayer(engine: engine)

        XCTAssertEqual(player.resolvedVoice(for: "yuna")?.id, "yuna")
        XCTAssertEqual(player.resolvedVoice(for: "missing")?.id, "other")
    }
}

@MainActor
private final class MockSpeechEngine: SpeechEngine {
    struct Request {
        let text: String
        let voiceIdentifier: String?
        let rate: Double
    }

    var voices: [SpeechVoice] = [
        SpeechVoice(id: "yuna", name: "Yuna", language: "ko-KR", quality: .enhanced)
    ]
    var shouldStart = true
    private(set) var requests: [Request] = []
    private var completions: [@MainActor (Bool) -> Void] = []

    func speak(
        _ text: String,
        voiceIdentifier: String?,
        rate: Double,
        completion: @escaping @MainActor (Bool) -> Void
    ) -> Bool {
        guard shouldStart else { return false }
        requests.append(Request(text: text, voiceIdentifier: voiceIdentifier, rate: rate))
        completions.append(completion)
        return true
    }

    func stop() {}

    func completeLast(_ completed: Bool) {
        guard !completions.isEmpty else { return }
        completions.removeLast()(completed)
    }
}
