import SwiftUI

struct SpeakView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var customText = ""
    @State private var showingVoiceSettings = false

    private let samplePhrase = "안녕하세요. 만나서 반갑습니다."
    private let sampleWords = ["안녕하세요", "만나서", "반갑습니다"]

    var body: some View {
        @Bindable var settings = env.settings

        NavigationStack {
            ScrollView {
                VStack(spacing: SoriSpacing.lg) {
                    autoRow(settings: settings)

                    if settings.speakAutoMode {
                        phraseCard
                    } else {
                        customTextCard
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
                }
            }
            .sheet(isPresented: $showingVoiceSettings) {
                VoiceSettingsSheet(settings: settings)
            }
        }
    }

    private func autoRow(settings: SettingsStore) -> some View {
        SoriCard {
            HStack(spacing: SoriSpacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Auto")
                        .font(SoriFont.headline)
                        .foregroundStyle(Color.soriInk)
                    Text(settings.speakAutoMode ? "Phrases from your library" : "Your own Korean text")
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

    private var phraseCard: some View {
        SoriCard {
            VStack(alignment: .leading, spacing: SoriSpacing.md) {
                HStack {
                    SoriBadge(text: "Phrase 1")
                    Spacer()
                    Text("≤ 10 eojeol")
                        .font(SoriFont.caption)
                        .foregroundStyle(Color.soriSecondary)
                }

                Text(samplePhrase)
                    .font(SoriFont.korean(env.settings.speakFontSize))
                    .foregroundStyle(Color.soriInk)
                    .lineSpacing(env.settings.speakFontSize * 0.35)
                    .fixedSize(horizontal: false, vertical: true)

                FlowingWords(words: sampleWords)

                Text("Yuna · ko-KR · 1×")
                    .font(SoriFont.caption)
                    .foregroundStyle(Color.soriSecondary)

                HStack(spacing: SoriSpacing.sm) {
                    Button {} label: {
                        Label("Play phrase", systemImage: "play.fill")
                    }
                    .buttonStyle(SoriPrimaryButtonStyle())
                    .disabled(true)
                    .opacity(0.55)

                    Button {} label: {
                        Image(systemName: "arrow.right")
                    }
                    .buttonStyle(SoriSecondaryButtonStyle(fullWidth: false))
                    .disabled(true)
                    .opacity(0.55)
                }

                Text("Audio playback arrives in M4. Tap a word to hear it separately once enabled.")
                    .font(SoriFont.caption)
                    .foregroundStyle(Color.soriSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var customTextCard: some View {
        SoriCard {
            VStack(alignment: .leading, spacing: SoriSpacing.sm) {
                Text("Your text")
                    .font(SoriFont.headline)
                    .foregroundStyle(Color.soriInk)

                TextEditor(text: $customText)
                    .font(SoriFont.korean(24))
                    .frame(minHeight: 130)
                    .scrollContentBackground(.hidden)
                    .padding(SoriSpacing.sm)
                    .background(Color.soriSurfaceElevated, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(alignment: .topLeading) {
                        if customText.isEmpty {
                            Text("Paste Korean text here…")
                                .font(SoriFont.korean(24))
                                .foregroundStyle(Color.soriTertiary)
                                .padding(.horizontal, SoriSpacing.md)
                                .padding(.vertical, SoriSpacing.md)
                                .allowsHitTesting(false)
                        }
                    }

                Button("Pronounce") {}
                    .buttonStyle(SoriPrimaryButtonStyle())
                    .disabled(true)
                    .opacity(0.55)
            }
        }
    }

    private func controlsCard(settings: SettingsStore) -> some View {
        SoriCard {
            VStack(spacing: 0) {
                Text("Playback")
                    .font(SoriFont.headline)
                    .foregroundStyle(Color.soriInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, SoriSpacing.sm)

                settingRow("Voice", value: "Yuna (system)")
                Divider().overlay(Color.soriBorder)
                settingRow("Speed", value: String(format: "%.2f×", settings.speechRate / 0.5))
                Divider().overlay(Color.soriBorder)
                settingRow(
                    "Repeat",
                    value: settings.repeatCount == 0 ? "Loop" : "\(settings.repeatCount)×"
                )
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
        }
        .padding(.vertical, 11)
    }
}

// MARK: - Word chips

private struct FlowingWords: View {
    let words: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SoriSpacing.xs) {
                ForEach(Array(words.enumerated()), id: \.offset) { _, word in
                    Text(word)
                        .font(SoriFont.korean(17))
                        .foregroundStyle(Color.soriInk)
                        .padding(.horizontal, SoriSpacing.sm)
                        .padding(.vertical, 7)
                        .background(Color.soriAccent.opacity(0.10), in: Capsule())
                }
            }
        }
    }
}

// MARK: - Voice settings

private struct VoiceSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let settings: SettingsStore

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            Form {
                Section("Voice") {
                    LabeledContent("Speaker", value: "Yuna")
                    LabeledContent("Language", value: "Korean (ko-KR)")
                    LabeledContent("Quality", value: "System default")
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
                    Text("Voice selection and playback arrive in M4. Apple Yuna Enhanced is the default; install the enhanced voice in iOS Settings → Accessibility → Spoken Content → Voices → Korean.")
                        .font(SoriFont.caption)
                        .foregroundStyle(Color.soriSecondary)
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
    }
}
