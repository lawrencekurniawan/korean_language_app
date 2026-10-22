import XCTest
@testable import Sori

final class CurriculumTests: XCTestCase {
    private func loadCurriculum() throws -> Curriculum {
        let bundle = Bundle(for: CurriculumStore.self)
        return try XCTUnwrap(CurriculumStore.loadFromBundle(bundle))
    }

    func testBundledCurriculumHasFiveChaptersAndFifteenLessons() throws {
        let curriculum = try loadCurriculum()

        XCTAssertEqual(curriculum.curriculumVersion, "1.0.0")
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
            XCTAssertTrue((3...5).contains(lesson.minutes), "\(lesson.id) minutes")
            XCTAssertEqual(lesson.topik, 1, "\(lesson.id) TOPIK")
            XCTAssertTrue((3...4).contains(lesson.goals.count), "\(lesson.id) goals")
            XCTAssertEqual(lesson.vocabulary.count, 6, "\(lesson.id) vocabulary")
            XCTAssertEqual(lesson.grammar.count, 3, "\(lesson.id) grammar")
            XCTAssertEqual(lesson.practice.count, 3, "\(lesson.id) practice")
            XCTAssertFalse(lesson.summary.isEmpty, "\(lesson.id) summary")
            XCTAssertFalse(lesson.culture.isEmpty, "\(lesson.id) culture")
            XCTAssertFalse(lesson.reference.isEmpty, "\(lesson.id) reference")
            XCTAssertFalse(lesson.audioTracks.isEmpty, "\(lesson.id) audio")

            for point in lesson.grammar {
                XCTAssertFalse(point.title.isEmpty)
                XCTAssertFalse(point.pattern.isEmpty)
                XCTAssertFalse(point.explanation.isEmpty)
                XCTAssertFalse(point.examples.isEmpty)
                XCTAssertFalse(point.tip.isEmpty)
            }
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
