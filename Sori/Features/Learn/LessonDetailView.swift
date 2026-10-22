import SwiftUI
import UniformTypeIdentifiers

struct LessonDetailView: View {
    @Environment(AppEnvironment.self) private var env
    let lesson: CurriculumLesson

    @State private var player = PersonalAudioPlayer()
    @State private var revealedAnswers: Set<Int> = []
    @State private var showingImporter = false
    @State private var alertMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: SoriSpacing.lg) {
                headerCard
                goalsCard
                vocabularyCard
                grammarSections
                if !lesson.dialogue.isEmpty {
                    dialogueCard
                }
                practiceCard
                cultureCard
                referenceCard
                audioCard
                completionCard
            }
            .padding(SoriSpacing.lg)
            .padding(.bottom, SoriSpacing.xl)
        }
        .soriScreenBackground()
        .navigationTitle("Lesson \(lesson.id)")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("lesson-detail-\(lesson.id)")
        .task {
            await env.curriculum.markOpened(lesson.id)
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

    // MARK: - Header

    private var headerCard: some View {
        SoriCard {
            VStack(alignment: .leading, spacing: SoriSpacing.md) {
                HStack(spacing: SoriSpacing.xs) {
                    SoriBadge(text: "TOPIK \(lesson.topik)")
                    SoriBadge(text: "\(lesson.minutes) min", tint: .soriSecondary)
                    Spacer()
                }

                VStack(alignment: .leading, spacing: SoriSpacing.xxs) {
                    Text(lesson.title)
                        .font(SoriFont.korean(32))
                        .foregroundStyle(Color.soriInk)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(lesson.englishTitle)
                        .font(SoriFont.callout)
                        .foregroundStyle(Color.soriSecondary)
                }

                Text(lesson.summary)
                    .font(SoriFont.body)
                    .foregroundStyle(Color.soriInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var goalsCard: some View {
        SoriCard {
            VStack(alignment: .leading, spacing: SoriSpacing.sm) {
                Text("By the end of this lesson")
                    .font(SoriFont.captionStrong)
                    .foregroundStyle(Color.soriSecondary)

                ForEach(lesson.goals, id: \.self) { goal in
                    Label {
                        Text(goal)
                            .font(SoriFont.body)
                            .foregroundStyle(Color.soriInk)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(Color.soriAccent)
                    }
                }
            }
        }
    }

    // MARK: - Vocabulary

    private var vocabularyCard: some View {
        SoriCard {
            VStack(alignment: .leading, spacing: SoriSpacing.sm) {
                SoriSectionHeader("Vocabulary", subtitle: "\(lesson.vocabulary.count) words")

                VStack(spacing: 0) {
                    ForEach(lesson.vocabulary.indices, id: \.self) { index in
                        if index > 0 {
                            Divider().overlay(Color.soriBorder)
                        }
                        let item = lesson.vocabulary[index]
                        HStack(alignment: .firstTextBaseline) {
                            Text(item.korean)
                                .font(SoriFont.korean(19))
                                .foregroundStyle(Color.soriInk)
                            Spacer(minLength: SoriSpacing.md)
                            Text(item.english)
                                .font(SoriFont.callout)
                                .foregroundStyle(Color.soriSecondary)
                                .multilineTextAlignment(.trailing)
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
        }
    }

    // MARK: - Grammar

    private var grammarSections: some View {
        VStack(spacing: SoriSpacing.md) {
            ForEach(lesson.grammar) { point in
                GrammarCard(point: point)
            }
        }
    }

    // MARK: - Dialogue

    private var dialogueCard: some View {
        SoriCard {
            VStack(alignment: .leading, spacing: SoriSpacing.md) {
                SoriSectionHeader("Dialogue", subtitle: "Read it aloud")

                ForEach(lesson.dialogue.indices, id: \.self) { index in
                    let line = lesson.dialogue[index]
                    VStack(alignment: .leading, spacing: 3) {
                        Text(line.speaker)
                            .font(SoriFont.captionStrong)
                            .foregroundStyle(Color.soriAccent)
                        Text(line.korean)
                            .font(SoriFont.korean(19))
                            .foregroundStyle(Color.soriInk)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(line.english)
                            .font(SoriFont.caption)
                            .foregroundStyle(Color.soriSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    // MARK: - Practice

    private var practiceCard: some View {
        SoriCard {
            VStack(alignment: .leading, spacing: SoriSpacing.md) {
                SoriSectionHeader("Practice", subtitle: "Answer, then check")

                ForEach(lesson.practice.indices, id: \.self) { index in
                    let item = lesson.practice[index]
                    VStack(alignment: .leading, spacing: SoriSpacing.xs) {
                        Text(item.prompt)
                            .font(SoriFont.body)
                            .foregroundStyle(Color.soriInk)
                            .fixedSize(horizontal: false, vertical: true)

                        if revealedAnswers.contains(index) {
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.soriCorrect)
                                Text(item.answer)
                                    .font(SoriFont.callout)
                                    .foregroundStyle(Color.soriInk)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(SoriSpacing.sm)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                Color.soriCorrect.opacity(0.10),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                        } else {
                            Button("Show answer") {
                                revealedAnswers.insert(index)
                            }
                            .font(SoriFont.captionStrong)
                            .foregroundStyle(Color.soriAccent)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Culture and reference

    private var cultureCard: some View {
        SoriCard {
            VStack(alignment: .leading, spacing: SoriSpacing.sm) {
                Label("Culture", systemImage: "globe.asia.australia")
                    .font(SoriFont.headline)
                    .foregroundStyle(Color.soriInk)
                Text(lesson.culture)
                    .font(SoriFont.body)
                    .foregroundStyle(Color.soriInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var referenceCard: some View {
        SoriCard {
            VStack(alignment: .leading, spacing: SoriSpacing.sm) {
                Text("Reference")
                    .font(SoriFont.captionStrong)
                    .foregroundStyle(Color.soriSecondary)

                ForEach(lesson.reference, id: \.self) { reference in
                    HStack(alignment: .top, spacing: 6) {
                        Text("·")
                        Text(reference)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .font(SoriFont.caption)
                    .foregroundStyle(Color.soriSecondary)
                }

                Text("Explanations and examples are original study material.")
                    .font(SoriFont.caption)
                    .foregroundStyle(Color.soriTertiary)
            }
        }
    }

    // MARK: - Audio

    private var audioCard: some View {
        let tracks = env.personalAudio.tracks(for: lesson)

        return SoriCard {
            VStack(alignment: .leading, spacing: SoriSpacing.md) {
                SoriSectionHeader("Textbook audio", subtitle: "Personal study files") {
                    if !tracks.isEmpty {
                        SoriBadge(text: "\(tracks.count)", tint: .soriSecondary)
                    }
                }

                if tracks.isEmpty {
                    Text("Import your personal Vitamin Korean 1 MP3s to hear this lesson. Files remain on this iPhone, never enter the library, and are excluded from iCloud backup.")
                        .font(SoriFont.caption)
                        .foregroundStyle(Color.soriSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    VStack(spacing: 0) {
                        ForEach(tracks) { track in
                            if track.id != tracks.first?.id {
                                Divider().overlay(Color.soriBorder)
                            }
                            audioRow(track)
                        }
                    }

                    Text("Tracks are matched to this lesson by number. Matching is best effort; use All personal audio to reach every imported track.")
                        .font(SoriFont.caption)
                        .foregroundStyle(Color.soriTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: SoriSpacing.sm) {
                    Button {
                        showingImporter = true
                    } label: {
                        Label("Import audio", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(SoriSecondaryButtonStyle())

                    NavigationLink(value: LearnRoute.audio) {
                        Text("All audio")
                            .font(SoriFont.callout)
                            .foregroundStyle(Color.soriInk)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.soriSurfaceElevated)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(Color.soriBorder, lineWidth: 1)
                            )
                    }
                }
            }
        }
    }

    private func audioRow(_ track: PersonalAudioTrack) -> some View {
        Button {
            player.toggle(track)
        } label: {
            HStack(spacing: SoriSpacing.sm) {
                Image(systemName: isPlaying(track) ? "stop.circle.fill" : "play.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.soriAccent)
                Text(track.displayName)
                    .font(SoriFont.callout)
                    .foregroundStyle(Color.soriInk)
                Spacer()
                Text(isPlaying(track) ? "Playing" : "Play")
                    .font(SoriFont.caption)
                    .foregroundStyle(Color.soriSecondary)
            }
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func isPlaying(_ track: PersonalAudioTrack) -> Bool {
        player.currentTrackID == track.id && player.isPlaying
    }

    // MARK: - Completion

    private var completionCard: some View {
        SoriCard {
            VStack(alignment: .leading, spacing: SoriSpacing.md) {
                if env.curriculum.isCompleted(lesson.id) {
                    Label("Lesson complete", systemImage: "checkmark.seal.fill")
                        .font(SoriFont.headline)
                        .foregroundStyle(Color.soriCorrect)

                    Text("Review cards for this lesson's grammar and vocabulary will appear when the review milestone lands.")
                        .font(SoriFont.caption)
                        .foregroundStyle(Color.soriSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let next = nextLesson {
                        NavigationLink(value: LearnRoute.lesson(next)) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Next lesson")
                                        .font(SoriFont.caption)
                                        .foregroundStyle(Color.soriSecondary)
                                    Text(next.title)
                                        .font(SoriFont.callout)
                                        .foregroundStyle(Color.soriInk)
                                }
                                Spacer()
                                Image(systemName: "arrow.right")
                                    .foregroundStyle(Color.soriAccent)
                            }
                            .padding(SoriSpacing.sm)
                            .background(
                                Color.soriAccent.opacity(0.10),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Button {
                        Task { await env.curriculum.complete(lesson.id) }
                    } label: {
                        Label("Mark lesson complete", systemImage: "checkmark.circle.fill")
                    }
                    .buttonStyle(SoriPrimaryButtonStyle())
                    .accessibilityIdentifier("lesson-complete")

                    Text("Completing the lesson records your progress on this iPhone. Nothing is uploaded.")
                        .font(SoriFont.caption)
                        .foregroundStyle(Color.soriSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var nextLesson: CurriculumLesson? {
        let lessons = env.curriculum.curriculum.lessons
        guard let index = lessons.firstIndex(where: { $0.id == lesson.id }),
              lessons.indices.contains(index + 1) else {
            return nil
        }
        return lessons[index + 1]
    }

    // MARK: - Import

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

// MARK: - Grammar card

private struct GrammarCard: View {
    let point: CurriculumGrammarPoint

    var body: some View {
        SoriCard {
            VStack(alignment: .leading, spacing: SoriSpacing.sm) {
                Text(point.title)
                    .font(SoriFont.headline)
                    .foregroundStyle(Color.soriInk)

                Text(point.pattern)
                    .font(SoriFont.mono)
                    .foregroundStyle(Color.soriAccent)
                    .padding(.horizontal, SoriSpacing.sm)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        Color.soriAccent.opacity(0.10),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )

                Text(point.explanation)
                    .font(SoriFont.body)
                    .foregroundStyle(Color.soriInk)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: SoriSpacing.xs) {
                    ForEach(point.examples, id: \.self) { example in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(example.korean)
                                .font(SoriFont.korean(18))
                                .foregroundStyle(Color.soriInk)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(example.english)
                                .font(SoriFont.caption)
                                .foregroundStyle(Color.soriSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "lightbulb")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.soriWarning)
                    Text(point.tip)
                        .font(SoriFont.caption)
                        .foregroundStyle(Color.soriSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
