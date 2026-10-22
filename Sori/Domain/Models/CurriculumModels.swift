import Foundation

// MARK: - Curriculum

struct Curriculum: Decodable, Sendable, Hashable {
    let curriculumVersion: String
    let spine: String
    let reference: String
    let chapters: [CurriculumChapter]

    static let empty = Curriculum(
        curriculumVersion: "0.0.0",
        spine: "",
        reference: "",
        chapters: []
    )

    var lessons: [CurriculumLesson] {
        chapters.flatMap(\.lessons)
    }

    var totalLessonCount: Int {
        lessons.count
    }

    func lesson(withID id: String) -> CurriculumLesson? {
        lessons.first { $0.id == id }
    }

    func chapter(for lesson: CurriculumLesson) -> CurriculumChapter? {
        chapters.first { chapter in
            chapter.lessons.contains { $0.id == lesson.id }
        }
    }

    func lesson(forTrack number: Int) -> CurriculumLesson? {
        lessons.first { $0.audioTracks.contains(number) }
    }
}

struct CurriculumChapter: Identifiable, Decodable, Sendable, Hashable {
    let id: String
    let number: Int
    let title: String
    let englishTitle: String
    let summary: String
    let culture: String
    let lessons: [CurriculumLesson]

    var displayTitle: String {
        "Chapter \(number) · \(title)"
    }
}

struct CurriculumLesson: Identifiable, Decodable, Sendable, Hashable {
    let id: String
    let number: Int
    let title: String
    let englishTitle: String
    let summary: String
    let topik: Int
    let minutes: Int
    let goals: [String]
    let vocabulary: [CurriculumVocabulary]
    let grammar: [CurriculumGrammarPoint]
    let dialogue: [CurriculumDialogueLine]
    let practice: [CurriculumPracticeItem]
    let culture: String
    let reference: [String]
    let audioTracks: [Int]
}

struct CurriculumVocabulary: Decodable, Sendable, Hashable {
    let korean: String
    let english: String
}

struct CurriculumGrammarPoint: Identifiable, Decodable, Sendable, Hashable {
    let id: String
    let title: String
    let pattern: String
    let explanation: String
    let examples: [CurriculumExample]
    let tip: String
}

struct CurriculumExample: Decodable, Sendable, Hashable {
    let korean: String
    let english: String
}

struct CurriculumDialogueLine: Decodable, Sendable, Hashable {
    let speaker: String
    let korean: String
    let english: String
}

struct CurriculumPracticeItem: Decodable, Sendable, Hashable {
    let prompt: String
    let answer: String
}

// MARK: - Progress

enum LessonStatus: String, Sendable, CaseIterable {
    case notStarted
    case inProgress
    case completed

    var title: String {
        switch self {
        case .notStarted: "Not started"
        case .inProgress: "In progress"
        case .completed: "Completed"
        }
    }
}

struct LessonProgress: Identifiable, Sendable, Equatable {
    let lessonID: String
    var status: LessonStatus
    var lastOpenedAt: Date?
    var completedAt: Date?
    var secondsSpent: Double

    var id: String { lessonID }
}
