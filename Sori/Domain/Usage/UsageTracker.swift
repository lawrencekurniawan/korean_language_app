import Foundation
import Observation

/// Records active time per top-level tab. Intervals are written when the tab
/// changes or the app leaves the foreground; the in-progress interval is kept in
/// memory and is intentionally not counted until it is committed.
@MainActor
@Observable
final class UsageTracker {
    @ObservationIgnored private let repository: UsageRepository

    private var currentTab: String?
    private var startedAt: Date?

    init(repository: UsageRepository) {
        self.repository = repository
    }

    func start(tab: AppTab, at now: Date = Date()) {
        if currentTab == tab.rawValue, startedAt != nil {
            return
        }

        flush(until: now)
        currentTab = tab.rawValue
        startedAt = now
    }

    func stop(at now: Date = Date()) {
        flush(until: now)
        currentTab = nil
    }

    func timeByTab() async -> [TabUsage] {
        (try? await repository.timeByTab()) ?? []
    }

    private func flush(until now: Date) {
        guard let tab = currentTab, let start = startedAt else { return }
        startedAt = nil

        let duration = now.timeIntervalSince(start)
        guard duration >= 1 else { return }

        Task {
            try? await repository.record(
                tab: tab,
                startedAt: start,
                endedAt: now
            )
        }
    }
}
