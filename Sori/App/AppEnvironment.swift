import Foundation
import Observation

@MainActor
@Observable
final class AppEnvironment {
    let database: AppDatabase
    let settings: SettingsStore
    let startupError: String?

    init(database: AppDatabase, settings: SettingsStore, startupError: String? = nil) {
        self.database = database
        self.settings = settings
        self.startupError = startupError
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
