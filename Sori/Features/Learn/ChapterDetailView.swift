import SwiftUI

struct ChapterDetailView: View {
    @Environment(AppEnvironment.self) private var env
    let chapter: CurriculumChapter

    private var completed: Int {
        env.curriculum.completedCount(in: chapter)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: SoriSpacing.lg) {
                headerCard
                lessonsCard
                cultureCard
                footnote
            }
            .padding(SoriSpacing.lg)
            .padding(.bottom, SoriSpacing.xl)
        }
        .soriScreenBackground()
        .navigationTitle("Chapter \(chapter.number)")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerCard: some View {
        SoriCard {
            VStack(alignment: .leading, spacing: SoriSpacing.md) {
                HStack {
                    SoriBadge(text: "Chapter \(chapter.number)")
                    Spacer()
                    Text("\(completed)/\(chapter.lessons.count) complete")
                        .font(SoriFont.caption)
                        .foregroundStyle(Color.soriSecondary)
                }

                VStack(alignment: .leading, spacing: SoriSpacing.xxs) {
                    Text(chapter.title)
                        .font(SoriFont.title)
                        .foregroundStyle(Color.soriInk)
                    Text(chapter.englishTitle)
                        .font(SoriFont.callout)
                        .foregroundStyle(Color.soriSecondary)
                }

                Text(chapter.summary)
                    .font(SoriFont.body)
                    .foregroundStyle(Color.soriInk)
                    .fixedSize(horizontal: false, vertical: true)

                ProgressView(
                    value: chapter.lessons.isEmpty
                        ? 0
                        : Double(completed) / Double(chapter.lessons.count)
                )
                .tint(.soriAccent)
            }
        }
    }

    private var lessonsCard: some View {
        SoriCard(padding: SoriSpacing.md) {
            VStack(spacing: 0) {
                SoriSectionHeader("Lessons", subtitle: "3–5 minutes each")
                    .padding(.bottom, SoriSpacing.sm)

                ForEach(chapter.lessons) { lesson in
                    if lesson.id != chapter.lessons.first?.id {
                        Divider().overlay(Color.soriBorder)
                    }

                    NavigationLink(value: LearnRoute.lesson(lesson)) {
                        LessonRow(
                            lesson: lesson,
                            status: env.curriculum.status(for: lesson.id)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("lesson-row-\(lesson.id)")
                }
            }
        }
    }

    private var cultureCard: some View {
        SoriCard {
            VStack(alignment: .leading, spacing: SoriSpacing.sm) {
                Label("Culture", systemImage: "globe.asia.australia")
                    .font(SoriFont.headline)
                    .foregroundStyle(Color.soriInk)

                Text(chapter.culture)
                    .font(SoriFont.body)
                    .foregroundStyle(Color.soriInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var footnote: some View {
        Text("Explanations and examples are original study material aligned with the Vitamin Korean 1 sequence. The textbook itself is not included.")
            .font(SoriFont.caption)
            .foregroundStyle(Color.soriSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, SoriSpacing.xs)
    }
}

private struct LessonRow: View {
    let lesson: CurriculumLesson
    let status: LessonStatus

    var body: some View {
        HStack(spacing: SoriSpacing.md) {
            Image(systemName: iconName)
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(iconColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(lesson.title)
                    .font(SoriFont.callout)
                    .foregroundStyle(Color.soriInk)
                Text(lesson.englishTitle)
                    .font(SoriFont.caption)
                    .foregroundStyle(Color.soriSecondary)
            }

            Spacer(minLength: SoriSpacing.sm)

            Text("\(lesson.minutes) min")
                .font(SoriFont.caption)
                .foregroundStyle(Color.soriTertiary)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.soriTertiary)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private var iconName: String {
        switch status {
        case .notStarted: "circle"
        case .inProgress: "circle.lefthalf.filled"
        case .completed: "checkmark.circle.fill"
        }
    }

    private var iconColor: Color {
        switch status {
        case .notStarted: Color.soriTertiary
        case .inProgress: Color.soriAccent
        case .completed: Color.soriCorrect
        }
    }
}
