import Foundation
import GRDB

struct UsageRepository: Sendable {
    let database: AppDatabase

    func record(tab: String, startedAt: Date, endedAt: Date) async throws {
        let duration = max(0, endedAt.timeIntervalSince(startedAt))
        guard duration >= 1 else { return }

        try await database.dbQueue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO usageInterval (tab, startedAt, endedAt, durationSeconds)
                    VALUES (?, ?, ?, ?)
                    """,
                arguments: [tab, startedAt, endedAt, duration]
            )
        }
    }

    func timeByTab() async throws -> [TabUsage] {
        try await database.dbQueue.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT tab, COALESCE(SUM(durationSeconds), 0) AS total
                  FROM usageInterval
                 GROUP BY tab
                 ORDER BY tab
                """)

            return rows.map { row in
                TabUsage(
                    tab: row["tab"],
                    seconds: row["total"]
                )
            }
        }
    }
}
