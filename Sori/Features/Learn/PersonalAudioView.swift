import SwiftUI
import UniformTypeIdentifiers

struct PersonalAudioView: View {
    @Environment(AppEnvironment.self) private var env

    @State private var player = PersonalAudioPlayer()
    @State private var showingImporter = false
    @State private var showingClearConfirmation = false
    @State private var alertMessage: String?

    var body: some View {
        List {
            Section {
                if env.personalAudio.tracks.isEmpty {
                    SoriEmptyState(
                        symbol: "waveform",
                        title: "No personal audio",
                        message: "Import the Vitamin Korean 1 MP3 folder or ZIP. Tracks are matched to lessons by their number."
                    )
                    .listRowBackground(Color.clear)

                    Button {
                        showingImporter = true
                    } label: {
                        Label("Import audio", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(SoriPrimaryButtonStyle())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(env.personalAudio.tracks) { track in
                        trackRow(track)
                    }
                }
            } header: {
                Text("Imported tracks")
            } footer: {
                Text("Audio stays in Sori's private storage on this iPhone and is excluded from iCloud backup. It is never uploaded or committed.")
            }

            if !env.personalAudio.tracks.isEmpty {
                Section {
                    Button("Import more audio") {
                        showingImporter = true
                    }
                    Button("Clear all personal audio", role: .destructive) {
                        showingClearConfirmation = true
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .soriScreenBackground()
        .navigationTitle("Personal audio")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingImporter = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Import audio")
            }
        }
        .onAppear {
            env.personalAudio.reload()
        }
        .onDisappear {
            player.stop()
        }
        .onChange(of: player.errorMessage) { _, message in
            guard let message else { return }
            alertMessage = message
            player.clearError()
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.audio, .zip, .folder],
            allowsMultipleSelection: true
        ) { result in
            handleImport(result)
        }
        .confirmationDialog(
            "Delete every imported audio track?",
            isPresented: $showingClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete all audio", role: .destructive) {
                player.stop()
                env.personalAudio.clear()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The original files on your Mac or in iCloud are not affected.")
        }
        .alert(
            "Personal audio",
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

    private func trackRow(_ track: PersonalAudioTrack) -> some View {
        Button {
            player.toggle(track)
        } label: {
            HStack(spacing: SoriSpacing.sm) {
                Image(systemName: isPlaying(track) ? "stop.circle.fill" : "play.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.soriAccent)

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.displayName)
                        .font(SoriFont.callout)
                        .foregroundStyle(Color.soriInk)
                    Text(lessonLabel(for: track))
                        .font(SoriFont.caption)
                        .foregroundStyle(Color.soriSecondary)
                }

                Spacer()
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button("Delete", role: .destructive) {
                if player.currentTrackID == track.id {
                    player.stop()
                }
                env.personalAudio.delete(track)
            }
        }
    }

    private func lessonLabel(for track: PersonalAudioTrack) -> String {
        guard let number = track.trackNumber,
              let lesson = env.curriculum.lesson(forTrack: number) else {
            return "Not matched to a lesson"
        }
        return "Lesson \(lesson.id) · \(lesson.englishTitle)"
    }

    private func isPlaying(_ track: PersonalAudioTrack) -> Bool {
        player.currentTrackID == track.id && player.isPlaying
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            let imported = env.personalAudio.importSources(urls)
            if let error = env.personalAudio.lastError {
                alertMessage = error
            } else if imported == 0 {
                alertMessage = "No audio files were found in that selection."
            } else {
                alertMessage = "Imported \(imported) audio file\(imported == 1 ? "" : "s")."
            }
        case .failure(let error):
            alertMessage = error.localizedDescription
        }
    }
}
