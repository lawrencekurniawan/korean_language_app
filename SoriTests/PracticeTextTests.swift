import XCTest
@testable import Sori

final class PracticeTextTests: XCTestCase {
    func testCompleteSentencesArePresentable() {
        XCTAssertTrue(PracticeText.isPresentable("안녕하세요."))
        XCTAssertTrue(PracticeText.isPresentable("2000년대 초반이다."))
        XCTAssertTrue(PracticeText.isPresentable("\"안녕\"이라고 했다."))
    }

    func testLeadingPunctuationAndUnfinishedFragmentsAreRejected() {
        XCTAssertFalse(PracticeText.isPresentable(", 한글날 큰잔치 조직위원회 결성"))
        XCTAssertFalse(PracticeText.isPresentable("문장이 끝나지 않음"))
        XCTAssertFalse(PracticeText.isPresentable("…"))
        XCTAssertFalse(PracticeText.isPresentable(""))
    }
}
