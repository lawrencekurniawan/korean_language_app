import Foundation

enum SpeechVoiceQuality: Int, Sendable, Comparable {
    case standard
    case enhanced
    case premium
    case neural

    static func < (lhs: SpeechVoiceQuality, rhs: SpeechVoiceQuality) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var title: String {
        switch self {
        case .standard: "Standard"
        case .enhanced: "Enhanced"
        case .premium: "Premium"
        case .neural: "Neural"
        }
    }
}

struct SpeechVoice: Identifiable, Sendable, Equatable {
    let id: String
    let name: String
    let language: String
    let quality: SpeechVoiceQuality

    var displayName: String {
        "\(name) · \(quality.title)"
    }

    var isYuna: Bool {
        name.localizedCaseInsensitiveContains("Yuna")
            || id.localizedCaseInsensitiveContains("Yuna")
    }

    /// Picks the best voice installed on this device. Quality wins first, so the
    /// bundled neural voice is preferred, then a downloaded Premium or Enhanced
    /// Apple voice. Yuna is deliberately pushed down on ties because the
    /// standard Yuna voice is the least natural Korean option on most devices.
    static func best(in voices: [SpeechVoice]) -> SpeechVoice? {
        voices.sorted(by: isOrderedBefore).first
    }

    static func isOrderedBefore(_ lhs: SpeechVoice, _ rhs: SpeechVoice) -> Bool {
        if lhs.quality != rhs.quality {
            return lhs.quality > rhs.quality
        }
        if lhs.isYuna != rhs.isYuna {
            return !lhs.isYuna
        }
        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }
}

/// The speech layer is deliberately small so Apple's synthesizer can be
/// replaced by an on-device neural engine without changing the Speak UI.
@MainActor
protocol SpeechEngine: AnyObject {
    var voices: [SpeechVoice] { get }
    func speak(
        _ text: String,
        voiceIdentifier: String?,
        rate: Double,
        completion: @escaping @MainActor (Bool) -> Void
    ) -> Bool
    func stop()
    func prewarm() async
}

extension SpeechEngine {
    func prewarm() async {}
}
