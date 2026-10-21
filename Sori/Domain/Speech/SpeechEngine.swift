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
