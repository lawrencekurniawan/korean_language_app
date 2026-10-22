import SwiftUI

enum LearnRoute: Hashable {
    case chapter(CurriculumChapter)
    case lesson(CurriculumLesson)
    case audio
    case review
}

struct LearnView: View {
    @Environment(AppEnvironment.self) private var env

    @AppStorage("learn.roadmapExpanded") private var roadmapExpanded = false
    @State private var path: [LearnRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: SoriSpacing.lg) {
                    if let error = env.curriculum.loadError {
                        errorCard(error)
                    }

                    continueCard

                    if let summary = env.librarySummary, summary.needsMoreContent {
                        coveragePrompt(summary)
                    }

                    reviewCard
                    curriculumCard
                    roadmapCard
                    footnote
                }
                .padding(SoriSpacing.lg)
                .padding(.bottom, SoriSpacing.xl)
            }
            .soriScreenBackground()
            .navigationTitle("Learn")
            .navigationDestination(for: LearnRoute.self) { route in
                switch route {
                case .chapter(let chapter):
                    ChapterDetailView(chapter: chapter)
                case .lesson(let lesson):
                    LessonDetailView(lesson: lesson)
                case .audio:
                    PersonalAudioView()
                case .review:
                    ReviewView()
                }
            }
            .task {
                await env.prepareCurriculum()
                await env.prepareReview()
                if env.librarySummary == nil {
                    await env.refreshLibrary()
                }

                #if DEBUG
                openDebugDestinationIfNeeded()
                #endif
            }
        }
    }

    @ViewBuilder
    private var continueCard: some View {
        if let lesson = env.curriculum.nextLesson ?? env.curriculum.lastLesson {
            let chapter = env.curriculum.curriculum.chapter(for: lesson)
            let isReview = env.curriculum.isCompleted(lesson.id)

            NavigationLink(value: LearnRoute.lesson(lesson)) {
                SoriCard {
                    VStack(alignment: .leading, spacing: SoriSpacing.md) {
                        HStack {
                            SoriBadge(text: "TOPIK \(lesson.topik)")
                            Spacer()
                            Text("\(lesson.minutes) min")
                                .font(SoriFont.caption)
                                .foregroundStyle(Color.soriSecondary)
                        }

                        VStack(alignment: .leading, spacing: SoriSpacing.xxs) {
                            Text(lesson.title)
                                .font(SoriFont.title)
                                .foregroundStyle(Color.soriInk)
                            Text(continueSubtitle(chapter: chapter, lesson: lesson))
                                .font(SoriFont.callout)
                                .foregroundStyle(Color.soriSecondary)
                        }

                        Text(lesson.summary)
                            .font(SoriFont.body)
                            .foregroundStyle(Color.soriInk)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: SoriSpacing.sm) {
                            Text(isReview ? "Review lesson" : "Continue lesson")
                                .font(SoriFont.headline)
                                .foregroundStyle(Color.soriBackground)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.soriBackground)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.soriAccent)
                        )

                        progressLine
                    }
                }
            }
            .buttonStyle(.plain)
        } else {
            SoriCard {
                SoriEmptyState(
                    symbol: "book.closed",
                    title: "Curriculum unavailable",
                    message: "Reinstall Sori or regenerate the project to restore the bundled lessons."
                )
            }
        }
    }

    private var progressLine: some View {
        let total = env.curriculum.curriculum.totalLessonCount
        let completed = env.curriculum.completedLessonCount
        let fraction = total > 0 ? Double(completed) / Double(total) : 0

        return VStack(alignment: .leading, spacing: 6) {
            ProgressView(value: fraction)
                .tint(.soriAccent)
            Text("\(completed) of \(total) lessons complete")
                .font(SoriFont.caption)
                .foregroundStyle(Color.soriSecondary)
        }
    }

    private func continueSubtitle(
        chapter: CurriculumChapter?,
        lesson: CurriculumLesson
    ) -> String {
        let chapterTitle = chapter.map { "Chapter \($0.number) · \($0.englishTitle)" }
            ?? "Vitamin Korean 1"
        return "\(chapterTitle) · Lesson \(lesson.id)"
    }

    private var curriculumCard: some View {
        SoriCard(padding: SoriSpacing.md) {
            VStack(spacing: 0) {
                SoriSectionHeader(
                    "Curriculum",
                    subtitle: "Vitamin Korean 1 · 5 chapters"
                )
                .padding(.bottom, SoriSpacing.sm)

                ForEach(env.curriculum.curriculum.chapters) { chapter in
                    if chapter.id != env.curriculum.curriculum.chapters.first?.id {
                        Divider().overlay(Color.soriBorder)
                    }

                    NavigationLink(value: LearnRoute.chapter(chapter)) {
                        ChapterRow(
                            chapter: chapter,
                            completed: env.curriculum.completedCount(in: chapter)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var reviewCard: some View {
        NavigationLink(value: LearnRoute.review) {
            SoriCard {
                HStack(spacing: SoriSpacing.md) {
                    Image(systemName: "rectangle.stack")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Color.soriAccent)
                        .frame(width: 42, height: 42)
                        .background(Color.soriAccent.opacity(0.12), in: Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reviews due")
                            .font(SoriFont.headline)
                            .foregroundStyle(Color.soriInk)
                        Text(reviewSubtitle)
                            .font(SoriFont.caption)
                            .foregroundStyle(Color.soriSecondary)
                    }

                    Spacer()

                    Text("\(env.review.dueCount)")
                        .font(SoriFont.stat)
                        .foregroundStyle(
                            env.review.dueCount > 0
                                ? Color.soriAccent
                                : Color.soriTertiary
                        )
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("learn-review")
    }

    private var reviewSubtitle: String {
        if env.review.dueCount > 0 {
            return "Grammar and vocabulary · FSRS"
        }
        if env.review.cards.isEmpty {
            return "Complete a lesson to add cards"
        }
        if let next = env.review.nextDueAt {
            return "Next \(next.formatted(.relative(presentation: .named)))"
        }
        return "Nothing due"
    }

    private func coveragePrompt(_ summary: LibrarySummary) -> some View {
        NavigationLink {
            LibraryView()
        } label: {
            SoriCard {
                HStack(alignment: .center, spacing: SoriSpacing.md) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.soriWarning)
                        .frame(width: 42, height: 42)
                        .background(Color.soriWarning.opacity(0.12), in: Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Library covered")
                            .font(SoriFont.headline)
                            .foregroundStyle(Color.soriInk)
                        Text("You've seen \(Int((summary.coverage * 100).rounded()))% of your active sentences. Add more real Korean to keep practice varied.")
                            .font(SoriFont.caption)
                            .foregroundStyle(Color.soriSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.soriTertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var roadmapCard: some View {
        SoriCard(padding: SoriSpacing.md) {
            VStack(spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        roadmapExpanded.toggle()
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Learning roadmap")
                                .font(SoriFont.headline)
                                .foregroundStyle(Color.soriInk)
                            Text("TOPIK 1 → 6")
                                .font(SoriFont.caption)
                                .foregroundStyle(Color.soriSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.soriSecondary)
                            .rotationEffect(.degrees(roadmapExpanded ? 0 : -90))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if roadmapExpanded {
                    VStack(spacing: SoriSpacing.xs) {
                        ForEach(RoadmapLevel.all) { level in
                            RoadmapLevelRow(
                                level: level,
                                progress: level.id == 1 ? topikOneProgress : nil
                            )
                        }
                    }
                    .padding(.top, SoriSpacing.md)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private var topikOneProgress: Double {
        let total = env.curriculum.curriculum.totalLessonCount
        guard total > 0 else { return 0 }
        return Double(env.curriculum.completedLessonCount) / Double(total)
    }

    private var footnote: some View {
        Text("Lessons are bundled and versioned, so every install gets the same curriculum. Personal textbook audio stays on this iPhone.")
            .font(SoriFont.caption)
            .foregroundStyle(Color.soriSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, SoriSpacing.xs)
    }

    private func errorCard(_ message: String) -> some View {
        SoriCard {
            Label {
                Text(message)
                    .font(SoriFont.caption)
                    .foregroundStyle(Color.soriInk)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.soriWarning)
            }
        }
    }

    #if DEBUG
    private func openDebugDestinationIfNeeded() {
        guard path.isEmpty else { return }
        let arguments = ProcessInfo.processInfo.arguments

        if arguments.contains("--learn-review") {
            path.append(.review)
        } else if arguments.contains("--learn-audio") {
            path.append(.audio)
        } else if arguments.contains("--learn-lesson"),
                  let lesson = env.curriculum.curriculum.lessons.first {
            path.append(.lesson(lesson))
        } else if arguments.contains("--learn-chapter"),
                  let chapter = env.curriculum.curriculum.chapters.first {
            path.append(.chapter(chapter))
        }
    }
    #endif
}

// MARK: - Chapter row

private struct ChapterRow: View {
    let chapter: CurriculumChapter
    let completed: Int

    private var isComplete: Bool {
        completed == chapter.lessons.count
    }

    var body: some View {
        HStack(spacing: SoriSpacing.md) {
            ZStack {
                Circle()
                    .fill(
                        isComplete
                            ? Color.soriCorrect.opacity(0.14)
                            : Color.soriAccent.opacity(0.12)
                    )
                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.soriCorrect)
                } else {
                    Text("\(chapter.number)")
                        .font(SoriFont.captionStrong)
                        .foregroundStyle(Color.soriAccent)
                }
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(chapter.title)
                    .font(SoriFont.callout)
                    .foregroundStyle(Color.soriInk)
                Text(chapter.englishTitle)
                    .font(SoriFont.caption)
                    .foregroundStyle(Color.soriSecondary)
            }

            Spacer(minLength: SoriSpacing.sm)

            Text("\(completed)/\(chapter.lessons.count)")
                .font(SoriFont.captionStrong)
                .foregroundStyle(completed > 0 ? Color.soriAccent : Color.soriTertiary)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.soriTertiary)
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
    }
}

// MARK: - Roadmap

private struct RoadmapLevel: Identifiable {
    let id: Int
    let book: String
    let topic: String
    let status: Status

    enum Status {
        case current
        case planned
    }

    static let all: [RoadmapLevel] = [
        .init(id: 1, book: "Vitamin Korean 1", topic: "TOPIK 1", status: .current),
        .init(id: 2, book: "Vitamin Korean 2", topic: "TOPIK 2", status: .planned),
        .init(id: 3, book: "Vitamin Korean 3", topic: "TOPIK 3", status: .planned),
        .init(id: 4, book: "Vitamin Korean 4", topic: "TOPIK 4", status: .planned),
        .init(id: 5, book: "Vitamin Korean 5", topic: "TOPIK 5", status: .planned),
        .init(id: 6, book: "Vitamin Korean 6", topic: "TOPIK 6", status: .planned)
    ]
}

private struct RoadmapLevelRow: View {
    let level: RoadmapLevel
    let progress: Double?

    var body: some View {
        HStack(spacing: SoriSpacing.sm) {
            Text("\(level.id)")
                .font(SoriFont.captionStrong)
                .foregroundStyle(level.status == .current ? Color.soriAccent : Color.soriTertiary)
                .frame(width: 26, height: 26)
                .background(
                    Circle().fill(
                        level.status == .current
                            ? Color.soriAccent.opacity(0.14)
                            : Color.soriSurfaceElevated
                    )
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(level.book)
                    .font(SoriFont.callout)
                    .foregroundStyle(level.status == .current ? Color.soriInk : Color.soriSecondary)
                HStack(spacing: 6) {
                    Text(level.topic)
                    Text("·")
                    Text(level.status == .current ? "Current level" : "Coming later")
                }
                .font(SoriFont.caption)
                .foregroundStyle(Color.soriSecondary)
            }

            Spacer()

            if let progress, level.status == .current {
                Text("\(Int((progress * 100).rounded()))%")
                    .font(SoriFont.captionStrong)
                    .foregroundStyle(Color.soriAccent)
            } else if level.status == .planned {
                Image(systemName: "lock")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.soriTertiary)
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, SoriSpacing.xs)
    }
}
