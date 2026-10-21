import XCTest
@testable import Sori

@MainActor
final class SettingsStoreTests: XCTestCase {
    func testDefaultValues() {
        withStore { store, _ in
            XCTAssertEqual(store.appearance, .system)
            XCTAssertEqual(store.readingDuration, 60)
            XCTAssertEqual(store.typingDuration, 60)
            XCTAssertEqual(store.readingFontSize, 30)
            XCTAssertEqual(store.typingFontSize, 24)
            XCTAssertEqual(store.speakFontSize, 32)
            XCTAssertEqual(store.appLanguage, .english)
            XCTAssertEqual(store.explanationLanguage, .english)
            XCTAssertTrue(store.splashEnabled)
            XCTAssertEqual(store.splashAutoCloseSeconds, 3)
            XCTAssertEqual(store.keyboardMode, .builtIn)
            XCTAssertTrue(store.speakAutoMode)
            XCTAssertEqual(store.voiceIdentifier, "")
            XCTAssertEqual(store.speechRate, 0.5)
            XCTAssertEqual(store.repeatCount, 1)
        }
    }

    func testValuesPersistAcrossInstances() {
        withStore { first, defaults in
            first.appearance = .dark
            first.readingDuration = 90
            first.typingDuration = 120
            first.readingFontSize = 36
            first.typingFontSize = 28
            first.splashEnabled = false
            first.splashAutoCloseSeconds = 5
            first.keyboardMode = .system
            first.speakAutoMode = false
            first.voiceIdentifier = "com.apple.voice.enhanced.ko-KR.Yuna"
            first.speechRate = 0.65
            first.repeatCount = 3

            let second = SettingsStore(defaults: defaults)
            XCTAssertEqual(second.appearance, .dark)
            XCTAssertEqual(second.readingDuration, 90)
            XCTAssertEqual(second.typingDuration, 120)
            XCTAssertEqual(second.readingFontSize, 36)
            XCTAssertEqual(second.typingFontSize, 28)
            XCTAssertFalse(second.splashEnabled)
            XCTAssertEqual(second.splashAutoCloseSeconds, 5)
            XCTAssertEqual(second.keyboardMode, .system)
            XCTAssertFalse(second.speakAutoMode)
            XCTAssertEqual(second.voiceIdentifier, "com.apple.voice.enhanced.ko-KR.Yuna")
            XCTAssertEqual(second.speechRate, 0.65)
            XCTAssertEqual(second.repeatCount, 3)
        }
    }

    func testInvalidStoredValuesAreClamped() {
        withStore { store, defaults in
            defaults.set(5_000, forKey: "settings.readingDuration")
            defaults.set(2.0, forKey: "settings.readingFontSize")
            defaults.set("not-a-language", forKey: "settings.appLanguage")

            let reloaded = SettingsStore(defaults: defaults)
            XCTAssertEqual(reloaded.readingDuration, 300)
            XCTAssertEqual(reloaded.readingFontSize, 18)
            XCTAssertEqual(reloaded.appLanguage, .english)
            XCTAssertEqual(store.readingDuration, 60)
        }
    }

    func testResetRestoresDefaults() {
        withStore { store, _ in
            store.appearance = .dark
            store.readingDuration = 150
            store.keyboardMode = .system
            store.voiceIdentifier = "voice"
            store.speechRate = 0.7
            store.repeatCount = 4

            store.resetToDefaults()

            XCTAssertEqual(store.appearance, .system)
            XCTAssertEqual(store.readingDuration, 60)
            XCTAssertEqual(store.keyboardMode, .builtIn)
            XCTAssertEqual(store.voiceIdentifier, "")
            XCTAssertEqual(store.speechRate, 0.5)
            XCTAssertEqual(store.repeatCount, 1)
        }
    }

    private func withStore(_ body: (SettingsStore, UserDefaults) throws -> Void) rethrows {
        let suiteName = "SoriTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SettingsStore(defaults: defaults)
        try body(store, defaults)
    }
}
