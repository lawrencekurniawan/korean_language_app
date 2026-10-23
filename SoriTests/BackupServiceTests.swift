import Foundation
import XCTest
import ZIPFoundation
@testable import Sori

final class BackupServiceTests: XCTestCase {
    @MainActor
    func testCreateBackupWritesExpectedEntriesAndMetadata() async throws {
        let context = try makeContext()
        defer { context.cleanup() }

        context.settings.readingDuration = 120
        context.settings.appearance = .dark
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        let url = try await context.service.createBackup(at: now)

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(context.settings.lastBackupAt, now)
        XCTAssertEqual(context.service.dailyBackups.count, 1)
        XCTAssertEqual(context.service.weeklyBackups.count, 1)
        XCTAssertEqual(context.service.localBackups.count, 2)

        let archive = try Archive(url: url, accessMode: .read)
        XCTAssertEqual(
            Set(archive.map(\.path)),
            Set(["manifest.json", "sori.sqlite", "settings.json", "README.txt"])
        )

        let manifest: BackupManifest = try decode(
            BackupManifest.self,
            path: "manifest.json",
            archive: archive
        )
        XCTAssertEqual(manifest.format, BackupManifest.currentFormat)
        XCTAssertEqual(manifest.formatVersion, BackupManifest.currentVersion)
        XCTAssertEqual(manifest.createdAt, now)
        XCTAssertFalse(manifest.containsCredentials)

        let snapshot: SettingsSnapshot = try decode(
            SettingsSnapshot.self,
            path: "settings.json",
            archive: archive
        )
        XCTAssertEqual(snapshot.readingDuration, 120)
        XCTAssertEqual(snapshot.appearance, AppAppearance.dark.rawValue)

        let settingsData: Data = try data(path: "settings.json", archive: archive)
        let settingsJSON = try XCTUnwrap(String(data: settingsData, encoding: .utf8))
        XCTAssertFalse(settingsJSON.contains("password"))
        XCTAssertFalse(settingsJSON.contains("openSubtitles"))
        XCTAssertFalse(settingsJSON.contains("lastBackupAt"))
    }

    @MainActor
    func testRestoreReplacesDatabaseAndSettings() async throws {
        let context = try makeContext()
        defer { context.cleanup() }

        let practice = PracticeRepository(database: context.database)
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let sessionID = try await practice.saveReadingSession(
            ReadingSessionInput(
                startedAt: base,
                endedAt: base.addingTimeInterval(60),
                durationSeconds: 60,
                plannedSeconds: 60,
                completedCharacters: 120,
                completedSentences: 3,
                cpm: 120,
                fontSize: 30
            ),
            exposedSentenceIDs: []
        )
        context.settings.readingDuration = 120
        let backupURL = try await context.service.createBackup(at: base)

        try await practice.deleteSession(id: sessionID)
        context.settings.readingDuration = 45
        let emptySessions = try await practice.recentSessions(limit: 10)
        XCTAssertTrue(emptySessions.isEmpty)

        let manifest = try await context.service.restore(from: backupURL)

        XCTAssertEqual(manifest.createdAt, base)
        XCTAssertEqual(context.settings.readingDuration, 120)
        let sessions = try await practice.recentSessions(limit: 10)
        XCTAssertEqual(sessions.count, 1)
        let session = try XCTUnwrap(sessions.first)
        XCTAssertEqual(session.cpmNet, 120, accuracy: 0.001)
    }

    @MainActor
    func testRetentionKeepsSevenDailyAndFourWeeklyBackups() async throws {
        let context = try makeContext()
        defer { context.cleanup() }

        var calendar = Calendar.current
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = try XCTUnwrap(
            calendar.date(from: DateComponents(
                year: 2026,
                month: 1,
                day: 1,
                hour: 12
            ))
        )

        for offset in 0..<35 {
            let date = try XCTUnwrap(
                calendar.date(byAdding: .day, value: offset, to: start)
            )
            _ = try await context.service.createBackup(at: date)
        }

        XCTAssertEqual(context.service.dailyBackups.count, 7)
        XCTAssertEqual(context.service.weeklyBackups.count, 4)
        XCTAssertEqual(context.service.localBackups.count, 11)
    }

    @MainActor
    func testAutomaticBackupRunsOncePerDay() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SoriBackupTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let suite = "SoriBackupTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let database = try AppDatabase.onDisk(
            at: root.appendingPathComponent("sori.sqlite")
        )
        let settings = SettingsStore(defaults: defaults)
        let service = BackupService(
            database: database,
            settings: settings,
            rootDirectory: root.appendingPathComponent("Backups", isDirectory: true)
        )

        var calendar = Calendar.current
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let dayOne = try XCTUnwrap(
            calendar.date(from: DateComponents(
                year: 2026,
                month: 5,
                day: 1,
                hour: 12
            ))
        )

        await service.automaticBackupIfNeeded(at: dayOne)
        XCTAssertEqual(service.dailyBackups.count, 1)

        await service.automaticBackupIfNeeded(
            at: dayOne.addingTimeInterval(3_600)
        )
        XCTAssertEqual(service.dailyBackups.count, 1)

        let dayTwo = try XCTUnwrap(
            calendar.date(byAdding: .day, value: 1, to: dayOne)
        )
        await service.automaticBackupIfNeeded(at: dayTwo)
        XCTAssertEqual(service.dailyBackups.count, 2)
    }

    @MainActor
    func testRestoreIntoOnDiskDatabase() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SoriBackupTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let suite = "SoriBackupTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let database = try AppDatabase.onDisk(
            at: root.appendingPathComponent("sori.sqlite")
        )
        let settings = SettingsStore(defaults: defaults)
        let service = BackupService(
            database: database,
            settings: settings,
            rootDirectory: root.appendingPathComponent("Backups", isDirectory: true)
        )
        let practice = PracticeRepository(database: database)
        let base = Date(timeIntervalSince1970: 1_800_000_000)

        let sessionID = try await practice.saveReadingSession(
            ReadingSessionInput(
                startedAt: base,
                endedAt: base.addingTimeInterval(60),
                durationSeconds: 60,
                plannedSeconds: 60,
                completedCharacters: 90,
                completedSentences: 2,
                cpm: 90,
                fontSize: 30
            ),
            exposedSentenceIDs: []
        )
        settings.readingDuration = 120
        let backupURL = try await service.createBackup(at: base)
        try await practice.deleteSession(id: sessionID)
        settings.readingDuration = 45

        _ = try await service.restore(from: backupURL)

        let sessions = try await practice.recentSessions(limit: 10)
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(settings.readingDuration, 120)
    }

    @MainActor
    func testRestoredSettingsAreClampedToSupportedRanges() throws {
        let suite = "SoriBackupTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = SettingsStore(defaults: defaults)

        settings.apply(
            SettingsSnapshot(
                appearance: "not-a-theme",
                readingDuration: 1,
                typingDuration: 999,
                readingFontSize: 1,
                typingFontSize: 99,
                speakFontSize: 30,
                appLanguage: "not-a-language",
                explanationLanguage: "not-a-language",
                splashEnabled: false,
                splashAutoCloseSeconds: 99,
                keyboardMode: "not-a-keyboard",
                speakAutoMode: false,
                voiceIdentifier: "voice",
                speechRate: 2,
                repeatCount: -1
            )
        )

        XCTAssertEqual(settings.appearance, .system)
        XCTAssertEqual(settings.readingDuration, 15)
        XCTAssertEqual(settings.typingDuration, 300)
        XCTAssertEqual(settings.readingFontSize, 18)
        XCTAssertEqual(settings.typingFontSize, 44)
        XCTAssertEqual(settings.appLanguage, .english)
        XCTAssertEqual(settings.explanationLanguage, .english)
        XCTAssertFalse(settings.splashEnabled)
        XCTAssertEqual(settings.splashAutoCloseSeconds, 15)
        XCTAssertEqual(settings.keyboardMode, .builtIn)
        XCTAssertFalse(settings.speakAutoMode)
        XCTAssertEqual(settings.voiceIdentifier, "voice")
        XCTAssertEqual(settings.speechRate, 0.8)
        XCTAssertEqual(settings.repeatCount, 0)
    }

    @MainActor
    private func makeContext() throws -> TestContext {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SoriBackupTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let suite = "SoriBackupTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let database = try AppDatabase.inMemory()
        let settings = SettingsStore(defaults: defaults)
        let service = BackupService(
            database: database,
            settings: settings,
            rootDirectory: root
        )

        return TestContext(
            root: root,
            suite: suite,
            defaults: defaults,
            database: database,
            settings: settings,
            service: service
        )
    }

    private func data(path: String, archive: Archive) throws -> Data {
        guard let entry = archive.first(where: { $0.path == path }) else {
            throw BackupError.missingEntry(path)
        }
        var data = Data()
        _ = try archive.extract(entry) { chunk in
            data.append(chunk)
        }
        return data
    }

    private func decode<T: Decodable>(
        _ type: T.Type,
        path: String,
        archive: Archive
    ) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data(path: path, archive: archive))
    }
}

@MainActor
private struct TestContext {
    let root: URL
    let suite: String
    let defaults: UserDefaults
    let database: AppDatabase
    let settings: SettingsStore
    let service: BackupService

    func cleanup() {
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: root)
    }
}
