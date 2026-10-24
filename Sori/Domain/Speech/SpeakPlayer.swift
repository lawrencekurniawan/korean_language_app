import Foundation
import Observation

@MainActor
@Observable
final class SpeakPlayer {
    private let engine: SpeechEngine
    private var requestID = UUID()
    private var text = ""
    private var repeatCount = 1
    private var remainingRepeats = 0
    private var voiceIdentifier = ""
    private var rate = 0.5

    private(set) var isSpeaking = false
    private(set) var speakingText: String?
    private(set) var errorMessage: String?

    init(engine: SpeechEngine = NeuralSpeechEngine()) {
        self.engine = engine
    }

    func prewarm() async {
        await engine.prewarm()
    }

    var voices: [SpeechVoice] {
        engine.voices
    }

    func resolvedVoice(for identifier: String?) -> SpeechVoice? {
        if let identifier, !identifier.isEmpty,
           let match = voices.first(where: { $0.id == identifier }) {
            return match
        }
        return SpeechVoice.best(in: voices)
    }

    var bestVoice: SpeechVoice? {
        SpeechVoice.best(in: voices)
    }

    var hasEnhancedVoice: Bool {
        voices.contains { $0.quality >= .enhanced }
    }

    func play(
        _ text: String,
        repeatCount: Int,
        voiceIdentifier: String,
        rate: Double
    ) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !voices.isEmpty else {
            stop()
            errorMessage = "No Korean voice is installed. Add one in iOS Settings → Accessibility → Spoken Content → Voices."
            return
        }

        stop()
        errorMessage = nil
        requestID = UUID()
        self.text = trimmed
        self.repeatCount = max(0, repeatCount)
        remainingRepeats = self.repeatCount
        self.voiceIdentifier = voiceIdentifier
        self.rate = rate
        isSpeaking = true
        speakingText = trimmed
        speakNext()
    }

    func stop() {
        requestID = UUID()
        isSpeaking = false
        speakingText = nil
        remainingRepeats = 0
        engine.stop()
    }

    func clearError() {
        errorMessage = nil
    }

    private func speakNext() {
        let expectedRequest = requestID
        let started = engine.speak(
            text,
            voiceIdentifier: voiceIdentifier.isEmpty ? nil : voiceIdentifier,
            rate: rate
        ) { [weak self] completed in
            self?.handleCompletion(completed, request: expectedRequest)
        }

        if !started {
            stop()
            errorMessage = "The Korean voice could not start. Check that a Korean voice is installed in iOS Settings."
        }
    }

    private func handleCompletion(_ completed: Bool, request: UUID) {
        guard request == requestID, isSpeaking else { return }
        guard completed else {
            stop()
            return
        }

        if repeatCount == 0 {
            speakNext()
            return
        }

        if remainingRepeats > 1 {
            remainingRepeats -= 1
            speakNext()
            return
        }

        isSpeaking = false
        speakingText = nil
        remainingRepeats = 0
    }
}
