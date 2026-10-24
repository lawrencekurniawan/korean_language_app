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
    let pronunciation: [CurriculumPronunciation]
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

struct CurriculumPronunciation: Decodable, Sendable, Hashable {
    let korean: String
    let english: String
    let focus: String
}

enum CurriculumExerciseKind: String, Codable, Sendable, Hashable, CaseIterable {
    case fillBlank
    case translateToKorean
    case translateToEnglish
    case openResponse

    var title: String {
        switch self {
        case .fillBlank: "Fill in the blank"
        case .translateToKorean: "English → Korean"
        case .translateToEnglish: "Korean → English"
        case .openResponse: "Open response"
        }
    }

    var symbol: String {
        switch self {
        case .fillBlank: "rectangle.and.pencil.and.ellipsis"
        case .translateToKorean: "arrow.right"
        case .translateToEnglish: "arrow.left"
        case .openResponse: "text.bubble"
        }
    }

    var placeholder: String {
        switch self {
        case .fillBlank: "Type the missing word"
        case .translateToKorean: "Type your answer in Korean"
        case .translateToEnglish: "Type your answer in English"
        case .openResponse: "Write your own answer"
        }
    }

    var isOpen: Bool { self == .openResponse }
}

struct CurriculumPracticeItem: Identifiable, Decodable, Sendable, Hashable {
    let id: String
    let kind: CurriculumExerciseKind
    let prompt: String
    let answer: String
    let acceptedAnswers: [String]
    let hint: String?
    let explanation: String?

    private enum CodingKeys: String, CodingKey {
        case id, kind, prompt, answer, acceptedAnswers, hint, explanation
    }

    init(
        id: String,
        kind: CurriculumExerciseKind,
        prompt: String,
        answer: String,
        acceptedAnswers: [String] = [],
        hint: String? = nil,
        explanation: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.prompt = prompt
        self.answer = answer
        self.acceptedAnswers = acceptedAnswers
        self.hint = hint
        self.explanation = explanation
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let promptValue = try container.decode(String.self, forKey: .prompt)
        prompt = promptValue
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? promptValue
        kind = try container.decodeIfPresent(CurriculumExerciseKind.self, forKey: .kind)
            ?? .openResponse
        answer = try container.decode(String.self, forKey: .answer)
        acceptedAnswers = try container.decodeIfPresent(
            [String].self,
            forKey: .acceptedAnswers
        ) ?? []
        hint = try container.decodeIfPresent(String.self, forKey: .hint)
        explanation = try container.decodeIfPresent(String.self, forKey: .explanation)
    }
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
