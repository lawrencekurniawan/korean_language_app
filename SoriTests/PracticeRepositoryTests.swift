import GRDB
import XCTest
@testable import Sori

final class PracticeRepositoryTests: XCTestCase {
    private var database: AppDatabase!
    private var library: LibraryRepository!
    private var importer: CorpusImporter!
    private var practice: PracticeRepository!

    override func setUpWithError() throws {
        database = try AppDatabase.inMemory()
        library = LibraryRepository(database: database)
        importer = CorpusImporter(database: database)
        practice = PracticeRepository(database: database)
    }

    override func tearDownWithError() throws {
        database = nil
        library = nil
        importer = nil
        practice = nil
    }

    func testSaveReadingSessionWritesSessionAndExposures() async throws {
        _ = try await importer.importDocument(
            ImportedDocument(
                title: "Practice text",
                text: "안녕하세요. 오늘은 날씨가 좋습니다. 저는 한국어를 공부해요.",
                source: "Unit test",
                sourceURL: nil,
                license: nil,
                attribution: nil,
                kind: .prose
            )
        )

        let sentences = try await library.randomSentences(limit: 10)
        let startedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let endedAt = startedAt.addingTimeInterval(60)

        let sessionID = try await practice.saveReadingSession(
            ReadingSessionInput(
                startedAt: startedAt,
                endedAt: endedAt,
                durationSeconds: 60,
                plannedSeconds: 60,
                completedCharacters: 15,
                completedSentences: 2,
                cpm: 15,
                fontSize: 30
            ),
            exposedSentenceIDs: Array(sentences.prefix(2)).map(\.id)
        )

        XCTAssertGreaterThan(sessionID, 0)

        let sessions = try await practice.recentSessions(limit: 5)
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions[0].skill, "reading")
        XCTAssertEqual(sessions[0].startedAt, startedAt)
        XCTAssertEqual(sessions[0].endedAt, endedAt)
        XCTAssertEqual(sessions[0].durationSeconds, 60, accuracy: 0.001)
        XCTAssertEqual(sessions[0].plannedSeconds, 60)
        XCTAssertEqual(sessions[0].characters, 15)
        XCTAssertEqual(sessions[0].sentences, 2)
        XCTAssertEqual(sessions[0].cpmNet, 15, accuracy: 0.001)
        XCTAssertEqual(sessions[0].fontSize, 30)

        let exposureCount = try await database.dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM sentenceExposure") ?? 0
        }
        XCTAssertEqual(exposureCount, 2)
    }

    func testSaveTypingSessionWritesTypingFieldsAndExposures() async throws {
        _ = try await importer.importDocument(
            ImportedDocument(
                title: "Typing text",
                text: "안녕하세요. 오늘은 날씨가 좋습니다. 저는 한국어를 공부해요.",
                source: "Unit test",
                sourceURL: nil,
                license: nil,
                attribution: nil,
                kind: .prose
            )
        )

        let sentences = try await library.randomSentences(limit: 10)
        let startedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let endedAt = startedAt.addingTimeInterval(60)

        let sessionID = try await practice.saveTypingSession(
            TypingSessionInput(
                startedAt: startedAt,
                endedAt: endedAt,
                durationSeconds: 60,
                plannedSeconds: 60,
                typedCharacters: 12,
                correctCharacters: 10,
                errorCharacters: 2,
                completedSentences: 1,
                cpmNet: 10,
                cpmGross: 12,
                accuracy: 10.0 / 12.0,
                fontSize: 24,
                keyboardMode: "builtIn"
            ),
            exposedSentenceIDs: Array(sentences.prefix(2)).map(\.id)
        )

        XCTAssertGreaterThan(sessionID, 0)

        let sessions = try await practice.recentSessions(limit: 5)
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions[0].skill, "typing")
        XCTAssertEqual(sessions[0].startedAt, startedAt)
        XCTAssertEqual(sessions[0].endedAt, endedAt)
        XCTAssertEqual(sessions[0].durationSeconds, 60, accuracy: 0.001)
        XCTAssertEqual(sessions[0].plannedSeconds, 60)
        XCTAssertEqual(sessions[0].characters, 12)
        XCTAssertEqual(sessions[0].sentences, 1)
        XCTAssertEqual(sessions[0].cpmNet, 10, accuracy: 0.001)
        XCTAssertEqual(sessions[0].cpmGross, 12, accuracy: 0.001)
        XCTAssertEqual(sessions[0].accuracy, 10.0 / 12.0, accuracy: 0.001)
        XCTAssertEqual(sessions[0].fontSize, 24)

        let storedMode = try await database.dbQueue.read { db in
            try String.fetchOne(
                db,
                sql: "SELECT keyboardMode FROM practiceSession WHERE id = ?",
                arguments: [sessionID]
            )
        }
        XCTAssertEqual(storedMode, "builtIn")

        let exposureCount = try await database.dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM sentenceExposure") ?? 0
        }
        XCTAssertEqual(exposureCount, 2)
    }

    func testRecentSessionsAreNewestFirstAndLimited() async throws {
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        for index in 0..<3 {
            let startedAt = base.addingTimeInterval(Double(index * 60))
            _ = try await practice.saveReadingSession(
                ReadingSessionInput(
                    startedAt: startedAt,
                    endedAt: startedAt.addingTimeInterval(60),
                    durationSeconds: 60,
                    plannedSeconds: 60,
                    completedCharacters: index + 1,
                    completedSentences: index + 1,
                    cpm: Double(index + 1),
                    fontSize: 30
                ),
                exposedSentenceIDs: []
            )
        }

        let sessions = try await practice.recentSessions(limit: 2)
        XCTAssertEqual(sessions.count, 2)
        XCTAssertEqual(sessions[0].startedAt, base.addingTimeInterval(120))
        XCTAssertEqual(sessions[1].startedAt, base.addingTimeInterval(60))
    }

    func testCPMSamplesAreOrderedAndCanBeFilteredByDate() async throws {
        let base = Date(timeIntervalSince1970: 1_800_000_000)

        _ = try await practice.saveReadingSession(
            ReadingSessionInput(
                startedAt: base,
                endedAt: base.addingTimeInterval(60),
                durationSeconds: 60,
                plannedSeconds: 60,
                completedCharacters: 10,
                completedSentences: 1,
                cpm: 10,
                fontSize: 30
            ),
            exposedSentenceIDs: []
        )
        _ = try await practice.saveTypingSession(
            TypingSessionInput(
                startedAt: base.addingTimeInterval(60),
                endedAt: base.addingTimeInterval(120),
                durationSeconds: 60,
                plannedSeconds: 60,
                typedCharacters: 15,
                correctCharacters: 15,
                errorCharacters: 0,
                completedSentences: 1,
                cpmNet: 15,
                cpmGross: 15,
                accuracy: 1,
                fontSize: 24,
                keyboardMode: "builtIn"
            ),
            exposedSentenceIDs: []
        )
        _ = try await practice.saveReadingSession(
            ReadingSessionInput(
                startedAt: base.addingTimeInterval(120),
                endedAt: base.addingTimeInterval(180),
                durationSeconds: 60,
                plannedSeconds: 60,
                completedCharacters: 20,
                completedSentences: 1,
                cpm: 20,
                fontSize: 30
            ),
            exposedSentenceIDs: []
        )

        let all = try await practice.cpmSamples()
        XCTAssertEqual(all.count, 3)
        XCTAssertEqual(all.map(\.cpm), [10, 15, 20])
        XCTAssertEqual(all[0].skill, .reading)
        XCTAssertEqual(all[1].skill, .typing)
        XCTAssertEqual(all[2].skill, .reading)

        let recent = try await practice.cpmSamples(
            since: base.addingTimeInterval(30)
        )
        XCTAssertEqual(recent.count, 2)
        XCTAssertEqual(recent.map(\.cpm), [15, 20])
    }

    func testDeleteSessionRemovesOnlyTheSelectedSession() async throws {
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let readingID = try await practice.saveReadingSession(
            ReadingSessionInput(
                startedAt: base,
                endedAt: base.addingTimeInterval(60),
                durationSeconds: 60,
                plannedSeconds: 60,
                completedCharacters: 10,
                completedSentences: 1,
                cpm: 10,
                fontSize: 30
            ),
            exposedSentenceIDs: []
        )
        let typingID = try await practice.saveTypingSession(
            TypingSessionInput(
                startedAt: base.addingTimeInterval(60),
                endedAt: base.addingTimeInterval(120),
                durationSeconds: 60,
                plannedSeconds: 60,
                typedCharacters: 12,
                correctCharacters: 12,
                errorCharacters: 0,
                completedSentences: 1,
                cpmNet: 12,
                cpmGross: 12,
                accuracy: 1,
                fontSize: 24,
                keyboardMode: "builtIn"
            ),
            exposedSentenceIDs: []
        )

        try await practice.deleteSession(id: readingID)

        let sessions = try await practice.recentSessions(limit: 10)
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions[0].id, typingID)
    }
}
