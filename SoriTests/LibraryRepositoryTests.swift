import GRDB
import XCTest
@testable import Sori

final class LibraryRepositoryTests: XCTestCase {
    private var database: AppDatabase!
    private var library: LibraryRepository!
    private var importer: CorpusImporter!

    override func setUpWithError() throws {
        database = try AppDatabase.inMemory()
        library = LibraryRepository(database: database)
        importer = CorpusImporter(database: database)
    }

    override func tearDownWithError() throws {
        database = nil
        library = nil
        importer = nil
    }

    func testImportStoresArticleAndSentences() async throws {
        let text = "안녕하세요. 오늘은 날씨가 좋습니다. 저는 한국어를 공부해요."
        let result = try await importText(text)

        XCTAssertFalse(result.wasDuplicate)
        XCTAssertEqual(result.sentenceCount, 3)
        XCTAssertEqual(result.newSentenceCount, 3)
        XCTAssertEqual(result.byteSize, TextNormalizer.normalize(text).utf8.count)

        let summary = try await library.summary()
        XCTAssertEqual(summary.articleCount, 1)
        XCTAssertEqual(summary.activeSentenceCount, 3)
        XCTAssertEqual(summary.seenSentenceCount, 0)
        XCTAssertEqual(summary.totalBytes, result.byteSize)
        XCTAssertFalse(summary.needsMoreContent)

        let articles = try await library.articles()
        XCTAssertEqual(articles.count, 1)
        XCTAssertEqual(articles[0].title, "Test article")
        XCTAssertEqual(articles[0].sentenceCount, 3)
        XCTAssertEqual(articles[0].source, "Unit test")
    }

    func testDuplicateContentIsNotImportedTwice() async throws {
        let text = "안녕하세요. 오늘은 날씨가 좋습니다. 저는 한국어를 공부해요."
        _ = try await importText(text)
        let duplicate = try await importText(text, title: "Different title")

        XCTAssertTrue(duplicate.wasDuplicate)
        let summary = try await library.summary()
        XCTAssertEqual(summary.articleCount, 1)
        XCTAssertEqual(summary.activeSentenceCount, 3)
    }

    func testRepeatedSentenceAcrossArticlesIsShared() async throws {
        _ = try await importText("안녕하세요. 오늘은 날씨가 좋습니다.", title: "First")
        _ = try await importText("오늘은 날씨가 좋습니다. 내일은 비가 옵니다.", title: "Second")

        let summary = try await library.summary()
        XCTAssertEqual(summary.articleCount, 2)
        XCTAssertEqual(summary.activeSentenceCount, 3)

        let sentenceCount = try await database.dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM sentence") ?? 0
        }
        XCTAssertEqual(sentenceCount, 3)
    }

    func testExposureUpdatesCoverageAndTriggersNinetyFivePercentRule() async throws {
        _ = try await importText("안녕하세요. 오늘은 날씨가 좋습니다. 저는 한국어를 공부해요.")
        let sentences = try await library.randomSentences(limit: 10)
        XCTAssertEqual(sentences.count, 3)
        let filtered = try await library.randomSentences(limit: 10, difficulty: 1...6)
        XCTAssertEqual(filtered.count, 3)
        let impossible = try await library.randomSentences(limit: 10, difficulty: 99...99)
        XCTAssertTrue(impossible.isEmpty)

        try await library.recordExposure(
            sentenceIDs: Array(sentences.prefix(2)).map(\.id),
            surface: "reading"
        )
        var summary = try await library.summary()
        XCTAssertEqual(summary.seenSentenceCount, 2)
        XCTAssertEqual(summary.coverage, 2.0 / 3.0, accuracy: 0.001)
        XCTAssertFalse(summary.needsMoreContent)

        try await library.recordExposure(
            sentenceIDs: sentences.map(\.id),
            surface: "reading"
        )
        summary = try await library.summary()
        XCTAssertEqual(summary.seenSentenceCount, 3)
        XCTAssertEqual(summary.coverage, 1.0, accuracy: 0.001)
        XCTAssertTrue(summary.needsMoreContent)

        // Exposures are counted per sentence, not per call.
        try await library.recordExposure(sentenceIDs: [sentences[0].id], surface: "typing")
        summary = try await library.summary()
        XCTAssertEqual(summary.seenSentenceCount, 3)
    }

    func testArchiveHidesArticleFromActiveCoverage() async throws {
        let result = try await importText("안녕하세요. 오늘은 날씨가 좋습니다.")
        try await library.setArchived(true, articleID: result.articleID)

        var summary = try await library.summary()
        XCTAssertEqual(summary.articleCount, 0)
        XCTAssertEqual(summary.activeSentenceCount, 0)
        XCTAssertEqual(summary.totalBytes, result.byteSize)
        let active = try await library.articles()
        XCTAssertTrue(active.isEmpty)

        let all = try await library.articles(includeArchived: true)
        XCTAssertEqual(all.count, 1)
        XCTAssertTrue(all[0].isArchived)

        try await library.setArchived(false, articleID: result.articleID)
        summary = try await library.summary()
        XCTAssertEqual(summary.articleCount, 1)
        XCTAssertEqual(summary.activeSentenceCount, 2)
    }

    func testDeleteRemovesOrphanSentencesAndExposures() async throws {
        let result = try await importText("안녕하세요. 오늘은 날씨가 좋습니다.")
        let sentences = try await library.randomSentences(limit: 10)
        try await library.recordExposure(sentenceIDs: sentences.map(\.id), surface: "reading")

        try await library.deleteArticle(id: result.articleID)

        let summary = try await library.summary()
        XCTAssertEqual(summary.articleCount, 0)
        XCTAssertEqual(summary.activeSentenceCount, 0)
        XCTAssertEqual(summary.totalBytes, 0)

        let counts = try await database.dbQueue.read { db in
            (
                try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM sentence") ?? 0,
                try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM articleSentence") ?? 0,
                try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM sentenceExposure") ?? 0
            )
        }
        XCTAssertEqual(counts.0, 0)
        XCTAssertEqual(counts.1, 0)
        XCTAssertEqual(counts.2, 0)
    }

    func testHardCapRejectsImport() async throws {
        try await database.dbQueue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO article
                        (title, source, sourceURL, license, attribution, kind, contentHash, byteSize, importedAt, isArchived)
                    VALUES (?, ?, NULL, NULL, NULL, 'prose', ?, ?, ?, 0)
                    """,
                arguments: ["Big article", "Test", "big-hash", 9_999_999, Date()]
            )
        }

        do {
            _ = try await importText("안녕하세요. 이것은 새로운 문장입니다.")
            XCTFail("Expected the hard cap to reject the import")
        } catch let error as ImportError {
            XCTAssertEqual(error, .libraryFull)
        }
    }

    func testNonKoreanContentIsRejected() async throws {
        do {
            _ = try await importText("Hello there. This is English text.")
            XCTFail("Expected non-Korean content to be rejected")
        } catch let error as ImportError {
            XCTAssertEqual(error, .noKoreanText)
        }
    }

    func testSeedLoaderIsVersionedAndIdempotent() async throws {
        let seed = SeedLibrary(
            version: "test-seed-1",
            generatedAt: "2026-10-21",
            description: "Test seed",
            articles: [
                SeedArticle(
                    id: "one",
                    title: "Seed one",
                    source: "Test",
                    sourceURL: nil,
                    license: "Public domain",
                    attribution: nil,
                    kind: "prose",
                    text: "안녕하세요. 오늘은 날씨가 좋습니다."
                ),
                SeedArticle(
                    id: "two",
                    title: "Seed two",
                    source: "Test",
                    sourceURL: nil,
                    license: "Public domain",
                    attribution: nil,
                    kind: "prose",
                    text: "저는 한국어를 공부해요. 매일 조금씩 배웁니다."
                )
            ]
        )
        let data = try JSONEncoder().encode(seed)
        let loader = SeedLibraryLoader(database: database, importer: importer)

        let first = try await loader.seedIfNeeded(seedData: data)
        XCTAssertFalse(first.alreadySeeded)
        XCTAssertEqual(first.importedArticles, 2)
        XCTAssertEqual(first.importedSentences, 4)
        let storedVersion = try await database.metaValue(forKey: SeedLibraryLoader.metaKey)
        XCTAssertEqual(storedVersion, "test-seed-1")

        let second = try await loader.seedIfNeeded(seedData: data)
        XCTAssertTrue(second.alreadySeeded)
        let summary = try await library.summary()
        XCTAssertEqual(summary.articleCount, 2)
    }

    func testSeedLoaderSkipsInvalidArticles() async throws {
        let seed = SeedLibrary(
            version: "test-seed-2",
            generatedAt: nil,
            description: nil,
            articles: [
                SeedArticle(
                    id: "valid",
                    title: "Valid",
                    source: "Test",
                    sourceURL: nil,
                    license: nil,
                    attribution: nil,
                    kind: nil,
                    text: "안녕하세요. 반갑습니다."
                ),
                SeedArticle(
                    id: "invalid",
                    title: "Invalid",
                    source: "Test",
                    sourceURL: nil,
                    license: nil,
                    attribution: nil,
                    kind: nil,
                    text: "This is not Korean."
                )
            ]
        )
        let data = try JSONEncoder().encode(seed)
        let result = try await SeedLibraryLoader(
            database: database,
            importer: importer
        ).seedIfNeeded(seedData: data)

        XCTAssertEqual(result.importedArticles, 1)
        XCTAssertEqual(result.skippedArticles, 1)
    }

    private func importText(
        _ text: String,
        title: String = "Test article"
    ) async throws -> ImportResult {
        try await importer.importDocument(
            ImportedDocument(
                title: title,
                text: text,
                source: "Unit test",
                sourceURL: nil,
                license: nil,
                attribution: nil,
                kind: .prose
            )
        )
    }
}
