import XCTest
@testable import Sori

final class CurriculumTests: XCTestCase {
    private func loadCurriculum() throws -> Curriculum {
        let bundle = Bundle(for: CurriculumStore.self)
        return try XCTUnwrap(CurriculumStore.loadFromBundle(bundle))
    }

    func testBundledCurriculumHasFiveChaptersAndFifteenLessons() throws {
        let curriculum = try loadCurriculum()

        XCTAssertEqual(curriculum.curriculumVersion, "1.1.0")
        XCTAssertEqual(curriculum.spine, "Vitamin Korean 1")
        XCTAssertEqual(curriculum.chapters.count, 5)
        XCTAssertEqual(curriculum.lessons.count, 15)

        XCTAssertEqual(
            curriculum.lessons.map(\.id),
            [
                "1-1", "1-2", "1-3",
                "2-1", "2-2", "2-3",
                "3-1", "3-2", "3-3",
                "4-1", "4-2", "4-3",
                "5-1", "5-2", "5-3"
            ]
        )
        XCTAssertEqual(Set(curriculum.lessons.map(\.id)).count, 15)
        XCTAssertEqual(curriculum.chapters.map(\.number), [1, 2, 3, 4, 5])
    }

    func testEveryLessonHasCompleteContent() throws {
        let curriculum = try loadCurriculum()

        for lesson in curriculum.lessons {
            XCTAssertTrue((15...30).contains(lesson.minutes), "\(lesson.id) minutes")
            XCTAssertEqual(lesson.topik, 1, "\(lesson.id) TOPIK")
            XCTAssertTrue((5...6).contains(lesson.goals.count), "\(lesson.id) goals")
            XCTAssertTrue(lesson.vocabulary.count >= 16, "\(lesson.id) vocabulary")
            XCTAssertTrue(lesson.grammar.count >= 4, "\(lesson.id) grammar")
            XCTAssertEqual(lesson.practice.count, 8, "\(lesson.id) practice")
            XCTAssertTrue(lesson.pronunciation.count >= 6, "\(lesson.id) pronunciation")
            XCTAssertEqual(Set(lesson.vocabulary.map(\.korean)).count, lesson.vocabulary.count,
                           "\(lesson.id) duplicate vocabulary")
            XCTAssertFalse(lesson.summary.isEmpty, "\(lesson.id) summary")
            XCTAssertFalse(lesson.culture.isEmpty, "\(lesson.id) culture")
            XCTAssertFalse(lesson.reference.isEmpty, "\(lesson.id) reference")
            XCTAssertTrue(lesson.reference[0].hasPrefix("Vitamin Korean 1"),
                          "\(lesson.id) should put VK1 first")
            XCTAssertFalse(lesson.audioTracks.isEmpty, "\(lesson.id) audio")

            for point in lesson.grammar {
                XCTAssertFalse(point.title.isEmpty)
                XCTAssertFalse(point.pattern.isEmpty)
                XCTAssertFalse(point.explanation.isEmpty)
                XCTAssertFalse(point.examples.isEmpty)
                XCTAssertFalse(point.tip.isEmpty)
            }

            let kinds = Set(lesson.practice.map(\.kind))
            XCTAssertEqual(kinds, Set(CurriculumExerciseKind.allCases),
                           "\(lesson.id) exercise kinds")
            XCTAssertEqual(Set(lesson.practice.map(\.id)).count, lesson.practice.count,
                           "\(lesson.id) duplicate exercise ids")
            for exercise in lesson.practice {
                XCTAssertFalse(exercise.prompt.isEmpty, "\(lesson.id) prompt")
                XCTAssertFalse(exercise.answer.isEmpty, "\(lesson.id) answer")
                if exercise.kind == .fillBlank {
                    XCTAssertTrue(exercise.prompt.contains("____"),
                                  "\(exercise.id) fill blank marker")
                }
            }
        }
    }

    func testTypedExercisesCoverEverySkillInEveryLesson() throws {
        let curriculum = try loadCurriculum()

        for lesson in curriculum.lessons {
            let counts = Dictionary(grouping: lesson.practice, by: \.kind)
                .mapValues(\.count)
            XCTAssertGreaterThanOrEqual(counts[.fillBlank] ?? 0, 2, lesson.id)
            XCTAssertGreaterThanOrEqual(counts[.translateToKorean] ?? 0, 2, lesson.id)
            XCTAssertGreaterThanOrEqual(counts[.translateToEnglish] ?? 0, 2, lesson.id)
            XCTAssertGreaterThanOrEqual(counts[.openResponse] ?? 0, 2, lesson.id)
        }
    }

    func testAudioTracksCoverOneThroughNinetyFourOnce() throws {
        let curriculum = try loadCurriculum()
        let tracks = curriculum.lessons.flatMap(\.audioTracks)

        XCTAssertEqual(tracks.count, 94)
        XCTAssertEqual(Set(tracks), Set(1...94))
    }

    func testTrackLookupUsesLessonRanges() throws {
        let curriculum = try loadCurriculum()

        XCTAssertEqual(curriculum.lesson(forTrack: 1)?.id, "1-1")
        XCTAssertEqual(curriculum.lesson(forTrack: 6)?.id, "1-1")
        XCTAssertEqual(curriculum.lesson(forTrack: 7)?.id, "1-2")
        XCTAssertEqual(curriculum.lesson(forTrack: 50)?.id, "3-2")
        XCTAssertEqual(curriculum.lesson(forTrack: 94)?.id, "5-3")
        XCTAssertNil(curriculum.lesson(forTrack: 95))
    }

    func testChapterLookupFindsParentForLesson() throws {
        let curriculum = try loadCurriculum()
        let lesson = try XCTUnwrap(curriculum.lesson(withID: "4-2"))

        XCTAssertEqual(curriculum.chapter(for: lesson)?.number, 4)
    }
}
