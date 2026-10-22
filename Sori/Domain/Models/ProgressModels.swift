import Foundation

enum PracticeSkill: String, Sendable, CaseIterable {
    case reading
    case typing

    var title: String {
        switch self {
        case .reading: "Reading"
        case .typing: "Typing"
        }
    }

    var symbolName: String {
        switch self {
        case .reading: "book"
        case .typing: "keyboard"
        }
    }
}

enum ProgressRange: String, CaseIterable, Identifiable, Sendable {
    case oneMonth
    case threeMonths
    case sixMonths
    case oneYear
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .oneMonth: "1M"
        case .threeMonths: "3M"
        case .sixMonths: "6M"
        case .oneYear: "1Y"
        case .all: "All"
        }
    }

    func startDate(now: Date = Date(), calendar: Calendar = .current) -> Date? {
        switch self {
        case .oneMonth:
            calendar.date(byAdding: .month, value: -1, to: now)
        case .threeMonths:
            calendar.date(byAdding: .month, value: -3, to: now)
        case .sixMonths:
            calendar.date(byAdding: .month, value: -6, to: now)
        case .oneYear:
            calendar.date(byAdding: .year, value: -1, to: now)
        case .all:
            nil
        }
    }
}

enum ProgressAggregation: String, CaseIterable, Identifiable, Sendable {
    case daily
    case weekly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .daily: "Daily"
        case .weekly: "Weekly"
        }
    }
}

struct CPMSessionSample: Sendable, Equatable {
    let startedAt: Date
    let skill: PracticeSkill
    let cpm: Double
}

struct CPMPoint: Identifiable, Sendable, Equatable {
    let skill: PracticeSkill
    let date: Date
    let cpm: Double

    var id: String {
        "\(skill.rawValue)-\(date.timeIntervalSince1970)"
    }
}

struct TabUsage: Identifiable, Sendable, Equatable {
    let tab: String
    let seconds: Double

    var id: String { tab }
}
