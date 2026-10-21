import Foundation

struct DashboardStats: Sendable, Equatable {
    var streakDays: Int
    var bestReadingCPM: Double?
    var bestTypingCPM: Double?
    var dueCards: Int
    var minutesThisWeek: Int
    var lessonsCompleted: Int

    static let empty = DashboardStats(
        streakDays: 0,
        bestReadingCPM: nil,
        bestTypingCPM: nil,
        dueCards: 0,
        minutesThisWeek: 0,
        lessonsCompleted: 0
    )

    var bestCPM: Double? {
        [bestReadingCPM, bestTypingCPM].compactMap(\.self).max()
    }
}
