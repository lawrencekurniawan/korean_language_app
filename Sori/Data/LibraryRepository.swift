import Foundation
import GRDB

struct LibraryRepository: Sendable {
    let database: AppDatabase

    func summary() async throws -> LibrarySummary {
        try await database.dbQueue.read { db in
            let articleCount = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM article WHERE isArchived = 0"
            ) ?? 0
            let totalBytes = try Int.fetchOne(
                db,
                sql: "SELECT COALESCE(SUM(byteSize), 0) FROM article"
            ) ?? 0
            let activeSentences = try Int.fetchOne(db, sql: """
                SELECT COUNT(DISTINCT s.id)
                  FROM sentence s
                  JOIN articleSentence aps ON aps.sentenceId = s.id
                  JOIN article a ON a.id = aps.articleId
                 WHERE a.isArchived = 0
                """) ?? 0
            let seenSentences = try Int.fetchOne(db, sql: """
                SELECT COUNT(DISTINCT s.id)
                  FROM sentence s
                  JOIN articleSentence aps ON aps.sentenceId = s.id
                  JOIN article a ON a.id = aps.articleId
                  JOIN sentenceExposure e ON e.sentenceId = s.id
                 WHERE a.isArchived = 0
                """) ?? 0

            return LibrarySummary(
                articleCount: articleCount,
                activeSentenceCount: activeSentences,
                seenSentenceCount: seenSentences,
                totalBytes: totalBytes,
                targetBytes: LibraryLimits.targetBytes,
                hardCapBytes: LibraryLimits.hardCapBytes
            )
        }
    }

    func articles(includeArchived: Bool = false) async throws -> [LibraryArticle] {
        try await database.dbQueue.read { db in
            let filter = includeArchived ? "" : "WHERE a.isArchived = 0"
            let rows = try Row.fetchAll(db, sql: """
                SELECT a.id, a.title, a.source, a.sourceURL, a.license, a.attribution,
                       a.kind, a.byteSize, a.importedAt, a.isArchived,
                       COUNT(aps.sentenceId) AS sentenceCount,
                       CAST(ROUND(AVG(s.difficulty)) AS INTEGER) AS averageDifficulty,
                       MIN(s.difficulty) AS minDifficulty,
                       MAX(s.difficulty) AS maxDifficulty
                  FROM article a
                  LEFT JOIN articleSentence aps ON aps.articleId = a.id
                  LEFT JOIN sentence s ON s.id = aps.sentenceId
                  \(filter)
                 GROUP BY a.id
                 ORDER BY a.importedAt DESC, a.id DESC
                """)

            return rows.map { row in
                let kindString: String = row["kind"]
                let urlString: String? = row["sourceURL"]
                return LibraryArticle(
                    id: row["id"],
                    title: row["title"],
                    source: row["source"],
                    sourceURL: urlString.flatMap(URL.init(string:)),
                    license: row["license"],
                    attribution: row["attribution"],
                    kind: ArticleKind(rawValue: kindString) ?? .prose,
                    byteSize: row["byteSize"],
                    sentenceCount: row["sentenceCount"],
                    averageDifficulty: row["averageDifficulty"],
                    minDifficulty: row["minDifficulty"],
                    maxDifficulty: row["maxDifficulty"],
                    importedAt: row["importedAt"],
                    isArchived: row["isArchived"]
                )
            }
        }
    }

    func articleSentences(articleID: Int64, limit: Int = 40) async throws -> [String] {
        try await database.dbQueue.read { db in
            try String.fetchAll(db, sql: """
                SELECT s.text
                  FROM articleSentence aps
                  JOIN sentence s ON s.id = aps.sentenceId
                 WHERE aps.articleId = ?
                 ORDER BY aps.orderIndex
                 LIMIT ?
                """, arguments: [articleID, limit])
        }
    }

    func setArchived(_ archived: Bool, articleID: Int64) async throws {
        try await database.dbQueue.write { db in
            try db.execute(
                sql: "UPDATE article SET isArchived = ? WHERE id = ?",
                arguments: [archived, articleID]
            )
        }
    }

    func deleteArticle(id: Int64) async throws {
        try await database.dbQueue.write { db in
            try db.execute(sql: "DELETE FROM article WHERE id = ?", arguments: [id])
            try db.execute(sql: """
                DELETE FROM sentence
                 WHERE NOT EXISTS (
                    SELECT 1 FROM articleSentence aps WHERE aps.sentenceId = sentence.id
                 )
                """)
        }
    }

    func recordExposure(sentenceIDs: [Int64], surface: String) async throws {
        let uniqueIDs = Array(Set(sentenceIDs))
        guard !uniqueIDs.isEmpty else { return }

        try await database.dbQueue.write { db in
            let statement = try db.makeStatement(sql: """
                INSERT INTO sentenceExposure (sentenceId, lastSeenAt, count, lastSurface)
                VALUES (?, ?, 1, ?)
                ON CONFLICT(sentenceId) DO UPDATE SET
                    lastSeenAt = excluded.lastSeenAt,
                    count = sentenceExposure.count + 1,
                    lastSurface = excluded.lastSurface
                """)
            let now = Date()
            for id in uniqueIDs {
                try statement.execute(arguments: [id, now, surface])
            }
        }
    }

    func randomSentences(
        limit: Int,
        difficulty: ClosedRange<Int>? = nil
    ) async throws -> [PracticeSentence] {
        try await database.dbQueue.read { db in
            var sql = """
                SELECT s.id, s.text, s.difficulty
                  FROM sentence s
                  JOIN articleSentence aps ON aps.sentenceId = s.id
                  JOIN article a ON a.id = aps.articleId
                 WHERE a.isArchived = 0
                """
            var arguments: StatementArguments = []
            if let difficulty {
                sql += " AND s.difficulty BETWEEN ? AND ?"
                arguments += [difficulty.lowerBound, difficulty.upperBound]
            }
            sql += " GROUP BY s.id ORDER BY RANDOM() LIMIT ?"
            arguments += [limit]

            let rows = try Row.fetchAll(db, sql: sql, arguments: arguments)
            return rows.map { row in
                PracticeSentence(
                    id: row["id"],
                    text: row["text"],
                    difficulty: row["difficulty"]
                )
            }
        }
    }
}
