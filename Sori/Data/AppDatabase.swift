import Foundation
import GRDB

/// Owns the SQLite database. The app uses one database for both user data and the
/// practice library, so charts and corpus queries can share a connection.
final class AppDatabase: Sendable {
    let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue) throws {
        self.dbQueue = dbQueue
        try Self.migrator.migrate(dbQueue)
    }

    // MARK: - Locations

    static func onDisk() throws -> AppDatabase {
        let fileManager = FileManager.default
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent("Sori", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        var configuration = Configuration()
        configuration.foreignKeysEnabled = true
        configuration.prepareDatabase { db in
            try db.execute(sql: "PRAGMA journal_mode = WAL")
            try db.execute(sql: "PRAGMA synchronous = NORMAL")
        }

        let queue = try DatabaseQueue(
            path: directory.appendingPathComponent("sori.sqlite").path,
            configuration: configuration
        )
        return try AppDatabase(dbQueue: queue)
    }

    static func inMemory() throws -> AppDatabase {
        var configuration = Configuration()
        configuration.foreignKeysEnabled = true
        return try AppDatabase(dbQueue: DatabaseQueue(configuration: configuration))
    }

    // MARK: - Health

    func healthCheck() throws -> Bool {
        try dbQueue.read { db in
            try db.tableExists("practiceSession") && db.tableExists("sentence")
        }
    }

    func tableNames() throws -> [String] {
        try dbQueue.read { db in
            try String.fetchAll(
                db,
                sql: "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name"
            )
        }
    }

    // MARK: - Metadata

    func metaValue(forKey key: String) async throws -> String? {
        try await dbQueue.read { db in
            try String.fetchOne(db, sql: "SELECT value FROM appMeta WHERE key = ?", arguments: [key])
        }
    }

    func setMetaValue(_ value: String, forKey key: String) async throws {
        try await dbQueue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO appMeta (key, value) VALUES (?, ?)
                    ON CONFLICT(key) DO UPDATE SET value = excluded.value
                    """,
                arguments: [key, value]
            )
        }
    }

    // MARK: - Dashboard

    func dashboardStats() async throws -> DashboardStats {
        try await dbQueue.read { db in
            try Self.dashboardStats(in: db)
        }
    }

    private static func dashboardStats(in db: Database) throws -> DashboardStats {
        let bestReading = try Double.fetchOne(
            db,
            sql: "SELECT MAX(cpmNet) FROM practiceSession WHERE skill = 'reading'"
        )
        let bestTyping = try Double.fetchOne(
            db,
            sql: "SELECT MAX(cpmNet) FROM practiceSession WHERE skill = 'typing'"
        )

        let dueCards = try Int.fetchOne(
            db,
            sql: "SELECT COUNT(*) FROM card WHERE due <= ?",
            arguments: [Date()]
        ) ?? 0

        let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let weekSeconds = try Double.fetchOne(
            db,
            sql: "SELECT COALESCE(SUM(durationSeconds), 0) FROM practiceSession WHERE startedAt >= ?",
            arguments: [weekStart]
        ) ?? 0

        let lessonsCompleted = try Int.fetchOne(
            db,
            sql: "SELECT COUNT(*) FROM lessonProgress WHERE status = 'completed'"
        ) ?? 0

        let dayStrings = try String.fetchAll(db, sql: """
            SELECT DISTINCT date(startedAt, 'localtime') FROM practiceSession
            UNION
            SELECT DISTINCT date(completedAt, 'localtime')
              FROM lessonProgress
             WHERE completedAt IS NOT NULL
            """)

        return DashboardStats(
            streakDays: streak(from: Set(dayStrings)),
            bestReadingCPM: bestReading,
            bestTypingCPM: bestTyping,
            dueCards: dueCards,
            minutesThisWeek: Int((weekSeconds / 60).rounded()),
            lessonsCompleted: lessonsCompleted
        )
    }

    private static func streak(from days: Set<String>) -> Int {
        guard !days.isEmpty else { return 0 }

        var calendar = Calendar.current
        calendar.firstWeekday = 2
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"

        let today = calendar.startOfDay(for: Date())
        var cursor = today
        if !days.contains(formatter.string(from: today)) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else {
                return 0
            }
            cursor = yesterday
        }

        var count = 0
        while days.contains(formatter.string(from: cursor)) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }
            cursor = previous
        }
        return count
    }

    // MARK: - Schema

    private static let migrator: DatabaseMigrator = {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1") { db in
            try db.create(table: "article") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("title", .text).notNull()
                t.column("source", .text).notNull()
                t.column("sourceURL", .text)
                t.column("license", .text)
                t.column("attribution", .text)
                t.column("kind", .text).notNull().defaults(to: "prose")
                t.column("contentHash", .text).notNull().unique()
                t.column("byteSize", .integer).notNull().defaults(to: 0)
                t.column("importedAt", .datetime).notNull()
                t.column("isArchived", .boolean).notNull().defaults(to: false)
            }

            try db.create(table: "sentence") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("text", .text).notNull()
                t.column("normalizedText", .text).notNull()
                t.column("textHash", .text).notNull().unique()
                t.column("charCount", .integer).notNull()
                t.column("eojeolCount", .integer).notNull()
                t.column("difficulty", .integer).notNull().defaults(to: 1)
                t.column("register", .text).notNull().defaults(to: "neutral")
                t.column("createdAt", .datetime).notNull()
            }

            try db.create(table: "articleSentence") { t in
                t.column("articleId", .integer)
                    .notNull()
                    .references("article", onDelete: .cascade)
                t.column("sentenceId", .integer)
                    .notNull()
                    .references("sentence", onDelete: .cascade)
                t.column("orderIndex", .integer).notNull()
                t.primaryKey(["articleId", "sentenceId"])
            }

            try db.create(table: "sentenceExposure") { t in
                t.column("sentenceId", .integer)
                    .primaryKey()
                    .references("sentence", onDelete: .cascade)
                t.column("lastSeenAt", .datetime).notNull()
                t.column("count", .integer).notNull().defaults(to: 0)
                t.column("lastSurface", .text)
            }

            try db.create(table: "practiceSession") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("skill", .text).notNull()
                t.column("startedAt", .datetime).notNull()
                t.column("endedAt", .datetime).notNull()
                t.column("durationSeconds", .double).notNull()
                t.column("plannedSeconds", .integer).notNull()
                t.column("chars", .integer).notNull().defaults(to: 0)
                t.column("correctChars", .integer).notNull().defaults(to: 0)
                t.column("inputChars", .integer).notNull().defaults(to: 0)
                t.column("errors", .integer).notNull().defaults(to: 0)
                t.column("sentences", .integer).notNull().defaults(to: 0)
                t.column("cpmNet", .double).notNull().defaults(to: 0)
                t.column("cpmGross", .double).notNull().defaults(to: 0)
                t.column("accuracy", .double).notNull().defaults(to: 0)
                t.column("articleId", .integer)
                    .references("article", onDelete: .setNull)
                t.column("fontSize", .double)
                t.column("keyboardMode", .text)
                t.column("createdAt", .datetime).notNull()
            }

            try db.create(table: "usageInterval") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("tab", .text).notNull()
                t.column("startedAt", .datetime).notNull()
                t.column("endedAt", .datetime).notNull()
                t.column("durationSeconds", .double).notNull()
            }

            try db.create(table: "lessonProgress") { t in
                t.column("lessonId", .text).primaryKey()
                t.column("status", .text).notNull().defaults(to: "notStarted")
                t.column("lastOpenedAt", .datetime)
                t.column("completedAt", .datetime)
                t.column("secondsSpent", .double).notNull().defaults(to: 0)
            }

            try db.create(table: "card") { t in
                t.column("id", .text).primaryKey()
                t.column("kind", .text).notNull()
                t.column("lessonId", .text).notNull()
                t.column("front", .text).notNull()
                t.column("back", .text).notNull()
                t.column("example", .text)
                t.column("due", .datetime).notNull()
                t.column("stability", .double).notNull().defaults(to: 0)
                t.column("difficulty", .double).notNull().defaults(to: 0)
                t.column("reps", .integer).notNull().defaults(to: 0)
                t.column("lapses", .integer).notNull().defaults(to: 0)
                t.column("state", .text).notNull().defaults(to: "new")
                t.column("lastReview", .datetime)
                t.column("createdAt", .datetime).notNull()
            }
            try db.create(
                index: "index_card_on_due",
                on: "card",
                columns: ["due"]
            )

            try db.create(table: "reviewLog") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("cardId", .text)
                    .notNull()
                    .references("card", onDelete: .cascade)
                t.column("rating", .integer).notNull()
                t.column("reviewedAt", .datetime).notNull()
                t.column("elapsedDays", .double).notNull()
                t.column("scheduledDays", .double).notNull()
            }

            try db.create(table: "libraryPack") { t in
                t.column("id", .text).primaryKey()
                t.column("source", .text).notNull()
                t.column("title", .text).notNull()
                t.column("license", .text)
                t.column("sourceURL", .text)
                t.column("byteSize", .integer).notNull().defaults(to: 0)
                t.column("downloadedAt", .datetime).notNull()
                t.column("isArchived", .boolean).notNull().defaults(to: false)
            }

            try db.create(table: "appMeta") { t in
                t.column("key", .text).primaryKey()
                t.column("value", .text).notNull()
            }

            try db.execute(sql: """
                CREATE INDEX index_sentence_on_difficulty
                ON sentence (difficulty)
                """)
            try db.execute(sql: """
                CREATE INDEX index_practiceSession_on_startedAt
                ON practiceSession (startedAt)
                """)
            try db.execute(sql: """
                CREATE INDEX index_usageInterval_on_startedAt
                ON usageInterval (startedAt)
                """)
            try db.execute(sql: """
                CREATE INDEX index_articleSentence_on_article
                ON articleSentence (articleId, orderIndex)
                """)

            try db.execute(
                sql: "INSERT INTO appMeta (key, value) VALUES (?, ?)",
                arguments: ["schemaVersion", "1"]
            )
            try db.execute(
                sql: "INSERT INTO appMeta (key, value) VALUES (?, ?)",
                arguments: ["curriculumVersion", "0.1.0"]
            )
        }

        migrator.registerMigration("v2") { db in
            try db.alter(table: "card") { t in
                t.add(column: "step", .integer).notNull().defaults(to: 0)
            }
            try db.execute(
                sql: "UPDATE appMeta SET value = ? WHERE key = ?",
                arguments: ["2", "schemaVersion"]
            )
        }

        return migrator
    }()
}
