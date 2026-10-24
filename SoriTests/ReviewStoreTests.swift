import GRDB
import XCTest
@testable import Sori

@MainActor
final class ReviewStoreTests: XCTestCase {
    private func curriculum() throws -> Curriculum {
        let bundle = Bundle(for: CurriculumStore.self)
        return try XCTUnwrap(CurriculumStore.loadFromBundle(bundle))
    }

    private func makeStore() throws -> ReviewStore {
        let database = try AppDatabase.inMemory()
        return ReviewStore(database: database)
    }

    func testSyncCreatesCardsOnlyForCompletedLessons() async throws {
        let store = try makeStore()
        let curriculum = try curriculum()

        await store.sync(curriculum: curriculum, completedLessonIDs: [])

        XCTAssertTrue(store.cards.isEmpty)
        XCTAssertEqual(store.dueCount, 0)

        await store.sync(curriculum: curriculum, completedLessonIDs: ["1-1"])

        let lesson = try XCTUnwrap(curriculum.lesson(withID: "1-1"))
        XCTAssertEqual(store.cards.count, lesson.vocabulary.count + lesson.grammar.count)
        XCTAssertEqual(store.dueCount, lesson.vocabulary.count + lesson.grammar.count)
        XCTAssertTrue(store.cards.allSatisfy { $0.lessonID == "1-1" })
        XCTAssertEqual(
            store.cards.filter { $0.kind == .grammar }.count,
            lesson.grammar.count
        )
        XCTAssertEqual(
            store.cards.filter { $0.kind == .vocabulary }.count,
            lesson.vocabulary.count
        )
    }

    func testDashboardCountsCardsCreatedForCompletedLessons() async throws {
        let database = try AppDatabase.inMemory()
        let store = ReviewStore(database: database)
        let curriculum = try curriculum()

        await store.sync(curriculum: curriculum, completedLessonIDs: ["1-1"])

        let lesson = try XCTUnwrap(curriculum.lesson(withID: "1-1"))
        let stats = try await database.dashboardStats()
        XCTAssertEqual(stats.dueCards, lesson.vocabulary.count + lesson.grammar.count)
    }

    func testSyncIsIdempotentAndPreservesScheduling() async throws {
        let store = try makeStore()
        let curriculum = try curriculum()

        await store.sync(curriculum: curriculum, completedLessonIDs: ["1-1"])
        let card = try XCTUnwrap(store.cards.first)
        await store.submit(cardID: card.id, rating: .good)

        let scheduled = try XCTUnwrap(store.cards.first { $0.id == card.id })
        XCTAssertEqual(scheduled.state, .learning)
        XCTAssertEqual(scheduled.reps, 1)

        await store.sync(curriculum: curriculum, completedLessonIDs: ["1-1"])

        let afterSync = try XCTUnwrap(store.cards.first { $0.id == card.id })
        XCTAssertEqual(afterSync.due, scheduled.due)
        XCTAssertEqual(afterSync.state, scheduled.state)
        XCTAssertEqual(afterSync.reps, scheduled.reps)
        let lesson = try XCTUnwrap(curriculum.lesson(withID: "1-1"))
        XCTAssertEqual(store.cards.count, lesson.vocabulary.count + lesson.grammar.count)
    }

    func testSyncRemovesCardsWhenProgressIsReset() async throws {
        let store = try makeStore()
        let curriculum = try curriculum()

        await store.sync(curriculum: curriculum, completedLessonIDs: ["1-1", "1-2"])
        let first = try XCTUnwrap(curriculum.lesson(withID: "1-1"))
        let second = try XCTUnwrap(curriculum.lesson(withID: "1-2"))
        let firstCount = first.vocabulary.count + first.grammar.count
        let secondCount = second.vocabulary.count + second.grammar.count
        XCTAssertEqual(store.cards.count, firstCount + secondCount)

        await store.sync(curriculum: curriculum, completedLessonIDs: ["1-1"])

        XCTAssertEqual(store.cards.count, firstCount)
        XCTAssertFalse(store.cards.contains { $0.lessonID == "1-2" })

        await store.sync(curriculum: curriculum, completedLessonIDs: [])

        XCTAssertTrue(store.cards.isEmpty)
        XCTAssertEqual(store.dueCount, 0)
    }

    func testSyncRemovesCardsForStaleContent() async throws {
        let database = try AppDatabase.inMemory()
        let store = ReviewStore(database: database)
        let curriculum = try curriculum()

        await store.sync(curriculum: curriculum, completedLessonIDs: ["1-1"])

        try await database.dbQueue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO card
                        (id, kind, lessonId, front, back, example, due,
                         stability, difficulty, reps, lapses, state, step,
                         lastReview, createdAt)
                    VALUES
                        ('vocabulary:1-1:stale', 'vocabulary', '1-1', 'stale',
                         'stale', NULL, ?, 0, 0, 0, 0, 'new', 0, NULL, ?)
                    """,
                arguments: [Date(), Date()]
            )
        }

        await store.sync(curriculum: curriculum, completedLessonIDs: ["1-1"])

        let lesson = try XCTUnwrap(curriculum.lesson(withID: "1-1"))
        XCTAssertEqual(store.cards.count, lesson.vocabulary.count + lesson.grammar.count)
        XCTAssertFalse(store.cards.contains { $0.id == "vocabulary:1-1:stale" })
    }

    func testSubmittingReviewUpdatesCardAndWritesLog() async throws {
        let database = try AppDatabase.inMemory()
        let store = ReviewStore(database: database)
        let curriculum = try curriculum()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        await store.sync(curriculum: curriculum, completedLessonIDs: ["1-1"], now: now)

        let card = try XCTUnwrap(store.dueCards.first)
        await store.submit(cardID: card.id, rating: .good, now: now)

        let lesson = try XCTUnwrap(curriculum.lesson(withID: "1-1"))
        XCTAssertEqual(store.dueCount, lesson.vocabulary.count + lesson.grammar.count - 1)

        let updated = try XCTUnwrap(store.cards.first { $0.id == card.id })
        XCTAssertEqual(updated.reps, 1)
        XCTAssertEqual(updated.state, .learning)
        XCTAssertEqual(updated.due, now.addingTimeInterval(600))

        let log = try await database.dbQueue.read { db -> (rating: Int, reviewedAt: Date, scheduledDays: Double)? in
            guard let row = try Row.fetchOne(
                db,
                sql: "SELECT * FROM reviewLog WHERE cardId = ?",
                arguments: [card.id]
            ) else {
                return nil
            }
            return (
                rating: row["rating"],
                reviewedAt: row["reviewedAt"],
                scheduledDays: row["scheduledDays"]
            )
        }
        let entry = try XCTUnwrap(log)
        XCTAssertEqual(entry.rating, ReviewRating.good.rawValue)
        XCTAssertEqual(entry.reviewedAt, now)
        XCTAssertEqual(entry.scheduledDays, 600.0 / 86_400.0, accuracy: 0.000001)
    }

    func testCardFactoryUsesStableIDsAndLessonContent() throws {
        let curriculum = try curriculum()
        let lesson = try XCTUnwrap(curriculum.lesson(withID: "1-1"))
        let first = ReviewCardFactory.cards(for: lesson)
        let second = ReviewCardFactory.cards(for: lesson)

        XCTAssertEqual(first.map(\.id), second.map(\.id))
        XCTAssertEqual(Set(first.map(\.id)).count, first.count)

        let vocabulary = try XCTUnwrap(first.first { $0.kind == .vocabulary })
        XCTAssertEqual(vocabulary.front, "아이")
        XCTAssertEqual(vocabulary.back, "child")

        let grammar = try XCTUnwrap(first.first { $0.kind == .grammar })
        XCTAssertTrue(grammar.front.contains(lesson.grammar[0].title))
        XCTAssertEqual(grammar.back, lesson.grammar[0].explanation)
        XCTAssertNotNil(grammar.example)
    }

    func testStepColumnExistsAfterMigration() async throws {
        let database = try AppDatabase.inMemory()
        let columns = try await database.dbQueue.read { db in
            try db.columns(in: "card").map(\.name)
        }
        XCTAssertTrue(columns.contains("step"))
    }
}
