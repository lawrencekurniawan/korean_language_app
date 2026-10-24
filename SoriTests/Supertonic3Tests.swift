import XCTest
@testable import Sori

final class Supertonic3Tests: XCTestCase {
    func testBundledModelLoadsAndSynthesizesKorean() async throws {
        let manager = Supertonic3Manager()
        let samples = try await manager.synthesize(
            text: "안녕하세요",
            voice: "F1",
            speed: 1.0,
            totalSteps: 4
        )

        XCTAssertGreaterThan(samples.count, 4_000)
        XCTAssertTrue(samples.contains { abs($0) > 0.0001 })
        let sampleRate = await manager.sampleRate()
        XCTAssertEqual(sampleRate, 44_100)
    }

    func testIsolatedHangeulJamoProducesAudio() async throws {
        let manager = Supertonic3Manager()
        for text in ["ㅏ", "가", "나"] {
            let samples = try await manager.synthesize(
                text: text,
                voice: "F1",
                speed: 1.0,
                totalSteps: 4
            )
            let peak = samples.map { abs($0) }.max() ?? 0
            XCTAssertGreaterThan(samples.count, 2_000, text)
            XCTAssertGreaterThan(peak, 0.0005, text)
        }
    }

    @MainActor
    func testNeuralEnginePlaysBundledVoiceAndCompletes() async {
        let engine = NeuralSpeechEngine()
        XCTAssertTrue(engine.voices.contains { $0.id == "supertonic:F1" })

        let finished = expectation(description: "playback finished")
        var completionValue: Bool?
        let started = engine.speak(
            "안녕하세요",
            voiceIdentifier: "supertonic:F1",
            rate: 0.5
        ) { completed in
            completionValue = completed
            finished.fulfill()
        }

        XCTAssertTrue(started)
        await fulfillment(of: [finished], timeout: 30)
        XCTAssertEqual(completionValue, true)
    }

    func testPCMWAVWriterProducesStandardHeader() {
        let data = PCMWAVWriter.data(samples: [0, 0.5, -0.5], sampleRate: 44_100)

        XCTAssertEqual(data.count, 44 + 6)
        XCTAssertEqual(String(data: data.prefix(4), encoding: .ascii), "RIFF")
        XCTAssertEqual(String(data: data[8..<12], encoding: .ascii), "WAVE")
        XCTAssertEqual(String(data: data[36..<40], encoding: .ascii), "data")
    }

    func testUnicodeProcessorWrapsKoreanText() {
        let processed = Supertonic3UnicodeProcessor.preprocess(
            text: "안녕하세요",
            lang: "ko"
        )

        XCTAssertTrue(processed.hasPrefix("<ko>"))
        XCTAssertTrue(processed.hasSuffix("</ko>"))
    }
}
