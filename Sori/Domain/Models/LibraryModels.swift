import Foundation

// MARK: - Documents

enum ArticleKind: String, Codable, Sendable, CaseIterable {
    case prose
    case dialogue
    case subtitle
    case textbook

    var title: String {
        switch self {
        case .prose: "Prose"
        case .dialogue: "Dialogue"
        case .subtitle: "Subtitle"
        case .textbook: "Textbook"
        }
    }
}

struct ImportedDocument: Sendable, Equatable {
    var title: String
    var text: String
    var source: String
    var sourceURL: URL?
    var license: String?
    var attribution: String?
    var kind: ArticleKind
}

struct ImportResult: Sendable, Equatable {
    let articleID: Int64
    let title: String
    let sentenceCount: Int
    let newSentenceCount: Int
    let byteSize: Int
    let wasDuplicate: Bool
}

// MARK: - Library

enum LibraryLimits {
    static let targetBytes = 2_000_000
    static let hardCapBytes = 10_000_000
}

struct LibraryArticle: Identifiable, Sendable, Equatable {
    let id: Int64
    let title: String
    let source: String
    let sourceURL: URL?
    let license: String?
    let attribution: String?
    let kind: ArticleKind
    let byteSize: Int
    let sentenceCount: Int
    let averageDifficulty: Int?
    let minDifficulty: Int?
    let maxDifficulty: Int?
    let importedAt: Date
    let isArchived: Bool
}

struct LibrarySummary: Sendable, Equatable {
    var articleCount: Int
    var activeSentenceCount: Int
    var seenSentenceCount: Int
    var totalBytes: Int
    var targetBytes: Int
    var hardCapBytes: Int

    static let empty = LibrarySummary(
        articleCount: 0,
        activeSentenceCount: 0,
        seenSentenceCount: 0,
        totalBytes: 0,
        targetBytes: LibraryLimits.targetBytes,
        hardCapBytes: LibraryLimits.hardCapBytes
    )

    var coverage: Double {
        guard activeSentenceCount > 0 else { return 0 }
        return min(Double(seenSentenceCount) / Double(activeSentenceCount), 1)
    }

    var targetProgress: Double {
        guard targetBytes > 0 else { return 0 }
        return min(Double(totalBytes) / Double(targetBytes), 1)
    }

    var isAtTarget: Bool { totalBytes >= targetBytes }
    var isAtHardCap: Bool { totalBytes >= hardCapBytes }

    /// The 95% rule: once almost every active sentence has been seen, the
    /// library is no longer providing enough variety for practice.
    var needsMoreContent: Bool {
        activeSentenceCount > 0 && coverage >= 0.95
    }

    var remainingTargetBytes: Int { max(targetBytes - totalBytes, 0) }
}

struct PracticeSentence: Identifiable, Sendable, Equatable {
    let id: Int64
    let text: String
    let difficulty: Int
}

// MARK: - Seeding

struct SeedArticle: Codable, Sendable {
    let id: String
    let title: String
    let source: String
    let sourceURL: String?
    let license: String?
    let attribution: String?
    let kind: String?
    let text: String

    var document: ImportedDocument {
        ImportedDocument(
            title: title,
            text: text,
            source: source,
            sourceURL: sourceURL.flatMap(URL.init(string:)),
            license: license,
            attribution: attribution,
            kind: ArticleKind(rawValue: kind ?? "") ?? .prose
        )
    }
}

struct SeedLibrary: Codable, Sendable {
    let version: String
    let generatedAt: String?
    let description: String?
    let articles: [SeedArticle]
}

struct SeedResult: Sendable, Equatable {
    var importedArticles: Int
    var importedSentences: Int
    var skippedArticles: Int
    var totalBytes: Int
    var alreadySeeded: Bool

    static let alreadyPresent = SeedResult(
        importedArticles: 0,
        importedSentences: 0,
        skippedArticles: 0,
        totalBytes: 0,
        alreadySeeded: true
    )
}

enum LibraryStatus: Sendable, Equatable {
    case unknown
    case seeding
    case ready(SeedResult)
    case failed(String)
}

// MARK: - Errors

enum ImportError: LocalizedError, Equatable {
    case emptyDocument
    case noKoreanText
    case libraryFull
    case unreadable(String)
    case unsupportedFormat(String)
    case noSubtitles

    var errorDescription: String? {
        switch self {
        case .emptyDocument:
            "There was no text to import."
        case .noKoreanText:
            "This file does not contain enough Korean text."
        case .libraryFull:
            "The library has reached its 10 MB hard cap. Delete an article or archive one before importing more."
        case .unreadable(let detail):
            "The file could not be read. \(detail)"
        case .unsupportedFormat(let ext):
            "The .\(ext) format is not supported."
        case .noSubtitles:
            "No Korean subtitle text was found."
        }
    }
}
