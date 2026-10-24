import Foundation

/// High-level entry point for the bundled Supertonic-3 pipeline.
///
/// The manager owns the model store, unicode indexer, and voice-style cache.
/// It never downloads anything: the INT8 L128 CoreML build and four voice
/// presets ship inside the app bundle.
actor Supertonic3Manager {
    private let store: Supertonic3ModelStore
    private var processor: Supertonic3UnicodeProcessor?
    private var synthesizer: Supertonic3Synthesizer?
    private var voiceCache: [String: Supertonic3VoiceStyle] = [:]

    init(store: Supertonic3ModelStore = Supertonic3ModelStore()) {
        self.store = store
    }

    func prepare() async throws {
        if synthesizer != nil { return }
        try await store.loadIfNeeded()
        let processor = try Supertonic3UnicodeProcessor(
            unicodeIndexerURL: await store.unicodeIndexerURL()
        )
        self.processor = processor
        self.synthesizer = Supertonic3Synthesizer(store: store, processor: processor)
    }

    func synthesize(
        text: String,
        language: String = "ko",
        voice: String = "F1",
        speed: Double = 1.0,
        totalSteps: Int = Supertonic3Constants.defaultTotalSteps
    ) async throws -> [Float] {
        try await prepare()
        guard let synthesizer else { throw Supertonic3Error.notInitialized }

        let style = try await voiceStyle(named: voice)
        let clampedSpeed = Float(min(max(speed, 0.55), 1.5))
        let result = try await synthesizer.synthesize(
            text: text,
            language: language,
            style: style,
            totalSteps: max(2, totalSteps),
            speed: clampedSpeed,
            silenceDuration: Supertonic3Constants.defaultSilenceDuration
        )
        return result.samples
    }

    func voiceStyle(named name: String) async throws -> Supertonic3VoiceStyle {
        let key = name.uppercased()
        if let cached = voiceCache[key] { return cached }
        let url = try await store.voiceStyleURL(named: key)
        let style = try Supertonic3VoiceStyle.load(from: url)
        voiceCache[key] = style
        return style
    }

    func sampleRate() async -> Int {
        await store.config.ae.sampleRate
    }
}
