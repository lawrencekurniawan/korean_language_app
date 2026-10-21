import Foundation
import Observation

@MainActor
@Observable
final class SplashCoordinator {
    private(set) var isPresented = false
    private(set) var stats: DashboardStats = .empty
    private(set) var isLoading = false

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let lastShownKey = "splash.lastShownAt"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Shows the daily summary the first time the app becomes active on a new day.
    func handleBecameActive(settings: SettingsStore, database: AppDatabase) async {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--skip-splash") {
            return
        }
        #endif

        guard settings.splashEnabled, !isPresented, !isLoading else { return }

        let now = Date()
        if let last = defaults.object(forKey: lastShownKey) as? Date,
           Calendar.current.isDate(last, inSameDayAs: now) {
            return
        }

        isLoading = true
        defaults.set(now, forKey: lastShownKey)
        stats = (try? await database.dashboardStats()) ?? .empty
        isLoading = false
        isPresented = true
    }

    func dismiss() {
        isPresented = false
    }
}
