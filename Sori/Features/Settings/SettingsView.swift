import SwiftUI

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var env

    @State private var showingResetConfirmation = false
    @State private var showingLicences = false

    var body: some View {
        @Bindable var settings = env.settings

        NavigationStack {
            Form {
                Section {
                    Picker("Theme", selection: $settings.appearance) {
                        ForEach(AppAppearance.allCases) { appearance in
                            Text(appearance.title).tag(appearance)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("System follows the iPhone's light or dark setting.")
                }

                Section {
                    Stepper(value: $settings.readingDuration, in: 15...300, step: 15) {
                        LabeledContent("Reading", value: settings.readingDuration.soriClock)
                    }
                    Stepper(value: $settings.typingDuration, in: 15...300, step: 15) {
                        LabeledContent("Typing", value: settings.typingDuration.soriClock)
                    }
                } header: {
                    Text("Practice duration")
                } footer: {
                    Text("Sessions end automatically at this length. CPM is always normalised to one minute.")
                }

                Section {
                    fontSizeRow(
                        title: "Reading",
                        value: $settings.readingFontSize,
                        sample: "안녕하세요. 오늘 날씨가 좋네요."
                    )
                    fontSizeRow(
                        title: "Typing",
                        value: $settings.typingFontSize,
                        sample: "저는 한국어를 배워요."
                    )
                    fontSizeRow(
                        title: "Speak",
                        value: $settings.speakFontSize,
                        sample: "만나서 반갑습니다."
                    )
                } header: {
                    Text("Text size")
                }

                Section {
                    LabeledContent("App language", value: "English")
                    LabeledContent("Explanations", value: "English")
                } header: {
                    Text("Language")
                } footer: {
                    Text("Vietnamese UI and explanations are coming in a later update. Lesson content is already structured for both languages.")
                }

                Section {
                    Picker("Keyboard", selection: $settings.keyboardMode) {
                        ForEach(KeyboardMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                } header: {
                    Text("Typing")
                } footer: {
                    Text("The built-in 2-set keyboard is always Korean and needs no system switching. System keyboard mode remembers the last detected language.")
                }

                Section {
                    Toggle("Daily summary", isOn: $settings.splashEnabled)
                    Picker("Close after", selection: $settings.splashAutoCloseSeconds) {
                        Text("Manually").tag(0)
                        Text("2 seconds").tag(2)
                        Text("3 seconds").tag(3)
                        Text("5 seconds").tag(5)
                        Text("10 seconds").tag(10)
                    }
                    .disabled(!settings.splashEnabled)
                } header: {
                    Text("Launch summary")
                } footer: {
                    Text("Shown the first time you open Sori each day.")
                }

                Section {
                    NavigationLink {
                        LibraryView()
                    } label: {
                        LabeledContent("Library", value: libraryValue)
                    }
                    NavigationLink {
                        SourcesSettingsView()
                    } label: {
                        LabeledContent("Subtitle sources", value: sourcesValue)
                    }
                    LabeledContent("Backup", value: "Not configured")
                    LabeledContent(
                        "Last backup",
                        value: settings.lastBackupAt.map(formatDate) ?? "Never"
                    )
                } header: {
                    Text("Library & backup")
                } footer: {
                    Text("Sori keeps a local copy of real Korean reading material. Backup and restore arrive in M8.")
                }

                Section {
                    LabeledContent("Version", value: "0.1.0")
                    LabeledContent("Curriculum", value: "0.1.0")
                    Button("Sources & licences") {
                        showingLicences = true
                    }
                } header: {
                    Text("About")
                }

                Section {
                    Button("Reset settings", role: .destructive) {
                        showingResetConfirmation = true
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .soriScreenBackground()
            .navigationTitle("Settings")
            .confirmationDialog(
                "Reset all settings?",
                isPresented: $showingResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset", role: .destructive) {
                    settings.resetToDefaults()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Progress and practice history are not affected.")
            }
            .sheet(isPresented: $showingLicences) {
                LicencesSheet()
            }
        }
    }

    private func fontSizeRow(
        title: String,
        value: Binding<Double>,
        sample: String
    ) -> some View {
        VStack(alignment: .leading, spacing: SoriSpacing.xs) {
            LabeledContent(title, value: "\(Int(value.wrappedValue)) pt")
            Slider(value: value, in: 18...44, step: 1)
            Text(sample)
                .font(.system(size: value.wrappedValue))
                .foregroundStyle(Color.soriInk)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 2)
        }
        .padding(.vertical, 2)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private var libraryValue: String {
        guard let summary = env.librarySummary else { return "Preparing…" }
        return "\(TextNormalizer.formatBytes(summary.totalBytes)) of 2 MB"
    }

    private var sourcesValue: String {
        let hasKey = !(SecretStore.shared.value(for: .openSubtitlesAPIKey) ?? "").isEmpty
        return hasKey ? "Configured" : "Not configured"
    }
}

private struct LicencesSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SoriSpacing.md) {
                    Text("Sori source code is licensed under MIT.")
                    Text("Original curriculum content is licensed under CC BY-NC-SA 4.0.")
                    Text("Public-domain texts keep their original status. Openly licensed texts, such as Korean Wikipedia under CC BY-SA 4.0, are attributed in the Library screen when downloaded.")
                    Text("Textbook PDFs, textbook audio, subtitles, and exam papers are personal study material and are never committed to the public repository.")
                }
                .font(SoriFont.body)
                .foregroundStyle(Color.soriSecondary)
                .padding(SoriSpacing.lg)
            }
            .soriScreenBackground()
            .navigationTitle("Sources & licences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
