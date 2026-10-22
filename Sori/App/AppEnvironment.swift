import Foundation
import Observation

@MainActor
@Observable
final class AppEnvironment {
    let database: AppDatabase
    let settings: SettingsStore
    let library: LibraryRepository
    let importer: CorpusImporter
    let practice: PracticeRepository
    let curriculum: CurriculumStore
    let personalAudio: PersonalAudioStore
    let review: ReviewStore
    let startupError: String?

    var libraryStatus: LibraryStatus = .unknown
    private(set) var librarySummary: LibrarySummary?
    private(set) var libraryRevision = 0
    private var isPreparingLibrary = false

    init(database: AppDatabase, settings: SettingsStore, startupError: String? = nil) {
        self.database = database
        self.settings = settings
        self.startupError = startupError
        self.library = LibraryRepository(database: database)
        self.importer = CorpusImporter(database: database)
        self.practice = PracticeRepository(database: database)
        self.curriculum = CurriculumStore(database: database)
        self.personalAudio = PersonalAudioStore()
        self.review = ReviewStore(database: database)
    }

    var isSeedingLibrary: Bool {
        if case .seeding = libraryStatus { return true }
        return false
    }

    var libraryFailure: String? {
        if case .failed(let message) = libraryStatus { return message }
        return nil
    }

    func prepareLibrary() async {
        guard !isPreparingLibrary else { return }
        if case .ready = libraryStatus, librarySummary != nil { return }

        isPreparingLibrary = true
        libraryStatus = .seeding

        do {
            let result = try await SeedLibraryLoader(
                database: database,
                importer: importer
            ).seedIfNeeded()
            librarySummary = try await library.summary()
            libraryStatus = .ready(result)
        } catch {
            libraryStatus = .failed(error.localizedDescription)
            librarySummary = try? await library.summary()
        }

        libraryRevision += 1
        isPreparingLibrary = false
    }

    func refreshLibrary() async {
        guard !isPreparingLibrary else { return }
        if let summary = try? await library.summary() {
            librarySummary = summary
        }
        libraryRevision += 1
    }

    func libraryDidChange() async {
        await refreshLibrary()
    }

    func prepareCurriculum() async {
        await curriculum.refresh()
    }

    func prepareReview() async {
        await review.sync(
            curriculum: curriculum.curriculum,
            completedLessonIDs: curriculum.completedLessonIDs
        )
    }

    func completeLesson(_ lessonID: String) async {
        await curriculum.complete(lessonID)
        await prepareReview()
    }

    static func live() -> AppEnvironment {
        let settings = SettingsStore()
        do {
            return AppEnvironment(database: try AppDatabase.onDisk(), settings: settings)
        } catch {
            if let fallback = try? AppDatabase.inMemory() {
                return AppEnvironment(
                    database: fallback,
                    settings: settings,
                    startupError: "The library database could not be opened. Changes will not be saved. \(error.localizedDescription)"
                )
            }
            fatalError("Sori could not create a database: \(error)")
        }
    }
}
