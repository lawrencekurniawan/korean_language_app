import Foundation

struct ReadingSessionInput: Sendable {
    let startedAt: Date
    let endedAt: Date
    let durationSeconds: Double
    let plannedSeconds: Int
    let completedCharacters: Int
    let completedSentences: Int
    let cpm: Double
    let fontSize: Double
}

struct PracticeSessionRecord: Identifiable, Sendable, Equatable {
    let id: Int64
    let skill: String
    let startedAt: Date
    let endedAt: Date
    let durationSeconds: Double
    let plannedSeconds: Int
    let characters: Int
    let sentences: Int
    let cpmNet: Double
    let cpmGross: Double
    let accuracy: Double
    let articleID: Int64?
    let fontSize: Double?

    var skillTitle: String {
        skill == "typing" ? "Typing" : "Reading"
    }
}

struct TypingSessionInput: Sendable {
    let startedAt: Date
    let endedAt: Date
    let durationSeconds: Double
    let plannedSeconds: Int
    let typedCharacters: Int
    let correctCharacters: Int
    let errorCharacters: Int
    let completedSentences: Int
    let cpmNet: Double
    let cpmGross: Double
    let accuracy: Double
    let fontSize: Double
    let keyboardMode: String
}
