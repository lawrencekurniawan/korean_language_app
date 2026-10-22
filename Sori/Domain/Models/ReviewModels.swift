import Foundation

enum ReviewCardKind: String, Sendable, CaseIterable {
    case grammar
    case vocabulary

    var title: String {
        switch self {
        case .grammar: "Grammar"
        case .vocabulary: "Vocabulary"
        }
    }

    var symbolName: String {
        switch self {
        case .grammar: "text.book.closed"
        case .vocabulary: "character.book.closed"
        }
    }
}

enum ReviewCardState: String, Sendable, CaseIterable {
    case new
    case learning
    case review
    case relearning

    var title: String {
        switch self {
        case .new: "New"
        case .learning: "Learning"
        case .review: "Review"
        case .relearning: "Relearning"
        }
    }
}

enum ReviewRating: Int, Sendable, CaseIterable, Identifiable {
    case again = 1
    case hard = 2
    case good = 3
    case easy = 4

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .again: "Again"
        case .hard: "Hard"
        case .good: "Good"
        case .easy: "Easy"
        }
    }

    var symbolName: String {
        switch self {
        case .again: "arrow.counterclockwise"
        case .hard: "tortoise"
        case .good: "checkmark"
        case .easy: "hare"
        }
    }
}

struct ReviewCard: Identifiable, Sendable, Equatable {
    let id: String
    let kind: ReviewCardKind
    let lessonID: String
    let front: String
    let back: String
    let example: String?
    var due: Date
    var stability: Double
    var difficulty: Double
    var reps: Int
    var lapses: Int
    var state: ReviewCardState
    var step: Int
    var lastReview: Date?
    let createdAt: Date

    var isNew: Bool { state == .new }
}

struct ReviewSchedule: Sendable {
    let card: ReviewCard
    let elapsedDays: Double
    let scheduledDays: Double
}
