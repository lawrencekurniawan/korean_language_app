import XCTest
@testable import Sori

final class AnswerCheckerTests: XCTestCase {
    private func item(
        kind: CurriculumExerciseKind,
        answer: String,
        acceptedAnswers: [String] = []
    ) -> CurriculumPracticeItem {
        CurriculumPracticeItem(
            id: "test",
            kind: kind,
            prompt: "Prompt",
            answer: answer,
            acceptedAnswers: acceptedAnswers
        )
    }

    func testExactAnswerIgnoresCasePunctuationAndSpacing() throws {
        let evaluation = try XCTUnwrap(
            AnswerChecker.evaluate(
                "  I am a student! ",
                for: item(
                    kind: .translateToEnglish,
                    answer: "I am a student."
                )
            )
        )

        XCTAssertEqual(evaluation.verdict, .correct)
        XCTAssertEqual(evaluation.correctAnswer, "I am a student.")
    }

    func testKoreanSpacingIsForgiving() throws {
        let evaluation = try XCTUnwrap(
            AnswerChecker.evaluate(
                "저는학생입니다",
                for: item(
                    kind: .translateToKorean,
                    answer: "저는 학생입니다."
                )
            )
        )

        XCTAssertEqual(evaluation.verdict, .correct)
    }

    func testAcceptedAlternativeIsCorrect() throws {
        let evaluation = try XCTUnwrap(
            AnswerChecker.evaluate(
                "hat",
                for: item(
                    kind: .translateToEnglish,
                    answer: "cap",
                    acceptedAnswers: ["hat"]
                )
            )
        )

        XCTAssertEqual(evaluation.verdict, .correct)
    }

    func testContractionsMatchExpandedEnglish() throws {
        let evaluation = try XCTUnwrap(
            AnswerChecker.evaluate(
                "I'm a student",
                for: item(
                    kind: .translateToEnglish,
                    answer: "I am a student"
                )
            )
        )

        XCTAssertEqual(evaluation.verdict, .correct)
    }

    func testOneCharacterDifferenceIsAlmost() throws {
        let evaluation = try XCTUnwrap(
            AnswerChecker.evaluate(
                "학생입니더",
                for: item(kind: .fillBlank, answer: "학생입니다")
            )
        )

        XCTAssertEqual(evaluation.verdict, .almost)
        XCTAssertEqual(evaluation.correctAnswer, "학생입니다")
    }

    func testUnrelatedAnswerIsIncorrectAndStillShowsModel() throws {
        let evaluation = try XCTUnwrap(
            AnswerChecker.evaluate(
                "teacher",
                for: item(kind: .translateToEnglish, answer: "student")
            )
        )

        XCTAssertEqual(evaluation.verdict, .incorrect)
        XCTAssertEqual(evaluation.correctAnswer, "student")
    }

    func testEmptyAnswerIsNotEvaluated() {
        XCTAssertNil(
            AnswerChecker.evaluate(
                "   ",
                for: item(kind: .fillBlank, answer: "입니다")
            )
        )
    }

    func testOpenResponseIsNeverMarkedIncorrect() throws {
        let evaluation = try XCTUnwrap(
            AnswerChecker.evaluate(
                "저는 매일 한국어를 공부해요.",
                for: item(
                    kind: .openResponse,
                    answer: "저는 아침에 한국어를 공부해요."
                )
            )
        )

        XCTAssertEqual(evaluation.verdict, .open)
        XCTAssertEqual(evaluation.title, "Response recorded")
        XCTAssertFalse(evaluation.message.isEmpty)
    }

    func testNormalizationFoldsCompatibilityCharacters() {
        XCTAssertEqual(
            AnswerChecker.normalize("  한국어 "),
            AnswerChecker.normalize("한국어")
        )
    }
}
