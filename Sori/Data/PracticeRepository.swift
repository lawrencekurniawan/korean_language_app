import Foundation
import GRDB

struct PracticeRepository: Sendable {
    let database: AppDatabase

    @discardableResult
    func saveReadingSession(
        _ input: ReadingSessionInput,
        exposedSentenceIDs: [Int64]
    ) async throws -> Int64 {
        try await database.dbQueue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO practiceSession
                        (skill, startedAt, endedAt, durationSeconds, plannedSeconds,
                         chars, correctChars, inputChars, errors, sentences,
                         cpmNet, cpmGross, accuracy, articleId, fontSize,
                         keyboardMode, createdAt)
                    VALUES
                        ('reading', ?, ?, ?, ?, ?, ?, 0, 0, ?, ?, ?, 1, NULL, ?, NULL, ?)
                    """,
                arguments: [
                    input.startedAt,
                    input.endedAt,
                    input.durationSeconds,
                    input.plannedSeconds,
                    input.completedCharacters,
                    input.completedCharacters,
                    input.completedSentences,
                    input.cpm,
                    input.cpm,
                    input.fontSize,
                    Date()
                ]
            )
            let sessionID = db.lastInsertedRowID
            try LibraryRepository.recordExposure(
                sentenceIDs: exposedSentenceIDs,
                surface: "reading",
                in: db
            )
            return sessionID
        }
    }

    @discardableResult
    func saveTypingSession(
        _ input: TypingSessionInput,
        exposedSentenceIDs: [Int64]
    ) async throws -> Int64 {
        try await database.dbQueue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO practiceSession
                        (skill, startedAt, endedAt, durationSeconds, plannedSeconds,
                         chars, correctChars, inputChars, errors, sentences,
                         cpmNet, cpmGross, accuracy, articleId, fontSize,
                         keyboardMode, createdAt)
                    VALUES
                        ('typing', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, ?, ?, ?)
                    """,
                arguments: [
                    input.startedAt,
                    input.endedAt,
                    input.durationSeconds,
                    input.plannedSeconds,
                    input.typedCharacters,
                    input.correctCharacters,
                    input.typedCharacters,
                    input.errorCharacters,
                    input.completedSentences,
                    input.cpmNet,
                    input.cpmGross,
                    input.accuracy,
                    input.fontSize,
                    input.keyboardMode,
                    Date()
                ]
            )
            let sessionID = db.lastInsertedRowID
            try LibraryRepository.recordExposure(
                sentenceIDs: exposedSentenceIDs,
                surface: "typing",
                in: db
            )
            return sessionID
        }
    }

    func recentSessions(limit: Int = 5) async throws -> [PracticeSessionRecord] {
        try await database.dbQueue.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT id, skill, startedAt, endedAt, durationSeconds, plannedSeconds,
                       chars, sentences, cpmNet, cpmGross, accuracy, articleId, fontSize
                  FROM practiceSession
                 ORDER BY startedAt DESC, id DESC
                 LIMIT ?
                """, arguments: [limit])

            return rows.map { row in
                PracticeSessionRecord(
                    id: row["id"],
                    skill: row["skill"],
                    startedAt: row["startedAt"],
                    endedAt: row["endedAt"],
                    durationSeconds: row["durationSeconds"],
                    plannedSeconds: row["plannedSeconds"],
                    characters: row["chars"],
                    sentences: row["sentences"],
                    cpmNet: row["cpmNet"],
                    cpmGross: row["cpmGross"],
                    accuracy: row["accuracy"],
                    articleID: row["articleId"],
                    fontSize: row["fontSize"]
                )
            }
        }
    }

    func cpmSamples(since: Date? = nil) async throws -> [CPMSessionSample] {
        try await database.dbQueue.read { db in
            let rows: [Row]
            if let since {
                rows = try Row.fetchAll(
                    db,
                    sql: """
                        SELECT startedAt, skill, cpmNet
                          FROM practiceSession
                         WHERE startedAt >= ?
                         ORDER BY startedAt ASC, id ASC
                        """,
                    arguments: [since]
                )
            } else {
                rows = try Row.fetchAll(
                    db,
                    sql: """
                        SELECT startedAt, skill, cpmNet
                          FROM practiceSession
                         ORDER BY startedAt ASC, id ASC
                        """
                )
            }

            return rows.compactMap { row in
                guard let skill = PracticeSkill(rawValue: row["skill"]) else {
                    return nil
                }
                return CPMSessionSample(
                    startedAt: row["startedAt"],
                    skill: skill,
                    cpm: row["cpmNet"]
                )
            }
        }
    }

    func deleteSession(id: Int64) async throws {
        try await database.dbQueue.write { db in
            try db.execute(
                sql: "DELETE FROM practiceSession WHERE id = ?",
                arguments: [id]
            )
        }
    }
}
