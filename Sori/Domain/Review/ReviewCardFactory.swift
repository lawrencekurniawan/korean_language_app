import Foundation

enum ReviewCardFactory {
    /// New cards are due immediately. A one-second offset keeps them due even
    /// when SQLite's date encoding rounds the stored timestamp upward.
    static func cards(for lesson: CurriculumLesson, now: Date = Date()) -> [ReviewCard] {
        let grammar = lesson.grammar.map { point -> ReviewCard in
            let firstExample = point.examples.first.map {
                "\($0.korean) — \($0.english)"
            }
            return ReviewCard(
                id: "grammar:\(point.id)",
                kind: .grammar,
                lessonID: lesson.id,
                front: "\(point.title)\n\(point.pattern)",
                back: point.explanation,
                example: firstExample,
                due: now.addingTimeInterval(-1),
                stability: 0,
                difficulty: 0,
                reps: 0,
                lapses: 0,
                state: .new,
                step: 0,
                lastReview: nil,
                createdAt: now
            )
        }

        let vocabulary = lesson.vocabulary.map { item in
            ReviewCard(
                id: "vocabulary:\(lesson.id):\(item.korean)",
                kind: .vocabulary,
                lessonID: lesson.id,
                front: item.korean,
                back: item.english,
                example: nil,
                due: now.addingTimeInterval(-1),
                stability: 0,
                difficulty: 0,
                reps: 0,
                lapses: 0,
                state: .new,
                step: 0,
                lastReview: nil,
                createdAt: now
            )
        }

        return grammar + vocabulary
    }

    static func cards(for lessons: [CurriculumLesson], now: Date = Date()) -> [ReviewCard] {
        lessons.flatMap { cards(for: $0, now: now) }
    }
}
