import SwiftUI

struct ProgressDashboardView: View {
    @Environment(AppEnvironment.self) private var env

    @State private var stats: DashboardStats = .empty
    @State private var range: ProgressRange = .threeMonths
    @State private var aggregation: Aggregation = .daily
    @State private var filter: SessionFilter = .all

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SoriSpacing.lg) {
                    chartCard
                    statsGrid
                    sessionsCard
                    timeCard
                }
                .padding(SoriSpacing.lg)
                .padding(.bottom, SoriSpacing.xl)
            }
            .soriScreenBackground()
            .navigationTitle("Progress")
            .task {
                stats = (try? await env.database.dashboardStats()) ?? .empty
            }
        }
    }

    private var chartCard: some View {
        SoriCard {
            VStack(alignment: .leading, spacing: SoriSpacing.md) {
                SoriSectionHeader("Speed", subtitle: "Characters per minute")

                Picker("Range", selection: $range) {
                    ForEach(ProgressRange.allCases) { range in
                        Text(range.title).tag(range)
                    }
                }
                .pickerStyle(.segmented)

                HStack(spacing: SoriSpacing.md) {
                    legendDot("Reading", color: .soriAccent)
                    legendDot("Typing", color: .soriCorrect)
                    Spacer()
                    Picker("Aggregation", selection: $aggregation) {
                        ForEach(Aggregation.allCases) { value in
                            Text(value.title).tag(value)
                        }
                    }
                    .pickerStyle(.menu)
                    .font(SoriFont.caption)
                }

                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            Color.soriBorder,
                            style: StrokeStyle(lineWidth: 1, dash: [5, 5])
                        )
                        .frame(height: 180)

                    SoriEmptyState(
                        symbol: "chart.xyaxis.line",
                        title: "No data yet",
                        message: "Complete a reading or typing session to start the chart."
                    )
                }

                Text("Daily or weekly mean of session CPM. Range: \(range.title).")
                    .font(SoriFont.caption)
                    .foregroundStyle(Color.soriSecondary)
            }
        }
    }

    private var statsGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: SoriSpacing.sm),
                      GridItem(.flexible(), spacing: SoriSpacing.sm)],
            spacing: SoriSpacing.sm
        ) {
            SoriStatTile(
                label: "Streak",
                value: "\(stats.streakDays)",
                unit: "days",
                symbol: "flame"
            )
            SoriStatTile(
                label: "Best reading",
                value: formatCPM(stats.bestReadingCPM),
                unit: "CPM",
                symbol: "book"
            )
            SoriStatTile(
                label: "Best typing",
                value: formatCPM(stats.bestTypingCPM),
                unit: "CPM",
                symbol: "keyboard"
            )
            SoriStatTile(
                label: "This week",
                value: "\(stats.minutesThisWeek)",
                unit: "min",
                symbol: "clock"
            )
        }
    }

    private var sessionsCard: some View {
        SoriCard {
            VStack(alignment: .leading, spacing: SoriSpacing.sm) {
                SoriSectionHeader("Sessions", subtitle: "Review or delete a session")

                Picker("Filter", selection: $filter) {
                    ForEach(SessionFilter.allCases) { value in
                        Text(value.title).tag(value)
                    }
                }
                .pickerStyle(.segmented)

                SoriEmptyState(
                    symbol: "list.bullet.rectangle",
                    title: "Nothing logged",
                    message: "Saved sessions will be listed here with their date, skill, and CPM."
                )
            }
        }
    }

    private var timeCard: some View {
        SoriCard {
            VStack(alignment: .leading, spacing: SoriSpacing.sm) {
                SoriSectionHeader("Time spent", subtitle: "By learning tab")
                SoriEmptyState(
                    symbol: "hourglass",
                    title: "No time recorded",
                    message: "Active time in Learn, Practice, Speak, and Review will appear here."
                )
            }
        }
    }

    private func legendDot(_ label: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(label)
                .font(SoriFont.caption)
                .foregroundStyle(Color.soriSecondary)
        }
    }

    private func formatCPM(_ value: Double?) -> String {
        guard let value else { return "–" }
        return String(format: "%.0f", value)
    }
}

private enum ProgressRange: String, CaseIterable, Identifiable {
    case oneMonth, threeMonths, sixMonths, oneYear, all

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
}

private enum Aggregation: String, CaseIterable, Identifiable {
    case daily, weekly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .daily: "Daily"
        case .weekly: "Weekly"
        }
    }
}

private enum SessionFilter: String, CaseIterable, Identifiable {
    case all, reading, typing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All"
        case .reading: "Reading"
        case .typing: "Typing"
        }
    }
}
