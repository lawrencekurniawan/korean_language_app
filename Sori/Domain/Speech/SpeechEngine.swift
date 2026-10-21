import Foundation

enum SpeechVoiceQuality: Int, Sendable, Comparable {
    case standard
    case enhanced
    case premium

    static func < (lhs: SpeechVoiceQuality, rhs: SpeechVoiceQuality) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var title: String {
        switch self {
        case .standard: "Standard"
        case .enhanced: "Enhanced"
        case .premium: "Premium"
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

    /// Picks the best voice installed on this device. Quality wins first, so a
    /// downloaded Enhanced or Premium voice is never passed over for a Standard
    /// one; Yuna breaks ties, then the name keeps the choice stable.
    static func best(in voices: [SpeechVoice]) -> SpeechVoice? {
        voices.sorted(by: isOrderedBefore).first
    }

    static func isOrderedBefore(_ lhs: SpeechVoice, _ rhs: SpeechVoice) -> Bool {
        if lhs.quality != rhs.quality {
            return lhs.quality > rhs.quality
        }
        if lhs.isYuna != rhs.isYuna {
            return lhs.isYuna
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
}
