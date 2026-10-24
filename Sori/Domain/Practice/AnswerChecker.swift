import Foundation

enum PracticeVerdict: String, Sendable, Equatable {
    case correct
    case almost
    case incorrect
    case open

    var isCorrect: Bool { self == .correct }
}

struct PracticeEvaluation: Sendable, Equatable {
    let verdict: PracticeVerdict
    let title: String
    let message: String
    let correctAnswer: String
    let explanation: String?

    var showsAnswer: Bool { true }
}

enum AnswerChecker {
    static func evaluate(
        _ input: String,
        for item: CurriculumPracticeItem
    ) -> PracticeEvaluation? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if item.kind.isOpen {
            return PracticeEvaluation(
                verdict: .open,
                title: "Response recorded",
                message: "There is no single correct answer. Compare your response with the model answer and notice one phrase you can reuse.",
                correctAnswer: item.answer,
                explanation: item.explanation
            )
        }

        let normalizedInput = normalize(trimmed)
        let candidates = ([item.answer] + item.acceptedAnswers)
            .map(normalize)
            .filter { !$0.isEmpty }

        if candidates.contains(normalizedInput) {
            return PracticeEvaluation(
                verdict: .correct,
                title: "Correct",
                message: "Your answer matches the model answer.",
                correctAnswer: item.answer,
                explanation: item.explanation
            )
        }

        if candidates.contains(where: { isNearMatch(normalizedInput, $0) }) {
            return PracticeEvaluation(
                verdict: .almost,
                title: "Almost",
                message: "The meaning is right. Check the spelling, spacing, or ending against the model answer.",
                correctAnswer: item.answer,
                explanation: item.explanation
            )
        }

        return PracticeEvaluation(
            verdict: .incorrect,
            title: "Not quite",
            message: "Compare your answer with the model answer, then try again.",
            correctAnswer: item.answer,
            explanation: item.explanation
        )
    }

    /// Case, punctuation, and whitespace are forgiving. Korean spacing varies
    /// between learners and textbook styles, so it is removed as well.
    static func normalize(_ text: String) -> String {
        var folded = text
            .precomposedStringWithCanonicalMapping
            .lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "‘", with: "'")

        for (short, long) in contractions {
            folded = folded.replacingOccurrences(of: short, with: long)
        }

        let withoutPunctuation = folded.unicodeScalars.filter { scalar in
            !CharacterSet.punctuationCharacters.contains(scalar)
                && !CharacterSet.symbols.contains(scalar)
                && !CharacterSet.whitespacesAndNewlines.contains(scalar)
        }

        return String(String.UnicodeScalarView(withoutPunctuation))
    }

    private static let contractions: [(String, String)] = [
        ("i'm", "i am"),
        ("you're", "you are"),
        ("we're", "we are"),
        ("they're", "they are"),
        ("he's", "he is"),
        ("she's", "she is"),
        ("it's", "it is"),
        ("that's", "that is"),
        ("there's", "there is"),
        ("what's", "what is"),
        ("let's", "let us"),
        ("don't", "do not"),
        ("doesn't", "does not"),
        ("didn't", "did not"),
        ("isn't", "is not"),
        ("aren't", "are not"),
        ("wasn't", "was not"),
        ("weren't", "were not"),
        ("can't", "cannot"),
        ("won't", "will not"),
        ("wouldn't", "would not"),
        ("couldn't", "could not"),
        ("shouldn't", "should not"),
        ("hasn't", "has not"),
        ("haven't", "have not"),
        ("hadn't", "had not"),
    ]

    static func isNearMatch(_ lhs: String, _ rhs: String) -> Bool {
        let a = Array(lhs)
        let b = Array(rhs)
        guard !a.isEmpty, !b.isEmpty else { return false }
        let distance = editDistance(a, b)
        if max(a.count, b.count) >= 8 {
            return distance <= 2
        }
        return distance == 1 && min(a.count, b.count) >= 3
    }

    private static func editDistance(_ a: [Character], _ b: [Character]) -> Int {
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }

        var previous = Array(0...b.count)
        var current = [Int](repeating: 0, count: b.count + 1)

        for i in 1...a.count {
            current[0] = i
            for j in 1...b.count {
                let substitution = previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1)
                current[j] = min(
                    previous[j] + 1,
                    current[j - 1] + 1,
                    substitution
                )
            }
            swap(&previous, &current)
        }

        return previous[b.count]
    }
}
