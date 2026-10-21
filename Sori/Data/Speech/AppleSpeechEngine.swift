import AVFoundation
import Foundation

@MainActor
final class AppleSpeechEngine: NSObject, SpeechEngine, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var activeRequest: (id: UUID, completion: @MainActor (Bool) -> Void)?
    private var audioSessionActive = false

    override init() {
        super.init()
        synthesizer.delegate = self
        synthesizer.usesApplicationAudioSession = true
    }

    var voices: [SpeechVoice] {
        Self.koreanVoices
            .map(Self.speechVoice(for:))
            .sorted(by: SpeechVoice.isOrderedBefore)
    }

    func speak(
        _ text: String,
        voiceIdentifier: String?,
        rate: Double,
        completion: @escaping @MainActor (Bool) -> Void
    ) -> Bool {
        guard let voice = resolvedVoice(identifier: voiceIdentifier) else {
            return false
        }

        cancelCurrentUtterance()
        activeRequest = (UUID(), completion)

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = Float(min(max(rate, 0.1), 1.0))
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        activateAudioSession()
        synthesizer.speak(utterance)
        return true
    }

    func stop() {
        cancelCurrentUtterance()
        deactivateAudioSession()
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in
            self?.finishUtterance(completed: true)
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in
            self?.finishUtterance(completed: false)
        }
    }

    private func finishUtterance(completed: Bool) {
        guard let request = activeRequest else { return }
        activeRequest = nil
        deactivateAudioSession()
        request.completion(completed)
    }

    private func cancelCurrentUtterance() {
        activeRequest = nil
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    private func activateAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
            audioSessionActive = true
        } catch {
            audioSessionActive = false
        }
    }

    private func deactivateAudioSession() {
        guard audioSessionActive else { return }
        audioSessionActive = false
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
    }

    private func resolvedVoice(identifier: String?) -> AVSpeechSynthesisVoice? {
        let voices = Self.koreanVoices

        if let identifier, !identifier.isEmpty,
           let match = voices.first(where: { $0.identifier == identifier }) {
            return match
        }

        let ranked = voices.map(Self.speechVoice(for:))
        guard let best = SpeechVoice.best(in: ranked),
              let match = voices.first(where: { $0.identifier == best.id }) else {
            return AVSpeechSynthesisVoice(language: "ko-KR")
        }
        return match
    }

    private static func speechVoice(for voice: AVSpeechSynthesisVoice) -> SpeechVoice {
        SpeechVoice(
            id: voice.identifier,
            name: voice.name,
            language: voice.language,
            quality: quality(for: voice)
        )
    }

    private static var koreanVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("ko") }
    }

    private static func quality(for voice: AVSpeechSynthesisVoice) -> SpeechVoiceQuality {
        switch voice.quality {
        case .premium: .premium
        case .enhanced: .enhanced
        default: .standard
        }
    }
}
