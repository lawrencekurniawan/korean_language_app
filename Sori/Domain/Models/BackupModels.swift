import Foundation

enum BackupFrequency: String, Sendable, CaseIterable {
    case daily
    case weekly

    var title: String {
        switch self {
        case .daily: "Daily"
        case .weekly: "Weekly"
        }
    }
}

struct BackupManifest: Codable, Sendable, Equatable {
    static let currentFormat = "sori-backup"
    static let currentVersion = 1

    let format: String
    let formatVersion: Int
    let createdAt: Date
    let appVersion: String
    let curriculumVersion: String
    let schemaVersion: String
    let containsCredentials: Bool
}

struct BackupRecord: Identifiable, Sendable, Equatable {
    let url: URL
    let frequency: BackupFrequency
    let createdAt: Date
    let byteCount: Int64

    var id: URL { url }
    var fileName: String { url.lastPathComponent }
    var sizeText: String { TextNormalizer.formatBytes(Int(byteCount)) }
}

struct SettingsSnapshot: Codable, Sendable, Equatable {
    let appearance: String
    let readingDuration: Int
    let typingDuration: Int
    let readingFontSize: Double
    let typingFontSize: Double
    let speakFontSize: Double
    let appLanguage: String
    let explanationLanguage: String
    let splashEnabled: Bool
    let splashAutoCloseSeconds: Int
    let keyboardMode: String
    let speakAutoMode: Bool
    let voiceIdentifier: String
    let speechRate: Double
    let repeatCount: Int
}

enum BackupError: LocalizedError {
    case busy
    case invalidArchive
    case missingEntry(String)
    case unsupportedFormat
    case invalidDatabase

    var errorDescription: String? {
        switch self {
        case .busy:
            "A backup operation is already running."
        case .invalidArchive:
            "This file is not a valid Sori backup."
        case .missingEntry(let name):
            "The backup is missing \(name)."
        case .unsupportedFormat:
            "This backup was created by a newer version of Sori."
        case .invalidDatabase:
            "The backup's database could not be opened."
        }
    }
}
