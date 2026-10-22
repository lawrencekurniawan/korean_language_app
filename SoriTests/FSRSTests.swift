import XCTest
@testable import Sori

final class FSRSTests: XCTestCase {
    private let scheduler = ReviewScheduler()

    func testRetrievabilityFallsOverTime() {
        XCTAssertEqual(
            scheduler.retrievability(stability: 10, elapsedDays: 0),
            1,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            scheduler.retrievability(stability: 10, elapsedDays: 10),
            0.9,
            accuracy: 0.0001
        )
        XCTAssertLessThan(
            scheduler.retrievability(stability: 10, elapsedDays: 30),
            0.9
        )
    }

    func testInitialStabilityFollowsRatingOrder() {
        XCTAssertLessThan(
            scheduler.initialStability(.again),
            scheduler.initialStability(.hard)
        )
        XCTAssertLessThan(
            scheduler.initialStability(.hard),
            scheduler.initialStability(.good)
        )
        XCTAssertLessThan(
            scheduler.initialStability(.good),
            scheduler.initialStability(.easy)
        )
    }

    func testNewCardGoodEntersLearningThenGraduates() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let card = makeCard(now: now)

        let first = scheduler.schedule(card, rating: .good, now: now)
        XCTAssertEqual(first.card.state, .learning)
        XCTAssertEqual(first.card.step, 1)
        XCTAssertEqual(first.card.reps, 1)
        XCTAssertEqual(first.card.due.timeIntervalSince(now), 600, accuracy: 0.01)

        let second = scheduler.schedule(
            first.card,
            rating: .good,
            now: now.addingTimeInterval(600)
        )
        XCTAssertEqual(second.card.state, .review)
        XCTAssertEqual(second.card.step, 0)
        XCTAssertEqual(
            second.card.due.timeIntervalSince(now.addingTimeInterval(600)),
            3 * 86_400,
            accuracy: 1
        )
    }

    func testNewCardEasyGraduatesImmediately() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let result = scheduler.schedule(makeCard(now: now), rating: .easy, now: now)

        XCTAssertEqual(result.card.state, .review)
        XCTAssertEqual(result.card.due.timeIntervalSince(now), 16 * 86_400, accuracy: 1)
        XCTAssertEqual(result.card.reps, 1)
    }

    func testAgainOnReviewCardEntersRelearningAndCountsLapse() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let card = makeCard(
            now: now,
            due: now,
            stability: 10,
            difficulty: 5,
            reps: 4,
            lapses: 1,
            state: .review,
            lastReview: now.addingTimeInterval(-10 * 86_400)
        )

        let result = scheduler.schedule(card, rating: .again, now: now)

        XCTAssertEqual(result.card.state, .relearning)
        XCTAssertEqual(result.card.lapses, 2)
        XCTAssertEqual(result.card.reps, 5)
        XCTAssertLessThan(result.card.stability, card.stability)
        XCTAssertEqual(result.card.due.timeIntervalSince(now), 600, accuracy: 0.01)
    }

    func testGoodOnDueReviewCardIncreasesStability() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let card = makeCard(
            now: now,
            due: now,
            stability: 10,
            difficulty: 5,
            reps: 4,
            lapses: 0,
            state: .review,
            lastReview: now.addingTimeInterval(-10 * 86_400)
        )

        let result = scheduler.schedule(card, rating: .good, now: now)

        XCTAssertEqual(result.card.state, .review)
        XCTAssertGreaterThan(result.card.stability, card.stability)
        XCTAssertGreaterThan(result.scheduledDays, 10)
    }

    func testDifficultyStaysWithinBounds() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        var card = makeCard(
            now: now,
            due: now,
            stability: 10,
            difficulty: 9.9,
            reps: 10,
            lapses: 0,
            state: .review,
            lastReview: now.addingTimeInterval(-10 * 86_400)
        )

        for _ in 0..<20 {
            card = scheduler.schedule(card, rating: .again, now: now).card
            XCTAssertGreaterThanOrEqual(card.difficulty, 1)
            XCTAssertLessThanOrEqual(card.difficulty, 10)
        }
    }

    private func makeCard(
        now: Date,
        due: Date? = nil,
        stability: Double = 0,
        difficulty: Double = 0,
        reps: Int = 0,
        lapses: Int = 0,
        state: ReviewCardState = .new,
        lastReview: Date? = nil
    ) -> ReviewCard {
        ReviewCard(
            id: "test",
            kind: .vocabulary,
            lessonID: "1-1",
            front: "안녕",
            back: "hello",
            example: nil,
            due: due ?? now,
            stability: stability,
            difficulty: difficulty,
            reps: reps,
            lapses: lapses,
            state: state,
            step: 0,
            lastReview: lastReview,
            createdAt: now
        )
    }
}
