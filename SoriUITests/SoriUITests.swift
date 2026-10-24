import XCTest

final class SoriUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "--skip-splash",
            "--tab", "learn",
            "--learn-lesson",
        ]
        app.launch()
    }

    func testLessonPlaybackAndTypedExercise() throws {
        XCTAssertTrue(
            app.staticTexts["Vocabulary"].waitForExistence(timeout: 20),
            "The first lesson should open with its vocabulary section."
        )

        let wordPlay = app.buttons["speak-아이"]
        XCTAssertTrue(wordPlay.waitForExistence(timeout: 5))
        wordPlay.tap()

        let stop = app.buttons["Stop pronunciation"].firstMatch
        XCTAssertTrue(stop.waitForExistence(timeout: 8))
        attachScreenshot(named: "lesson-vocabulary-playing")

        let pronunciationHeading = app.staticTexts["Pronunciation"]
        scrollTo(pronunciationHeading)
        XCTAssertTrue(pronunciationHeading.exists)
        XCTAssertTrue(app.buttons["speak-가"].firstMatch.exists)
        attachScreenshot(named: "lesson-pronunciation")

        let grammarHeading = app.staticTexts["Three shapes build every vowel"]
        scrollTo(grammarHeading)
        XCTAssertTrue(grammarHeading.exists)
        let grammarPlay = app.buttons["speak-ㅏ"].firstMatch
        XCTAssertTrue(grammarPlay.exists)
        attachScreenshot(named: "lesson-grammar")

        let practiceHeading = app.staticTexts["Typed practice"]
        scrollTo(practiceHeading)
        XCTAssertTrue(practiceHeading.exists)

        let exercise = app.descendants(matching: .any)
            .matching(identifier: "exercise-1-1-e1")
            .firstMatch
        scrollTo(exercise)
        XCTAssertTrue(exercise.exists)

        let answer = app.textFields["exercise-answer-1-1-e1"]
        XCTAssertTrue(answer.exists)
        answer.tap()
        answer.typeText("right")

        let check = exercise.buttons["Check answer"]
        XCTAssertTrue(check.exists)
        check.tap()

        XCTAssertTrue(
            app.staticTexts["Correct"].waitForExistence(timeout: 5),
            "A correct answer should show the Correct result card."
        )
        attachScreenshot(named: "lesson-exercise-correct")
    }

    private func scrollTo(_ element: XCUIElement, maxSwipes: Int = 16) {
        var swipes = 0
        while !(element.exists && element.isHittable) && swipes < maxSwipes {
            app.swipeUp()
            swipes += 1
        }
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
