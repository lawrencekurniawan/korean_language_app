import AVFoundation
import CryptoKit
import Foundation

/// The default speech engine: bundled Supertonic-3 neural Korean voices with
/// Apple's AVSpeechSynthesizer as an automatic fallback.
@MainActor
final class NeuralSpeechEngine: NSObject, SpeechEngine, AVAudioPlayerDelegate {
    private let apple = AppleSpeechEngine()
    private let manager: Supertonic3Manager
    private var player: AVAudioPlayer?
    private var synthesisTask: Task<Void, Never>?
    private var activeRequest: (id: UUID, completion: @MainActor (Bool) -> Void)?
    private var audioSessionActive = false

    private static let neuralVoices: [SpeechVoice] = [
        SpeechVoice(id: "supertonic:F1", name: "Sori Female 1", language: "ko-KR", quality: .neural),
        SpeechVoice(id: "supertonic:F2", name: "Sori Female 2", language: "ko-KR", quality: .neural),
        SpeechVoice(id: "supertonic:F3", name: "Sori Female 3", language: "ko-KR", quality: .neural),
        SpeechVoice(id: "supertonic:M1", name: "Sori Male 1", language: "ko-KR", quality: .neural),
    ]

    init(manager: Supertonic3Manager = Supertonic3Manager()) {
        self.manager = manager
        super.init()
    }

    var voices: [SpeechVoice] {
        (Self.neuralVoices + apple.voices).sorted(by: SpeechVoice.isOrderedBefore)
    }

    func prewarm() async {
        try? await manager.prepare()
    }

    func speak(
        _ text: String,
        voiceIdentifier: String?,
        rate: Double,
        completion: @escaping @MainActor (Bool) -> Void
    ) -> Bool {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let voice = resolvedVoice(identifier: voiceIdentifier) else {
            return false
        }

        stop()
        let request = UUID()
        activeRequest = (request, completion)

        if voice.quality == .neural {
            speakNeural(text, voice: voice, rate: rate, request: request)
        } else {
            startApple(text, voiceIdentifier: voice.id, rate: rate, request: request)
        }
        return true
    }

    func stop() {
        synthesisTask?.cancel()
        synthesisTask = nil
        player?.stop()
        player = nil
        apple.stop()
        activeRequest = nil
        deactivateAudioSession()
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            self?.finishPlayback(successfully: flag)
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor [weak self] in
            self?.finishPlayback(successfully: false)
        }
    }

    private func speakNeural(
        _ text: String,
        voice: SpeechVoice,
        rate: Double,
        request: UUID
    ) {
        let voiceName = String(voice.id.dropFirst("supertonic:".count))
        let speed = min(max(rate / 0.5, 0.6), 1.45)

        synthesisTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.manager.prepare()
                guard !Task.isCancelled, self.activeRequest?.id == request else { return }

                let cacheURL = try self.cacheURL(
                    text: text,
                    voiceName: voiceName,
                    speed: speed
                )

                if FileManager.default.fileExists(atPath: cacheURL.path) {
                    try self.play(cacheURL, request: request, rate: rate)
                    return
                }

                let samples = try await self.manager.synthesize(
                    text: text,
                    language: "ko",
                    voice: voiceName,
                    speed: speed
                )
                guard !Task.isCancelled, self.activeRequest?.id == request else { return }

                let sampleRate = await self.manager.sampleRate()
                let data = PCMWAVWriter.data(samples: samples, sampleRate: sampleRate)
                try data.write(to: cacheURL, options: .atomic)
                try self.play(cacheURL, request: request, rate: rate)
            } catch {
                guard !Task.isCancelled, self.activeRequest?.id == request else { return }
                self.startApple(text, voiceIdentifier: nil, rate: rate, request: request)
            }
        }
    }

    private func play(_ url: URL, request: UUID, rate: Double) throws {
        guard activeRequest?.id == request else { return }
        activateAudioSession()
        let player = try AVAudioPlayer(contentsOf: url)
        player.delegate = self
        player.enableRate = false
        player.volume = 1.0
        guard player.prepareToPlay(), player.play() else {
            throw NeuralSpeechError.playbackFailed
        }
        self.player = player
    }

    private func startApple(
        _ text: String,
        voiceIdentifier: String?,
        rate: Double,
        request: UUID
    ) {
        let started = apple.speak(
            text,
            voiceIdentifier: voiceIdentifier,
            rate: rate
        ) { [weak self] completed in
            self?.finish(request: request, completed: completed)
        }
        if !started {
            finish(request: request, completed: false)
        }
    }

    private func finishPlayback(successfully: Bool) {
        guard let request = activeRequest?.id else { return }
        if !successfully {
            player = nil
            finish(request: request, completed: false)
            return
        }
        player = nil
        finish(request: request, completed: true)
    }

    private func finish(request: UUID, completed: Bool) {
        guard let activeRequest, activeRequest.id == request else { return }
        self.activeRequest = nil
        synthesisTask = nil
        player = nil
        deactivateAudioSession()
        activeRequest.completion(completed)
    }

    private func resolvedVoice(identifier: String?) -> SpeechVoice? {
        let all = voices
        if let identifier, !identifier.isEmpty,
           let match = all.first(where: { $0.id == identifier }) {
            return match
        }
        return SpeechVoice.best(in: all)
    }

    private func cacheURL(text: String, voiceName: String, speed: Double) throws -> URL {
        let key = "\(voiceName)|\(String(format: "%.3f", speed))|\(text)"
        let digest = SHA256.hash(data: Data(key.utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined() + ".wav"

        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NeuralSpeech", isDirectory: true)
        try FileManager.default.createDirectory(
            at: base,
            withIntermediateDirectories: true
        )
        return base.appendingPathComponent(name)
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
}

private enum NeuralSpeechError: Error {
    case playbackFailed
}
