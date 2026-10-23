import Foundation
import GRDB
import Observation
import ZIPFoundation

@MainActor
@Observable
final class BackupService {
    @ObservationIgnored private let database: AppDatabase
    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private let fileManager: FileManager
    @ObservationIgnored private let rootDirectory: URL

    private(set) var localBackups: [BackupRecord] = []
    private(set) var isWorking = false
    private(set) var errorMessage: String?

    init(
        database: AppDatabase,
        settings: SettingsStore,
        rootDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.database = database
        self.settings = settings
        self.fileManager = fileManager

        let base = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first?.appendingPathComponent("Sori", isDirectory: true)
            ?? fileManager.temporaryDirectory.appendingPathComponent("Sori", isDirectory: true)
        self.rootDirectory = rootDirectory
            ?? base.appendingPathComponent("Backups", isDirectory: true)

        _ = try? ensureDirectories()
        refreshLocalBackups()
    }

    var latestBackup: BackupRecord? {
        dailyBackups.first ?? weeklyBackups.first
    }

    var dailyBackups: [BackupRecord] {
        localBackups.filter { $0.frequency == .daily }
    }

    var weeklyBackups: [BackupRecord] {
        localBackups.filter { $0.frequency == .weekly }
    }

    // MARK: - Creating

    @discardableResult
    func createBackup(at now: Date = Date()) async throws -> URL {
        guard !isWorking else { throw BackupError.busy }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        let directories = try ensureDirectories()
        let tempDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("sori-backup-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )
        defer { try? fileManager.removeItem(at: tempDirectory) }

        do {
            let databaseURL = tempDirectory.appendingPathComponent("sori.sqlite")
            let destination = try DatabaseQueue(path: databaseURL.path)
            try database.dbQueue.backup(to: destination)
            try destination.close()

            let settingsURL = tempDirectory.appendingPathComponent("settings.json")
            try makeEncoder().encode(settings.snapshot()).write(
                to: settingsURL,
                options: .atomic
            )

            let manifest = BackupManifest(
                format: BackupManifest.currentFormat,
                formatVersion: BackupManifest.currentVersion,
                createdAt: now,
                appVersion: Self.appVersion,
                curriculumVersion: try await database.metaValue(
                    forKey: "curriculumVersion"
                ) ?? "unknown",
                schemaVersion: try await database.metaValue(
                    forKey: "schemaVersion"
                ) ?? "0",
                containsCredentials: false
            )
            let manifestURL = tempDirectory.appendingPathComponent("manifest.json")
            try makeEncoder().encode(manifest).write(
                to: manifestURL,
                options: .atomic
            )

            let readmeURL = tempDirectory.appendingPathComponent("README.txt")
            try Self.readme.write(to: readmeURL, atomically: true, encoding: .utf8)

            let archiveURL = tempDirectory.appendingPathComponent("Sori.sori-backup")
            let archive = try Archive(url: archiveURL, accessMode: .create)
            try archive.addEntry(
                with: "manifest.json",
                fileURL: manifestURL,
                compressionMethod: .deflate
            )
            try archive.addEntry(
                with: "sori.sqlite",
                fileURL: databaseURL,
                compressionMethod: .deflate
            )
            try archive.addEntry(
                with: "settings.json",
                fileURL: settingsURL,
                compressionMethod: .deflate
            )
            try archive.addEntry(
                with: "README.txt",
                fileURL: readmeURL,
                compressionMethod: .deflate
            )

            let dailyURL = directories.daily.appendingPathComponent(
                "sori-\(dailyKey(for: now)).sori-backup"
            )
            try replace(archiveURL, with: dailyURL)

            let weeklyURL = directories.weekly.appendingPathComponent(
                "sori-\(weeklyKey(for: now)).sori-backup"
            )
            try copyReplacing(dailyURL, to: weeklyURL)

            try prune(dailyDirectory: directories.daily, keep: 7)
            try prune(dailyDirectory: directories.weekly, keep: 4)

            settings.lastBackupAt = now
            refreshLocalBackups()
            return dailyURL
        } catch {
            errorMessage = "The backup could not be created. \(error.localizedDescription)"
            throw error
        }
    }

    func automaticBackupIfNeeded(at now: Date = Date()) async {
        guard database.fileURL != nil, !isWorking else { return }

        do {
            let directories = try ensureDirectories()
            let dailyURL = directories.daily.appendingPathComponent(
                "sori-\(dailyKey(for: now)).sori-backup"
            )
            let weeklyURL = directories.weekly.appendingPathComponent(
                "sori-\(weeklyKey(for: now)).sori-backup"
            )

            if !fileManager.fileExists(atPath: dailyURL.path) {
                try await createBackup(at: now)
            } else if !fileManager.fileExists(atPath: weeklyURL.path) {
                try copyReplacing(dailyURL, to: weeklyURL)
                try prune(dailyDirectory: directories.weekly, keep: 4)
                refreshLocalBackups()
            }
        } catch {
            errorMessage = "Automatic backup failed. \(error.localizedDescription)"
        }
    }

    // MARK: - Restoring

    @discardableResult
    func restore(from url: URL) async throws -> BackupManifest {
        guard !isWorking else { throw BackupError.busy }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let tempDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("sori-restore-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )
        defer { try? fileManager.removeItem(at: tempDirectory) }

        do {
            let archive = try Archive(url: url, accessMode: .read)
            let manifest = try decode(
                BackupManifest.self,
                from: entry(named: "manifest.json", in: archive),
                in: archive
            )

            guard manifest.format == BackupManifest.currentFormat else {
                throw BackupError.invalidArchive
            }
            guard manifest.formatVersion <= BackupManifest.currentVersion else {
                throw BackupError.unsupportedFormat
            }

            let currentSchema = Int(
                try await database.metaValue(forKey: "schemaVersion") ?? "0"
            ) ?? 0
            let backupSchema = Int(manifest.schemaVersion) ?? 0
            guard backupSchema <= currentSchema else {
                throw BackupError.unsupportedFormat
            }

            let snapshot = try decode(
                SettingsSnapshot.self,
                from: entry(named: "settings.json", in: archive),
                in: archive
            )
            let databaseURL = try extract(
                "sori.sqlite",
                from: archive,
                to: tempDirectory
            )

            let sourceQueue = try DatabaseQueue(path: databaseURL.path)
            defer { try? sourceQueue.close() }
            let tables = try await sourceQueue.read { db in
                try String.fetchAll(
                    db,
                    sql: "SELECT name FROM sqlite_master WHERE type = 'table'"
                )
            }
            guard tables.contains("appMeta"),
                  tables.contains("practiceSession"),
                  tables.contains("sentence") else {
                throw BackupError.invalidDatabase
            }

            let source = try AppDatabase(dbQueue: sourceQueue)
            guard try source.healthCheck() else {
                throw BackupError.invalidDatabase
            }

            try source.dbQueue.backup(to: database.dbQueue)
            settings.apply(snapshot)
            if let lastBackupAt = settings.lastBackupAt {
                settings.lastBackupAt = max(lastBackupAt, manifest.createdAt)
            } else {
                settings.lastBackupAt = manifest.createdAt
            }
            refreshLocalBackups()
            return manifest
        } catch {
            errorMessage = "The backup could not be restored. \(error.localizedDescription)"
            throw error
        }
    }

    // MARK: - Local files

    func delete(_ record: BackupRecord) throws {
        do {
            try fileManager.removeItem(at: record.url)
            refreshLocalBackups()
        } catch {
            errorMessage = "The backup could not be deleted. \(error.localizedDescription)"
            throw error
        }
    }

    func refreshLocalBackups() {
        do {
            let directories = try ensureDirectories()
            localBackups = try records(
                in: directories.daily,
                frequency: .daily
            ) + records(in: directories.weekly, frequency: .weekly)
            localBackups.sort { lhs, rhs in
                if lhs.createdAt != rhs.createdAt {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.fileName > rhs.fileName
            }
        } catch {
            errorMessage = "Local backups could not be read. \(error.localizedDescription)"
        }
    }

    // MARK: - Helpers

    private func ensureDirectories() throws -> (daily: URL, weekly: URL) {
        let daily = rootDirectory.appendingPathComponent("Daily", isDirectory: true)
        let weekly = rootDirectory.appendingPathComponent("Weekly", isDirectory: true)
        for directory in [rootDirectory, daily, weekly] {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        }

        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableRoot = rootDirectory
        try? mutableRoot.setResourceValues(values)
        return (daily, weekly)
    }

    private func records(
        in directory: URL,
        frequency: BackupFrequency
    ) throws -> [BackupRecord] {
        let urls = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [
                .contentModificationDateKey,
                .fileSizeKey
            ],
            options: [.skipsHiddenFiles]
        )

        return urls.compactMap { url in
            guard url.pathExtension == "sori-backup" else { return nil }
            let values = try? url.resourceValues(forKeys: [
                .contentModificationDateKey,
                .fileSizeKey
            ])
            return BackupRecord(
                url: url,
                frequency: frequency,
                createdAt: values?.contentModificationDate ?? .distantPast,
                byteCount: Int64(values?.fileSize ?? 0)
            )
        }
    }

    private func prune(dailyDirectory directory: URL, keep: Int) throws {
        let files = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension == "sori-backup" }
        .sorted { $0.lastPathComponent > $1.lastPathComponent }

        for file in files.dropFirst(keep) {
            try fileManager.removeItem(at: file)
        }
    }

    private func replace(_ source: URL, with destination: URL) throws {
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.moveItem(at: source, to: destination)
    }

    private func copyReplacing(_ source: URL, to destination: URL) throws {
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: source, to: destination)
    }

    private func entry(named name: String, in archive: Archive) throws -> Entry {
        guard let entry = archive.first(where: { $0.path == name }) else {
            throw BackupError.missingEntry(name)
        }
        return entry
    }

    private func extract(
        _ name: String,
        from archive: Archive,
        to directory: URL
    ) throws -> URL {
        let entry = try entry(named: name, in: archive)
        let url = directory.appendingPathComponent(name)
        _ = try archive.extract(entry, to: url)
        return url
    }

    private func decode<T: Decodable>(
        _ type: T.Type,
        from entry: Entry,
        in archive: Archive
    ) throws -> T {
        var data = Data()
        _ = try archive.extract(entry) { chunk in
            data.append(chunk)
        }
        return try makeDecoder().decode(type, from: data)
    }

    private func dailyKey(for date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func weeklyKey(for date: Date) -> String {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = Calendar.current.timeZone
        let components = calendar.dateComponents(
            [.yearForWeekOfYear, .weekOfYear],
            from: date
        )
        return String(
            format: "%04d-W%02d",
            components.yearForWeekOfYear ?? 0,
            components.weekOfYear ?? 0
        )
    }

    private func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private static var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.5.0"
    }

    private static let readme = """
        Sori backup
        Format: \(BackupManifest.currentFormat), version \(BackupManifest.currentVersion)

        This is an unencrypted ZIP archive containing:
        - manifest.json: backup metadata
        - sori.sqlite: app database (library, progress, sessions, review, usage)
        - settings.json: app preferences
        - README.txt: this note

        It does NOT contain Keychain credentials or personal textbook audio.
        """
}
