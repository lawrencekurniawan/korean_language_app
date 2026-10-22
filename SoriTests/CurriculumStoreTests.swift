import XCTest
@testable import Sori

@MainActor
final class CurriculumStoreTests: XCTestCase {
    private func makeCurriculum() throws -> Curriculum {
        let bundle = Bundle(for: CurriculumStore.self)
        return try XCTUnwrap(CurriculumStore.loadFromBundle(bundle))
    }

    func testProgressStartsEmptyAndPointsAtFirstLesson() async throws {
        let database = try AppDatabase.inMemory()
        let store = CurriculumStore(database: database, curriculum: try makeCurriculum())

        XCTAssertEqual(store.status(for: "1-1"), .notStarted)
        XCTAssertEqual(store.nextLesson?.id, "1-1")
        XCTAssertEqual(store.completedLessonCount, 0)
        XCTAssertEqual(store.completedCount(in: try XCTUnwrap(store.curriculum.chapters.first)), 0)
    }

    func testMarkOpenedWritesInProgressAcrossReloads() async throws {
        let database = try AppDatabase.inMemory()
        let curriculum = try makeCurriculum()
        let store = CurriculumStore(database: database, curriculum: curriculum)

        await store.markOpened("1-1")

        XCTAssertEqual(store.status(for: "1-1"), .inProgress)
        XCTAssertEqual(store.nextLesson?.id, "1-1")

        let reopened = CurriculumStore(database: database, curriculum: curriculum)
        await reopened.refresh()
        XCTAssertEqual(reopened.status(for: "1-1"), .inProgress)
    }

    func testCompletingALessonAdvancesTheContinueCard() async throws {
        let database = try AppDatabase.inMemory()
        let store = CurriculumStore(database: database, curriculum: try makeCurriculum())

        await store.complete("1-1")

        XCTAssertEqual(store.status(for: "1-1"), .completed)
        XCTAssertEqual(store.completedLessonCount, 1)
        XCTAssertEqual(store.nextLesson?.id, "1-2")
        XCTAssertEqual(
            store.completedCount(in: try XCTUnwrap(store.curriculum.chapters.first)),
            1
        )
    }

    func testCompletedLessonIsNotDowngradedWhenReopened() async throws {
        let database = try AppDatabase.inMemory()
        let store = CurriculumStore(database: database, curriculum: try makeCurriculum())

        await store.complete("2-1")
        await store.markOpened("2-1")

        XCTAssertEqual(store.status(for: "2-1"), .completed)
        XCTAssertNotNil(store.progress["2-1"]?.completedAt)
    }

    func testResetClearsEveryLesson() async throws {
        let database = try AppDatabase.inMemory()
        let store = CurriculumStore(database: database, curriculum: try makeCurriculum())

        await store.complete("1-1")
        await store.complete("1-2")
        await store.resetProgress()

        XCTAssertEqual(store.completedLessonCount, 0)
        XCTAssertEqual(store.status(for: "1-1"), .notStarted)
        XCTAssertEqual(store.nextLesson?.id, "1-1")
    }
}
