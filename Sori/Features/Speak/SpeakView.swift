import SwiftUI

struct SpeakView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.scenePhase) private var scenePhase

    @State private var customText = ""
    @State private var autoPhrase: String?
    @State private var isLoadingPhrase = false
    @State private var hasLoadedPhrase = false
    @State private var showingVoiceSettings = false
    @State private var alertTitle = "Audio unavailable"
    @State private var alertMessage: String?
    @State private var player = SpeakPlayer()

    var body: some View {
        @Bindable var settings = env.settings

        NavigationStack {
            ScrollView {
                VStack(spacing: SoriSpacing.lg) {
                    autoRow(settings: settings)

                    if settings.speakAutoMode {
                        phraseSection(settings: settings)
                    } else {
                        customTextCard(settings: settings)
                    }

                    controlsCard(settings: settings)
                }
                .padding(SoriSpacing.lg)
                .padding(.bottom, SoriSpacing.xl)
            }
            .soriScreenBackground()
            .navigationTitle("Speak")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingVoiceSettings = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityLabel("Voice settings")
                }
            }
            .sheet(isPresented: $showingVoiceSettings) {
                VoiceSettingsSheet(settings: settings, player: player)
            }
        }
        .task {
            if env.settings.speakAutoMode {
                await loadPhraseIfNeeded()
            }

            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--speak-voice-settings") {
                showingVoiceSettings = true
            }
            if ProcessInfo.processInfo.arguments.contains("--speak-play") {
                let text = env.settings.speakAutoMode ? (autoPhrase ?? "") : customText
                if !text.isEmpty {
                    player.play(
                        text,
                        repeatCount: env.settings.repeatCount,
                        voiceIdentifier: env.settings.voiceIdentifier,
                        rate: env.settings.speechRate
                    )
                }
            }
            #endif
        }
        .onChange(of: settings.speakAutoMode) { _, isAuto in
            player.stop()
            if isAuto {
                Task { await loadPhraseIfNeeded() }
            }
        }
        .onChange(of: env.libraryRevision) { _, _ in
            guard env.settings.speakAutoMode, autoPhrase == nil, !isLoadingPhrase else {
                return
            }
            Task { await loadPhrase() }
        }
        .onChange(of: player.errorMessage) { _, message in
            guard let message else { return }
            alertTitle = "Audio unavailable"
            alertMessage = message
            player.clearError()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase != .active else { return }
            player.stop()
        }
        .onDisappear {
            player.stop()
        }
        .alert(
            alertTitle,
            isPresented: Binding(
                get: { alertMessage != nil },
                set: { if !$0 { alertMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private func autoRow(settings: SettingsStore) -> some View {
        SoriCard {
            HStack(spacing: SoriSpacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Auto")
                        .font(SoriFont.headline)
                        .foregroundStyle(Color.soriInk)
                    Text(settings.speakAutoMode ? "Short phrases from your library" : "Your own Korean text")
                        .font(SoriFont.caption)
                        .foregroundStyle(Color.soriSecondary)
                }
                Spacer()
                Toggle("Auto", isOn: Binding(
                    get: { settings.speakAutoMode },
                    set: { settings.speakAutoMode = $0 }
                ))
                .labelsHidden()
            }
        }
    }

    @ViewBuilder
    private func phraseSection(settings: SettingsStore) -> some View {
        if let autoPhrase {
            phraseCard(autoPhrase, settings: settings)
        } else if isLoadingPhrase {
            SoriCard {
                HStack(spacing: SoriSpacing.sm) {
                    ProgressView()
                    Text("Choosing a short library phrase…")
                        .font(SoriFont.body)
                        .foregroundStyle(Color.soriSecondary)
                }
            }
        } else if hasLoadedPhrase {
            SoriCard {
                SoriEmptyState(
                    symbol: "text.quote",
                    title: "No short phrases yet",
                    message: "Auto mode uses complete Korean phrases of ten eojeol or fewer. Add Korean text in Library, then try again."
                )
                Button("Try again") {
                    Task { await loadPhrase() }
                }
                .buttonStyle(SoriSecondaryButtonStyle())
            }
        }
    }

    private func phraseCard(_ phrase: String, settings: SettingsStore) -> some View {
        SoriCard {
            VStack(alignment: .leading, spacing: SoriSpacing.md) {
                HStack {
                    SoriBadge(text: "Library phrase")
                    Spacer()
                    Text("\(KoreanText.eojeolCount(phrase)) / 10 eojeol")
                        .font(SoriFont.caption)
                        .foregroundStyle(Color.soriSecondary)
                }

                Text(phrase)
                    .font(SoriFont.korean(settings.speakFontSize))
                    .foregroundStyle(Color.soriInk)
                    .lineSpacing(settings.speakFontSize * 0.35)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("speak-phrase")

                WordFlow(
                    words: KoreanText.words(in: phrase),
                    activeWord: player.isSpeaking ? player.speakingText : nil
                ) { word in
                    speakWord(word, settings: settings)
                }

                HStack(spacing: SoriSpacing.sm) {
                    Button {
                        if player.isSpeaking {
                            player.stop()
                        } else {
                            playPhrase(phrase, settings: settings)
                        }
                    } label: {
                        Label(
                            player.isSpeaking ? "Stop" : "Play phrase",
                            systemImage: player.isSpeaking ? "stop.fill" : "play.fill"
                        )
                    }
                    .buttonStyle(SoriPrimaryButtonStyle())

                    Button {
                        Task { await loadPhrase() }
                    } label: {
                        Image(systemName: "arrow.right")
                    }
                    .buttonStyle(SoriSecondaryButtonStyle(fullWidth: false))
                    .disabled(isLoadingPhrase)
                    .accessibilityLabel("Next phrase")
                }

                Text("Tap any word to hear it on its own.")
                    .font(SoriFont.caption)
                    .foregroundStyle(Color.soriSecondary)
            }
        }
    }

    private func customTextCard(settings: SettingsStore) -> some View {
        SoriCard {
            VStack(alignment: .leading, spacing: SoriSpacing.sm) {
                Text("Your text")
                    .font(SoriFont.headline)
                    .foregroundStyle(Color.soriInk)

                TextEditor(text: $customText)
                    .font(SoriFont.korean(settings.speakFontSize))
                    .frame(minHeight: 130)
                    .scrollContentBackground(.hidden)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(SoriSpacing.sm)
                    .background(Color.soriSurfaceElevated, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(alignment: .topLeading) {
                        if customText.isEmpty {
                            Text("Paste Korean text here…")
                                .font(SoriFont.korean(settings.speakFontSize))
                                .foregroundStyle(Color.soriTertiary)
                                .padding(.horizontal, SoriSpacing.md)
                                .padding(.vertical, SoriSpacing.md)
                                .allowsHitTesting(false)
                        }
                    }
                    .accessibilityIdentifier("speak-custom-text")

                if !customText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    WordFlow(
                        words: KoreanText.words(in: customText),
                        activeWord: player.isSpeaking ? player.speakingText : nil
                    ) { word in
                        speakWord(word, settings: settings)
                    }

                    Text("Tap a word to hear it on its own.")
                        .font(SoriFont.caption)
                        .foregroundStyle(Color.soriSecondary)
                }

                Button {
                    if player.isSpeaking {
                        player.stop()
                    } else {
                        playPhrase(customText, settings: settings)
                    }
                } label: {
                    Label(
                        player.isSpeaking ? "Stop" : "Pronounce",
                        systemImage: player.isSpeaking ? "stop.fill" : "speaker.wave.2.fill"
                    )
                }
                .buttonStyle(SoriPrimaryButtonStyle())
                .disabled(customText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func controlsCard(settings: SettingsStore) -> some View {
        SoriCard {
            VStack(spacing: 0) {
                HStack {
                    Text("Playback")
                        .font(SoriFont.headline)
                        .foregroundStyle(Color.soriInk)
                    Spacer()
                    Button("Change") {
                        showingVoiceSettings = true
                    }
                    .font(SoriFont.captionStrong)
                    .foregroundStyle(Color.soriAccent)
                }
                .padding(.bottom, SoriSpacing.sm)

                settingRow(
                    "Voice",
                    value: player.resolvedVoice(for: settings.voiceIdentifier)?.displayName
                        ?? "No Korean voice"
                )
                Divider().overlay(Color.soriBorder)
                settingRow("Speed", value: rateLabel(settings.speechRate))
                Divider().overlay(Color.soriBorder)
                settingRow("Repeat", value: repeatLabel(settings.repeatCount))

                Text("Speech is generated on-device by Apple. Nothing is uploaded or logged.")
                    .font(SoriFont.caption)
                    .foregroundStyle(Color.soriSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, SoriSpacing.md)
            }
        }
    }

    private func settingRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(SoriFont.body)
                .foregroundStyle(Color.soriInk)
            Spacer()
            Text(value)
                .font(SoriFont.callout)
                .foregroundStyle(Color.soriSecondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 11)
    }

    private func playPhrase(_ text: String, settings: SettingsStore) {
        player.play(
            text,
            repeatCount: settings.repeatCount,
            voiceIdentifier: settings.voiceIdentifier,
            rate: settings.speechRate
        )
    }

    private func speakWord(_ word: String, settings: SettingsStore) {
        player.play(
            word,
            repeatCount: 1,
            voiceIdentifier: settings.voiceIdentifier,
            rate: settings.speechRate
        )
    }

    private func rateLabel(_ rate: Double) -> String {
        String(format: "%.2f×", rate / 0.5)
    }

    private func repeatLabel(_ count: Int) -> String {
        count == 0 ? "Loop" : "\(count)×"
    }

    private func loadPhraseIfNeeded() async {
        guard autoPhrase == nil, !isLoadingPhrase else { return }
        await loadPhrase()
    }

    @MainActor
    private func loadPhrase() async {
        guard !isLoadingPhrase else { return }
        isLoadingPhrase = true
        player.stop()
        defer {
            isLoadingPhrase = false
            hasLoadedPhrase = true
        }

        do {
            let candidates = try await env.library.randomSentences(limit: 500)
            let eligible = candidates
                .map(\.text)
                .filter { KoreanText.isNaturalPhrase($0) }
            let preferred = eligible.filter {
                (3...7).contains(KoreanText.eojeolCount($0))
            }
            let base = preferred.isEmpty ? eligible : preferred
            let choices = base.filter { $0 != autoPhrase }
            let pool = choices.isEmpty ? base : choices

            guard let next = pool.randomElement() else {
                autoPhrase = nil
                return
            }

            autoPhrase = next
        } catch {
            alertTitle = "Could not load a phrase"
            alertMessage = "Could not load a library phrase. \(error.localizedDescription)"
        }
    }
}

// MARK: - Word chips

private struct WordFlow: View {
    let words: [String]
    let activeWord: String?
    let onTap: (String) -> Void

    var body: some View {
        WordFlowLayout(spacing: 8, lineSpacing: 8) {
            ForEach(Array(words.enumerated()), id: \.offset) { _, word in
                Button {
                    onTap(word)
                } label: {
                    Text(word)
                        .font(SoriFont.korean(17))
                        .foregroundStyle(Color.soriInk)
                        .padding(.horizontal, SoriSpacing.sm)
                        .padding(.vertical, 7)
                        .background(
                            Color.soriAccent.opacity(activeWord == word ? 0.24 : 0.10),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Hear \(word)")
            }
        }
    }
}

// MARK: - Voice settings

private struct VoiceSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let settings: SettingsStore
    let player: SpeakPlayer

    private var unavailableVoiceIdentifier: String? {
        let identifier = settings.voiceIdentifier
        guard !identifier.isEmpty,
              !player.voices.contains(where: { $0.id == identifier }) else {
            return nil
        }
        return identifier
    }

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            Form {
                Section {
                    Picker("Voice", selection: $settings.voiceIdentifier) {
                        Text("Automatic (best installed)").tag("")
                        if let unavailableVoiceIdentifier {
                            Text("Unavailable voice").tag(unavailableVoiceIdentifier)
                        }
                        ForEach(player.voices) { voice in
                            Text(voice.displayName).tag(voice.id)
                        }
                    }

                    if let voice = player.resolvedVoice(for: settings.voiceIdentifier) {
                        LabeledContent("Using", value: voice.displayName)
                        LabeledContent("Quality", value: voice.quality.title)
                        LabeledContent("Language", value: voice.language)
                    } else {
                        Text("No Korean voice is installed. Add one in iOS Settings.")
                            .font(SoriFont.caption)
                            .foregroundStyle(Color.soriWarning)
                    }
                } header: {
                    Text("Voice")
                } footer: {
                    VStack(alignment: .leading, spacing: SoriSpacing.xs) {
                        if settings.voiceIdentifier.isEmpty,
                           let best = player.bestVoice,
                           best.quality == .standard {
                            Text("Yuna Enhanced is not installed, so Sori is using \(best.displayName). Download Yuna (Enhanced) or a Premium Korean voice in iOS Settings → Accessibility → Spoken Content → Voices → Korean.")
                        } else {
                            Text("Automatic picks the highest-quality Korean voice installed, preferring Yuna on ties.")
                        }
                        Text("All voices work offline. Nothing is uploaded or logged.")
                    }
                }

                Section("Speed") {
                    Slider(value: $settings.speechRate, in: 0.3...0.8, step: 0.05)
                    HStack {
                        Text("Slower")
                        Spacer()
                        Text(String(format: "%.2f×", settings.speechRate / 0.5))
                            .font(SoriFont.mono)
                        Spacer()
                        Text("Faster")
                    }
                    .font(SoriFont.caption)
                    .foregroundStyle(Color.soriSecondary)
                }

                Section("Repeat") {
                    Stepper(
                        value: $settings.repeatCount,
                        in: 0...5
                    ) {
                        Text(settings.repeatCount == 0 ? "Loop indefinitely" : "\(settings.repeatCount)×")
                    }
                }

                Section {
                    Button {
                        player.play(
                            "안녕하세요. 만나서 반갑습니다.",
                            repeatCount: 1,
                            voiceIdentifier: settings.voiceIdentifier,
                            rate: settings.speechRate
                        )
                    } label: {
                        Label("Test voice", systemImage: "speaker.wave.2.fill")
                    }
                    .disabled(player.voices.isEmpty)

                    if player.isSpeaking {
                        Button("Stop") {
                            player.stop()
                        }
                    }
                } footer: {
                    Text("Tap a word in a phrase to hear just that word. Full phrases follow the repeat setting.")
                }
            }
            .navigationTitle("Voice settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onDisappear {
            player.stop()
        }
    }
}
