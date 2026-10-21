import Foundation
import GRDB

struct CorpusImporter: Sendable {
    let database: AppDatabase

    func importDocument(_ document: ImportedDocument) async throws -> ImportResult {
        try await database.dbQueue.write { db in
            try Self.importDocument(document, in: db)
        }
    }

    static func importDocument(_ document: ImportedDocument, in db: Database) throws -> ImportResult {
        let title = document.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = TextNormalizer.normalize(document.text)
        guard !text.isEmpty else { throw ImportError.emptyDocument }
        guard TextNormalizer.hangulRatio(text) >= 0.10 else {
            throw ImportError.noKoreanText
        }

        let byteSize = text.utf8.count
        let contentHash = TextNormalizer.sha256(text)

        if let existingID = try Int64.fetchOne(
            db,
            sql: "SELECT id FROM article WHERE contentHash = ?",
            arguments: [contentHash]
        ) {
            return ImportResult(
                articleID: existingID,
                title: title,
                sentenceCount: 0,
                newSentenceCount: 0,
                byteSize: byteSize,
                wasDuplicate: true
            )
        }

        let currentBytes = try Int.fetchOne(
            db,
            sql: "SELECT COALESCE(SUM(byteSize), 0) FROM article"
        ) ?? 0
        guard currentBytes + byteSize <= LibraryLimits.hardCapBytes else {
            throw ImportError.libraryFull
        }

        let rawSentences = SentenceSegmenter.sentences(from: text)
        guard !rawSentences.isEmpty else { throw ImportError.emptyDocument }

        var seen = Set<String>()
        var ordered: [(text: String, normalized: String, hash: String, chars: Int, eojeol: Int, difficulty: Int)] = []
        for raw in rawSentences {
            let sentence = TextNormalizer.normalize(raw)
            guard TextNormalizer.nonWhitespaceCount(sentence) >= 2 else { continue }
            let hash = TextNormalizer.sha256(TextNormalizer.normalizedForHash(sentence))
            guard seen.insert(hash).inserted else { continue }
            ordered.append((
                sentence,
                TextNormalizer.normalizedForHash(sentence),
                hash,
                TextNormalizer.nonWhitespaceCount(sentence),
                TextNormalizer.eojeolCount(sentence),
                DifficultyEstimator.estimate(sentence)
            ))
        }
        guard !ordered.isEmpty else { throw ImportError.emptyDocument }

        try db.execute(
            sql: """
                INSERT INTO article
                    (title, source, sourceURL, license, attribution, kind, contentHash, byteSize, importedAt, isArchived)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0)
                """,
            arguments: [
                title,
                document.source,
                document.sourceURL?.absoluteString,
                document.license,
                document.attribution,
                document.kind.rawValue,
                contentHash,
                byteSize,
                Date()
            ]
        )
        let articleID = db.lastInsertedRowID

        let selectSentence = try db.makeStatement(
            sql: "SELECT id FROM sentence WHERE textHash = ?"
        )
        let insertSentence = try db.makeStatement(
            sql: """
                INSERT INTO sentence
                    (text, normalizedText, textHash, charCount, eojeolCount, difficulty, register, createdAt)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """
        )
        let insertLink = try db.makeStatement(
            sql: """
                INSERT OR IGNORE INTO articleSentence (articleId, sentenceId, orderIndex)
                VALUES (?, ?, ?)
                """
        )

        var newSentenceCount = 0
        var sentenceCount = 0
        for (index, item) in ordered.enumerated() {
            let sentenceID: Int64
            if let existing = try Int64.fetchOne(selectSentence, arguments: [item.hash]) {
                sentenceID = existing
            } else {
                try insertSentence.execute(arguments: [
                    item.text,
                    item.normalized,
                    item.hash,
                    item.chars,
                    item.eojeol,
                    item.difficulty,
                    register(for: item.text),
                    Date()
                ])
                sentenceID = db.lastInsertedRowID
                newSentenceCount += 1
            }
            try insertLink.execute(arguments: [articleID, sentenceID, index])
            sentenceCount += 1
        }

        return ImportResult(
            articleID: articleID,
            title: title,
            sentenceCount: sentenceCount,
            newSentenceCount: newSentenceCount,
            byteSize: byteSize,
            wasDuplicate: false
        )
    }

    private static func register(for sentence: String) -> String {
        if sentence.contains("습니다") || sentence.contains("입니다") || sentence.contains("하십시오") {
            return "formal"
        }
        if sentence.hasSuffix("요.") || sentence.hasSuffix("요?") || sentence.hasSuffix("요!") {
            return "polite"
        }
        if sentence.hasSuffix("다.") || sentence.hasSuffix("다?") || sentence.hasSuffix("다!") {
            return "plain"
        }
        return "neutral"
    }
}
