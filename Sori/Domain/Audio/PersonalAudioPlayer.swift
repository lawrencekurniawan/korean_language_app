import AVFoundation
import Foundation
import Observation

@MainActor
@Observable
final class PersonalAudioPlayer {
    @ObservationIgnored private let delegate = AudioPlayerDelegate()
    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var sessionActive = false

    private(set) var currentTrackID: String?
    private(set) var isPlaying = false
    private(set) var errorMessage: String?

    init() {
        delegate.owner = self
    }

    func play(_ track: PersonalAudioTrack) {
        stop()

        do {
            let player = try AVAudioPlayer(contentsOf: track.url)
            player.delegate = delegate
            player.prepareToPlay()
            activateSession()
            guard player.play() else {
                throw AudioPlayerError.couldNotStart
            }
            self.player = player
            currentTrackID = track.id
            isPlaying = true
            errorMessage = nil
        } catch {
            stop()
            errorMessage = "This audio file could not be played. \(error.localizedDescription)"
        }
    }

    func toggle(_ track: PersonalAudioTrack) {
        if currentTrackID == track.id, isPlaying {
            stop()
        } else {
            play(track)
        }
    }

    func stop() {
        player?.stop()
        player = nil
        currentTrackID = nil
        isPlaying = false
        deactivateSession()
    }

    func clearError() {
        errorMessage = nil
    }

    fileprivate func handleFinished() {
        player = nil
        currentTrackID = nil
        isPlaying = false
        deactivateSession()
    }

    private func activateSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
            sessionActive = true
        } catch {
            sessionActive = false
        }
    }

    private func deactivateSession() {
        guard sessionActive else { return }
        sessionActive = false
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
    }
}

private enum AudioPlayerError: LocalizedError {
    case couldNotStart

    var errorDescription: String? {
        "The audio session did not start."
    }
}

@MainActor
private final class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    weak var owner: PersonalAudioPlayer?

    nonisolated func audioPlayerDidFinishPlaying(
        _ player: AVAudioPlayer,
        successfully flag: Bool
    ) {
        Task { @MainActor [weak self] in
            self?.owner?.handleFinished()
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(
        _ player: AVAudioPlayer,
        error: Error?
    ) {
        Task { @MainActor [weak self] in
            self?.owner?.handleFinished()
        }
    }
}
