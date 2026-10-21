import Foundation

/// Reading CPM is based on the furthest completed sentence, not the sentence
/// currently on screen. Going back with Previous never lowers the count.
struct ReadingMetrics: Sendable, Equatable {
    let completedCharacters: Int
    let completedSentences: Int
    let elapsedSeconds: Double
    let cpm: Double

    static func calculate(
        sentences: [PracticeSentence],
        completedCount: Int,
        elapsedSeconds: Double
    ) -> ReadingMetrics {
        let count = min(max(completedCount, 0), sentences.count)
        let characters = sentences.prefix(count).reduce(into: 0) { total, sentence in
            total += TextNormalizer.nonWhitespaceCount(sentence.text)
        }
        let seconds = max(elapsedSeconds, 0.001)
        let cpm = Double(characters) / (seconds / 60)

        return ReadingMetrics(
            completedCharacters: characters,
            completedSentences: count,
            elapsedSeconds: seconds,
            cpm: cpm
        )
    }
}
