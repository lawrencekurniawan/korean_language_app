import Foundation

/// Net typing CPM counts correct non-space characters only. Errors and spaces
/// are excluded from the numerator; every non-space typed character is in the
/// denominator of gross CPM and accuracy.
struct TypingMetrics: Sendable, Equatable {
    let correctCharacters: Int
    let typedCharacters: Int
    let errorCharacters: Int
    let netCPM: Double
    let grossCPM: Double
    let accuracy: Double

    static func calculate(
        target: String,
        input: String,
        completedCorrectCharacters: Int,
        completedTypedCharacters: Int,
        elapsedSeconds: Double
    ) -> TypingMetrics {
        let targetCharacters = Array(target)
        let inputCharacters = Array(input)
        let comparedCount = min(targetCharacters.count, inputCharacters.count)

        var currentCorrect = 0
        if comparedCount > 0 {
            for index in 0..<comparedCount {
                let character = inputCharacters[index]
                if character == targetCharacters[index], !character.isWhitespace {
                    currentCorrect += 1
                }
            }
        }

        let currentTyped = inputCharacters.reduce(into: 0) { count, character in
            if !character.isWhitespace { count += 1 }
        }
        var currentMismatches = 0
        for (index, character) in inputCharacters.enumerated() {
            if index >= targetCharacters.count || character != targetCharacters[index] {
                currentMismatches += 1
            }
        }
        let correct = max(completedCorrectCharacters, 0) + currentCorrect
        let typed = max(completedTypedCharacters, 0) + currentTyped
        let errors = max(typed - correct, currentMismatches)
        let seconds = max(elapsedSeconds, 0.001)
        let minutes = seconds / 60

        return TypingMetrics(
            correctCharacters: correct,
            typedCharacters: typed,
            errorCharacters: errors,
            netCPM: Double(correct) / minutes,
            grossCPM: Double(typed) / minutes,
            accuracy: typed > 0 ? Double(correct) / Double(typed) : 0
        )
    }
}
