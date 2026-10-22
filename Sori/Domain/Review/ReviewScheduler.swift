import Foundation

/// A compact FSRS-5 scheduler with Anki-style learning steps for new and lapsed
/// cards. Review scheduling uses the FSRS stability and difficulty model; the
/// desired retention is 90%. The scheduler is pure so it can be tested without a
/// database or a clock.
struct ReviewScheduler: Sendable {
    static let defaultWeights: [Double] = [
        0.40255, 1.18385, 3.173, 15.69105,
        7.1949, 0.5345, 1.4604, 0.0046,
        1.54575, 0.1192, 1.01925, 1.9395,
        0.11, 0.29605, 2.2698, 0.2315,
        2.9898, 0.51655, 0.6621
    ]

    static let factor = 19.0 / 81.0
    static let decay = -0.5

    static let againStep: TimeInterval = 60
    static let hardStep: TimeInterval = 5 * 60
    static let goodStep: TimeInterval = 10 * 60

    let weights: [Double]
    let desiredRetention: Double

    init(
        weights: [Double] = ReviewScheduler.defaultWeights,
        desiredRetention: Double = 0.90
    ) {
        precondition(weights.count >= 17, "FSRS needs at least 17 weights")
        self.weights = weights
        self.desiredRetention = min(max(desiredRetention, 0.70), 0.97)
    }

    // MARK: - Model

    func retrievability(stability: Double, elapsedDays: Double) -> Double {
        guard stability > 0 else { return 0 }
        let elapsed = max(0, elapsedDays)
        return pow(1 + Self.factor * elapsed / stability, Self.decay)
    }

    func initialStability(_ rating: ReviewRating) -> Double {
        max(0.1, weights[rating.rawValue - 1])
    }

    func initialDifficulty(_ rating: ReviewRating) -> Double {
        let value = weights[4] - exp(weights[5] * Double(rating.rawValue - 1)) + 1
        return clampDifficulty(value)
    }

    func nextDifficulty(_ difficulty: Double, rating: ReviewRating) -> Double {
        let delta = -weights[6] * Double(rating.rawValue - 3)
        let reverted = weights[7] * initialDifficulty(.easy)
            + (1 - weights[7]) * (difficulty + delta)
        return clampDifficulty(reverted)
    }

    func nextRecallStability(
        difficulty: Double,
        stability: Double,
        retrievability: Double,
        rating: ReviewRating
    ) -> Double {
        let hardPenalty = rating == .hard ? weights[15] : 1
        let easyBonus = rating == .easy ? weights[16] : 1
        let growth = exp(weights[8])
            * (11 - difficulty)
            * pow(stability, -weights[9])
            * (exp((1 - retrievability) * weights[10]) - 1)
            * hardPenalty
            * easyBonus
        return max(0.1, stability * (1 + growth))
    }

    func nextForgetStability(
        difficulty: Double,
        stability: Double,
        retrievability: Double
    ) -> Double {
        let value = weights[11]
            * pow(difficulty, -weights[12])
            * (pow(stability + 1, weights[13]) - 1)
            * exp((1 - retrievability) * weights[14])
        return max(0.1, value)
    }

    func nextIntervalDays(stability: Double) -> Double {
        let raw = stability / Self.factor
            * (pow(desiredRetention, 1 / Self.decay) - 1)
        return max(1, raw.rounded())
    }

    // MARK: - Scheduling

    func schedule(
        _ card: ReviewCard,
        rating: ReviewRating,
        now: Date = Date()
    ) -> ReviewSchedule {
        var updated = card
        let elapsedDays = card.lastReview.map {
            max(0, now.timeIntervalSince($0) / 86_400)
        } ?? 0
        let retrievabilityNow = retrievability(
            stability: max(card.stability, 0.01),
            elapsedDays: elapsedDays
        )

        updated.reps += 1
        updated.lastReview = now

        let scheduledDays: Double

        switch card.state {
        case .new:
            updated.stability = initialStability(rating)
            updated.difficulty = initialDifficulty(rating)

            switch rating {
            case .again:
                updated.state = .learning
                updated.step = 0
                scheduledDays = Self.againStep / 86_400
                updated.due = now.addingTimeInterval(Self.againStep)
            case .hard:
                updated.state = .learning
                updated.step = 0
                scheduledDays = Self.hardStep / 86_400
                updated.due = now.addingTimeInterval(Self.hardStep)
            case .good:
                updated.state = .learning
                updated.step = 1
                scheduledDays = Self.goodStep / 86_400
                updated.due = now.addingTimeInterval(Self.goodStep)
            case .easy:
                updated.state = .review
                updated.step = 0
                scheduledDays = nextIntervalDays(stability: updated.stability)
                updated.due = now.addingTimeInterval(scheduledDays * 86_400)
            }

        case .learning, .relearning:
            let wasRelearning = card.state == .relearning
            let baseDifficulty = card.difficulty > 0
                ? card.difficulty
                : initialDifficulty(rating)
            updated.difficulty = nextDifficulty(baseDifficulty, rating: rating)
            updated.state = card.state

            switch rating {
            case .again:
                updated.step = 0
                updated.stability = wasRelearning
                    ? max(
                        0.1,
                        nextForgetStability(
                            difficulty: baseDifficulty,
                            stability: max(card.stability, 0.1),
                            retrievability: retrievabilityNow
                        )
                    )
                    : max(0.1, initialStability(.again))
                scheduledDays = Self.againStep / 86_400
                updated.due = now.addingTimeInterval(Self.againStep)

            case .hard:
                scheduledDays = Self.hardStep / 86_400
                updated.due = now.addingTimeInterval(Self.hardStep)

            case .good, .easy:
                let canGraduate = wasRelearning || rating == .easy || card.step >= 1
                if canGraduate {
                    updated.state = .review
                    updated.step = 0
                    let floor = wasRelearning ? 1.0 : initialStability(rating)
                    updated.stability = max(card.stability, floor)
                    scheduledDays = nextIntervalDays(stability: updated.stability)
                    updated.due = now.addingTimeInterval(scheduledDays * 86_400)
                } else {
                    updated.state = .learning
                    updated.step = 1
                    scheduledDays = Self.goodStep / 86_400
                    updated.due = now.addingTimeInterval(Self.goodStep)
                }
            }

        case .review:
            updated.state = .review
            updated.step = 0
            let baseDifficulty = card.difficulty > 0
                ? card.difficulty
                : initialDifficulty(rating)
            updated.difficulty = nextDifficulty(baseDifficulty, rating: rating)

            if rating == .again {
                updated.lapses += 1
                updated.state = .relearning
                updated.stability = nextForgetStability(
                    difficulty: baseDifficulty,
                    stability: max(card.stability, 0.1),
                    retrievability: retrievabilityNow
                )
                scheduledDays = Self.goodStep / 86_400
                updated.due = now.addingTimeInterval(Self.goodStep)
            } else {
                updated.stability = nextRecallStability(
                    difficulty: baseDifficulty,
                    stability: max(card.stability, 0.1),
                    retrievability: retrievabilityNow,
                    rating: rating
                )
                scheduledDays = nextIntervalDays(stability: updated.stability)
                updated.due = now.addingTimeInterval(scheduledDays * 86_400)
            }
        }

        return ReviewSchedule(
            card: updated,
            elapsedDays: elapsedDays,
            scheduledDays: scheduledDays
        )
    }

    private func clampDifficulty(_ value: Double) -> Double {
        min(max(value, 1), 10)
    }
}
