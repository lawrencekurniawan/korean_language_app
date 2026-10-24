import Foundation
import Observation

// MARK: - Enums

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case english
    case vietnamese

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .english: "English"
        case .vietnamese: "Tiếng Việt"
        }
    }
}

enum ExplanationLanguage: String, CaseIterable, Identifiable, Sendable {
    case english
    case vietnamese

    var id: String { rawValue }

    var title: String {
        switch self {
        case .english: "English"
        case .vietnamese: "Tiếng Việt"
        }
    }
}

enum KeyboardMode: String, CaseIterable, Identifiable, Sendable {
    case builtIn
    case system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .builtIn: "Built-in 2-set"
        case .system: "System keyboard"
        }
    }
}

// MARK: - Settings

@MainActor
@Observable
final class SettingsStore {
    @ObservationIgnored private let defaults: UserDefaults

    // Appearance
    var appearance: AppAppearance {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) }
    }

    // Practice
    var readingDuration: Int {
        didSet { defaults.set(readingDuration, forKey: Keys.readingDuration) }
    }
    var typingDuration: Int {
        didSet { defaults.set(typingDuration, forKey: Keys.typingDuration) }
    }

    // Typography
    var readingFontSize: Double {
        didSet { defaults.set(readingFontSize, forKey: Keys.readingFontSize) }
    }
    var typingFontSize: Double {
        didSet { defaults.set(typingFontSize, forKey: Keys.typingFontSize) }
    }
    var speakFontSize: Double {
        didSet { defaults.set(speakFontSize, forKey: Keys.speakFontSize) }
    }

    // Language
    var appLanguage: AppLanguage {
        didSet { defaults.set(appLanguage.rawValue, forKey: Keys.appLanguage) }
    }
    var explanationLanguage: ExplanationLanguage {
        didSet { defaults.set(explanationLanguage.rawValue, forKey: Keys.explanationLanguage) }
    }

    // Splash
    var splashEnabled: Bool {
        didSet { defaults.set(splashEnabled, forKey: Keys.splashEnabled) }
    }
    var splashAutoCloseSeconds: Int {
        didSet { defaults.set(splashAutoCloseSeconds, forKey: Keys.splashAutoCloseSeconds) }
    }

    // Typing
    var keyboardMode: KeyboardMode {
        didSet { defaults.set(keyboardMode.rawValue, forKey: Keys.keyboardMode) }
    }

    // Speak
    var speakAutoMode: Bool {
        didSet { defaults.set(speakAutoMode, forKey: Keys.speakAutoMode) }
    }
    var voiceIdentifier: String {
        didSet { defaults.set(voiceIdentifier, forKey: Keys.voiceIdentifier) }
    }
    var speechRate: Double {
        didSet { defaults.set(speechRate, forKey: Keys.speechRate) }
    }
    /// 0 means repeat indefinitely.
    var repeatCount: Int {
        didSet { defaults.set(repeatCount, forKey: Keys.repeatCount) }
    }

    // Library
    let libraryLimitBytes: Int = 2_000_000

    // Backup
    var lastBackupAt: Date? {
        didSet { defaults.set(lastBackupAt, forKey: Keys.lastBackupAt) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        appearance = AppAppearance(
            rawValue: defaults.string(forKey: Keys.appearance) ?? ""
        ) ?? .system

        readingDuration = Self.int(defaults, Keys.readingDuration, default: 60, range: 15...300)
        typingDuration = Self.int(defaults, Keys.typingDuration, default: 60, range: 15...300)

        readingFontSize = Self.double(defaults, Keys.readingFontSize, default: 30, range: 18...44)
        typingFontSize = Self.double(defaults, Keys.typingFontSize, default: 24, range: 18...44)
        speakFontSize = Self.double(defaults, Keys.speakFontSize, default: 32, range: 18...44)

        appLanguage = AppLanguage(
            rawValue: defaults.string(forKey: Keys.appLanguage) ?? ""
        ) ?? .english
        explanationLanguage = ExplanationLanguage(
            rawValue: defaults.string(forKey: Keys.explanationLanguage) ?? ""
        ) ?? .english

        splashEnabled = defaults.object(forKey: Keys.splashEnabled) as? Bool ?? true
        splashAutoCloseSeconds = Self.int(
            defaults, Keys.splashAutoCloseSeconds, default: 3, range: 0...15
        )

        keyboardMode = KeyboardMode(
            rawValue: defaults.string(forKey: Keys.keyboardMode) ?? ""
        ) ?? .builtIn

        speakAutoMode = defaults.object(forKey: Keys.speakAutoMode) as? Bool ?? true
        let storedVoice = defaults.string(forKey: Keys.voiceIdentifier) ?? ""
        // Older builds defaulted to Apple's Yuna voice. Yuna is intentionally
        // retired in favour of the bundled neural voice.
        voiceIdentifier = storedVoice.localizedCaseInsensitiveContains("yuna")
            ? ""
            : storedVoice
        speechRate = Self.double(defaults, Keys.speechRate, default: 0.5, range: 0.3...0.8)
        repeatCount = Self.int(defaults, Keys.repeatCount, default: 1, range: 0...5)

        lastBackupAt = defaults.object(forKey: Keys.lastBackupAt) as? Date
    }

    func snapshot() -> SettingsSnapshot {
        SettingsSnapshot(
            appearance: appearance.rawValue,
            readingDuration: readingDuration,
            typingDuration: typingDuration,
            readingFontSize: readingFontSize,
            typingFontSize: typingFontSize,
            speakFontSize: speakFontSize,
            appLanguage: appLanguage.rawValue,
            explanationLanguage: explanationLanguage.rawValue,
            splashEnabled: splashEnabled,
            splashAutoCloseSeconds: splashAutoCloseSeconds,
            keyboardMode: keyboardMode.rawValue,
            speakAutoMode: speakAutoMode,
            voiceIdentifier: voiceIdentifier,
            speechRate: speechRate,
            repeatCount: repeatCount
        )
    }

    func apply(_ snapshot: SettingsSnapshot) {
        appearance = AppAppearance(rawValue: snapshot.appearance) ?? .system
        readingDuration = Self.clamp(snapshot.readingDuration, to: 15...300)
        typingDuration = Self.clamp(snapshot.typingDuration, to: 15...300)
        readingFontSize = Self.clamp(snapshot.readingFontSize, to: 18...44)
        typingFontSize = Self.clamp(snapshot.typingFontSize, to: 18...44)
        speakFontSize = Self.clamp(snapshot.speakFontSize, to: 18...44)
        appLanguage = AppLanguage(rawValue: snapshot.appLanguage) ?? .english
        explanationLanguage = ExplanationLanguage(
            rawValue: snapshot.explanationLanguage
        ) ?? .english
        splashEnabled = snapshot.splashEnabled
        splashAutoCloseSeconds = Self.clamp(snapshot.splashAutoCloseSeconds, to: 0...15)
        keyboardMode = KeyboardMode(rawValue: snapshot.keyboardMode) ?? .builtIn
        speakAutoMode = snapshot.speakAutoMode
        voiceIdentifier = snapshot.voiceIdentifier
        speechRate = Self.clamp(snapshot.speechRate, to: 0.3...0.8)
        repeatCount = Self.clamp(snapshot.repeatCount, to: 0...5)
    }

    func resetToDefaults() {
        appearance = .system
        readingDuration = 60
        typingDuration = 60
        readingFontSize = 30
        typingFontSize = 24
        speakFontSize = 32
        appLanguage = .english
        explanationLanguage = .english
        splashEnabled = true
        splashAutoCloseSeconds = 3
        keyboardMode = .builtIn
        speakAutoMode = true
        voiceIdentifier = ""
        speechRate = 0.5
        repeatCount = 1
    }

    private static func clamp<T: Comparable>(
        _ value: T,
        to range: ClosedRange<T>
    ) -> T {
        min(max(value, range.lowerBound), range.upperBound)
    }

    private static func int(
        _ defaults: UserDefaults,
        _ key: String,
        default defaultValue: Int,
        range: ClosedRange<Int>
    ) -> Int {
        guard let value = defaults.object(forKey: key) as? Int else { return defaultValue }
        return min(max(value, range.lowerBound), range.upperBound)
    }

    private static func double(
        _ defaults: UserDefaults,
        _ key: String,
        default defaultValue: Double,
        range: ClosedRange<Double>
    ) -> Double {
        guard let value = defaults.object(forKey: key) as? Double else { return defaultValue }
        return min(max(value, range.lowerBound), range.upperBound)
    }
}

private enum Keys {
    static let appearance = "settings.appearance"
    static let readingDuration = "settings.readingDuration"
    static let typingDuration = "settings.typingDuration"
    static let readingFontSize = "settings.readingFontSize"
    static let typingFontSize = "settings.typingFontSize"
    static let speakFontSize = "settings.speakFontSize"
    static let appLanguage = "settings.appLanguage"
    static let explanationLanguage = "settings.explanationLanguage"
    static let splashEnabled = "settings.splashEnabled"
    static let splashAutoCloseSeconds = "settings.splashAutoCloseSeconds"
    static let keyboardMode = "settings.keyboardMode"
    static let speakAutoMode = "settings.speakAutoMode"
    static let voiceIdentifier = "settings.voiceIdentifier"
    static let speechRate = "settings.speechRate"
    static let repeatCount = "settings.repeatCount"
    static let lastBackupAt = "settings.lastBackupAt"
}
