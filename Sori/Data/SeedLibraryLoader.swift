import Foundation

struct SeedLibraryLoader: Sendable {
    static let metaKey = "librarySeedVersion"

    let database: AppDatabase
    let importer: CorpusImporter

    func seedIfNeeded(seedData: Data? = nil) async throws -> SeedResult {
        let data: Data
        if let seedData {
            data = seedData
        } else {
            guard let url = Bundle.main.url(forResource: "library-seed", withExtension: "json") else {
                throw ImportError.unreadable("The starter library is missing from the app bundle.")
            }
            data = try Data(contentsOf: url)
        }

        let seed: SeedLibrary
        do {
            seed = try JSONDecoder().decode(SeedLibrary.self, from: data)
        } catch {
            throw ImportError.unreadable("The starter library could not be decoded.")
        }

        if try await database.metaValue(forKey: Self.metaKey) == seed.version {
            return .alreadyPresent
        }

        var importedArticles = 0
        var importedSentences = 0
        var skippedArticles = 0
        var totalBytes = 0

        // Import in reverse so modern Wikipedia articles are the newest rows and
        // appear first in the library. The four public-domain classics stay at
        // the end as advanced reading.
        for article in seed.articles.reversed() {
            do {
                let result = try await importer.importDocument(article.document)
                if result.wasDuplicate {
                    skippedArticles += 1
                } else {
                    importedArticles += 1
                    importedSentences += result.newSentenceCount
                    totalBytes += result.byteSize
                }
            } catch ImportError.libraryFull {
                throw ImportError.libraryFull
            } catch {
                skippedArticles += 1
            }
        }

        try await database.setMetaValue(seed.version, forKey: Self.metaKey)
        return SeedResult(
            importedArticles: importedArticles,
            importedSentences: importedSentences,
            skippedArticles: skippedArticles,
            totalBytes: totalBytes,
            alreadySeeded: false
        )
    }
}
