import Foundation
import GRDB
import Observation

@MainActor
@Observable
final class ReviewStore {
    @ObservationIgnored private let database: AppDatabase
    @ObservationIgnored private let scheduler: ReviewScheduler

    private(set) var cards: [ReviewCard] = []
    private(set) var dueCards: [ReviewCard] = []
    private(set) var errorMessage: String?

    init(database: AppDatabase, scheduler: ReviewScheduler = ReviewScheduler()) {
        self.database = database
        self.scheduler = scheduler
    }

    var dueCount: Int { dueCards.count }

    var nextDueAt: Date? {
        let now = Date()
        return cards.map(\.due).filter { $0 > now }.min()
    }

    func cards(for lessonID: String) -> [ReviewCard] {
        cards.filter { $0.lessonID == lessonID }
    }

    // MARK: - Loading

    func refresh(now: Date = Date()) async {
        do {
            let loaded = try await database.dbQueue.read { db -> [ReviewCard] in
                let rows = try Row.fetchAll(db, sql: """
                    SELECT id, kind, lessonId, front, back, example, due,
                           stability, difficulty, reps, lapses, state, step,
                           lastReview, createdAt
                      FROM card
                     ORDER BY due ASC, createdAt ASC, id ASC
                    """)
                return rows.compactMap(Self.card(from:))
            }
            cards = loaded
            dueCards = loaded
                .filter { $0.due <= now }
                .sorted { lhs, rhs in
                    if lhs.due != rhs.due { return lhs.due < rhs.due }
                    return lhs.id < rhs.id
                }
            errorMessage = nil
        } catch {
            errorMessage = "Review cards could not be loaded. \(error.localizedDescription)"
        }
    }

    // MARK: - Sync

    /// Creates cards for completed lessons and removes cards for lessons that are
    /// no longer complete. Existing cards keep their FSRS scheduling.
    func sync(
        curriculum: Curriculum,
        completedLessonIDs: Set<String>,
        now: Date = Date()
    ) async {
        guard !curriculum.lessons.isEmpty else {
            await refresh(now: now)
            return
        }

        let completedLessons = curriculum.lessons.filter {
            completedLessonIDs.contains($0.id)
        }
        let expected = ReviewCardFactory.cards(for: completedLessons, now: now)
        let expectedIDs = Set(expected.map(\.id))

        do {
            try await database.dbQueue.write { db in
                for card in expected {
                    try db.execute(
                        sql: """
                            INSERT INTO card
                                (id, kind, lessonId, front, back, example, due,
                                 stability, difficulty, reps, lapses, state, step,
                                 lastReview, createdAt)
                            VALUES (?, ?, ?, ?, ?, ?, ?, 0, 0, 0, 0, 'new', 0, NULL, ?)
                            ON CONFLICT(id) DO UPDATE SET
                                kind = excluded.kind,
                                lessonId = excluded.lessonId,
                                front = excluded.front,
                                back = excluded.back,
                                example = excluded.example
                            """,
                        arguments: [
                            card.id,
                            card.kind.rawValue,
                            card.lessonID,
                            card.front,
                            card.back,
                            card.example,
                            card.due,
                            card.createdAt
                        ]
                    )
                }

                let storedIDs = try String.fetchAll(db, sql: "SELECT id FROM card")
                for cardID in storedIDs where !expectedIDs.contains(cardID) {
                    try db.execute(
                        sql: "DELETE FROM card WHERE id = ?",
                        arguments: [cardID]
                    )
                }
            }
            await refresh(now: now)
        } catch {
            errorMessage = "Review cards could not be prepared. \(error.localizedDescription)"
        }
    }

    // MARK: - Review

    @discardableResult
    func submit(cardID: String, rating: ReviewRating, now: Date = Date()) async -> Bool {
        do {
            let saved = try await database.dbQueue.write { db -> Bool in
                guard let row = try Row.fetchOne(
                    db,
                    sql: """
                        SELECT id, kind, lessonId, front, back, example, due,
                               stability, difficulty, reps, lapses, state, step,
                               lastReview, createdAt
                          FROM card
                         WHERE id = ?
                        """,
                    arguments: [cardID]
                ), let card = Self.card(from: row) else {
                    return false
                }

                let schedule = scheduler.schedule(card, rating: rating, now: now)
                let updated = schedule.card

                try db.execute(
                    sql: """
                        UPDATE card
                           SET due = ?, stability = ?, difficulty = ?, reps = ?,
                               lapses = ?, state = ?, step = ?, lastReview = ?
                         WHERE id = ?
                        """,
                    arguments: [
                        updated.due,
                        updated.stability,
                        updated.difficulty,
                        updated.reps,
                        updated.lapses,
                        updated.state.rawValue,
                        updated.step,
                        updated.lastReview,
                        cardID
                    ]
                )
                try db.execute(
                    sql: """
                        INSERT INTO reviewLog
                            (cardId, rating, reviewedAt, elapsedDays, scheduledDays)
                        VALUES (?, ?, ?, ?, ?)
                        """,
                    arguments: [
                        cardID,
                        rating.rawValue,
                        now,
                        schedule.elapsedDays,
                        schedule.scheduledDays
                    ]
                )
                return true
            }

            if saved {
                await refresh(now: now)
                return true
            } else {
                errorMessage = "That review card no longer exists."
                return false
            }
        } catch {
            errorMessage = "The review could not be saved. \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Mapping

    nonisolated private static func card(from row: Row) -> ReviewCard? {
        guard let kind = ReviewCardKind(rawValue: row["kind"]),
              let state = ReviewCardState(rawValue: row["state"]) else {
            return nil
        }

        return ReviewCard(
            id: row["id"],
            kind: kind,
            lessonID: row["lessonId"],
            front: row["front"],
            back: row["back"],
            example: row["example"],
            due: row["due"],
            stability: row["stability"],
            difficulty: row["difficulty"],
            reps: row["reps"],
            lapses: row["lapses"],
            state: state,
            step: row["step"] ?? 0,
            lastReview: row["lastReview"],
            createdAt: row["createdAt"]
        )
    }
}
