import GRDB
import XCTest
@testable import Sori

final class UsageRepositoryTests: XCTestCase {
    func testRecordSumsTimeByTab() async throws {
        let database = try AppDatabase.inMemory()
        let repository = UsageRepository(database: database)
        let base = Date(timeIntervalSince1970: 1_800_000_000)

        try await repository.record(
            tab: "learn",
            startedAt: base,
            endedAt: base.addingTimeInterval(120)
        )
        try await repository.record(
            tab: "practice",
            startedAt: base.addingTimeInterval(120),
            endedAt: base.addingTimeInterval(180)
        )
        try await repository.record(
            tab: "learn",
            startedAt: base.addingTimeInterval(180),
            endedAt: base.addingTimeInterval(210)
        )

        let usage = try await repository.timeByTab()

        XCTAssertEqual(usage.count, 2)
        XCTAssertEqual(usage.first { $0.tab == "learn" }?.seconds, 150)
        XCTAssertEqual(usage.first { $0.tab == "practice" }?.seconds, 60)
    }

    func testIntervalsShorterThanOneSecondAreDiscarded() async throws {
        let database = try AppDatabase.inMemory()
        let repository = UsageRepository(database: database)
        let base = Date(timeIntervalSince1970: 1_800_000_000)

        try await repository.record(
            tab: "learn",
            startedAt: base,
            endedAt: base.addingTimeInterval(0.4)
        )

        let count = try await database.dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM usageInterval") ?? 0
        }
        XCTAssertEqual(count, 0)

        let usage = try await repository.timeByTab()
        XCTAssertTrue(usage.isEmpty)
    }
}
