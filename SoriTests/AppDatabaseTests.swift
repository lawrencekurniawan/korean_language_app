import XCTest
@testable import Sori

final class AppDatabaseTests: XCTestCase {
    func testInMemoryDatabaseMigrates() throws {
        let database = try AppDatabase.inMemory()
        XCTAssertTrue(try database.healthCheck())
    }

    func testDashboardStartsEmpty() async throws {
        let database = try AppDatabase.inMemory()
        let stats = try await database.dashboardStats()

        XCTAssertEqual(stats.streakDays, 0)
        XCTAssertNil(stats.bestReadingCPM)
        XCTAssertNil(stats.bestTypingCPM)
        XCTAssertEqual(stats.dueCards, 0)
        XCTAssertEqual(stats.minutesThisWeek, 0)
        XCTAssertEqual(stats.lessonsCompleted, 0)
    }

    func testCoreTablesExist() throws {
        let database = try AppDatabase.inMemory()
        let tables = try database.tableNames()

        for expected in [
            "article", "sentence", "articleSentence", "sentenceExposure",
            "practiceSession", "usageInterval", "lessonProgress",
            "card", "reviewLog", "libraryPack", "appMeta"
        ] {
            XCTAssertTrue(tables.contains(expected), "Missing table \(expected)")
        }
    }
}
