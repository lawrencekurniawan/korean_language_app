import Charts
import SwiftUI

struct ProgressDashboardView: View {
    @Environment(AppEnvironment.self) private var env

    @State private var stats: DashboardStats = .empty
    @State private var points: [CPMPoint] = []
    @State private var sessions: [PracticeSessionRecord] = []
    @State private var usage: [TabUsage] = []
    @State private var range: ProgressRange = .threeMonths
    @State private var aggregation: ProgressAggregation = .daily
    @State private var filter: SessionFilter = .all
    @State private var sessionToDelete: PracticeSessionRecord?
    @State private var loadError: String?

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: SoriSpacing.lg) {
                        if let loadError {
                            errorCard(loadError)
                        }

                        chartCard
                        statsGrid
                        sessionsCard
                        timeCard
                            .id("progress-bottom")
                    }
                    .padding(SoriSpacing.lg)
                    .padding(.bottom, SoriSpacing.xl)
                }
                .soriScreenBackground()
                .navigationTitle("Progress")
                .refreshable {
                    await loadAll()
                }
                .onAppear {
                    Task { await loadAll() }

                    #if DEBUG
                    if ProcessInfo.processInfo.arguments.contains("--progress-bottom") {
                        Task {
                            try? await Task.sleep(for: .milliseconds(800))
                            proxy.scrollTo("progress-bottom", anchor: .bottom)
                        }
                    }
                    #endif
                }
                .onChange(of: range) { _, _ in
                    Task { await loadChart() }
                }
                .onChange(of: aggregation) { _, _ in
                    Task { await loadChart() }
                }
                .confirmationDialog(
                    "Delete this session?",
                    isPresented: Binding(
                        get: { sessionToDelete != nil },
                        set: { if !$0 { sessionToDelete = nil } }
                    ),
                    presenting: sessionToDelete
                ) { session in
                    Button("Delete session", role: .destructive) {
                        Task { await deleteSession(session) }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: { session in
                    Text(
                        "The \(session.skillTitle.lowercased()) session from "
                            + "\(session.startedAt.formatted(date: .abbreviated, time: .shortened)) "
                            + "will be removed. This cannot be undone."
                    )
                }
            }
        }
    }

    // MARK: - Loading

    private func loadAll() async {
        await loadOverview()
        await loadChart()
    }

    private func loadOverview() async {
        stats = (try? await env.database.dashboardStats()) ?? .empty
        sessions = (try? await env.practice.recentSessions(limit: 100)) ?? []
        usage = await env.usage.timeByTab()
    }

    private func loadChart() async {
        let now = Date()
        do {
            let samples = try await env.practice.cpmSamples(
                since: range.startDate(now: now)
            )
            points = ProgressAggregator.points(
                from: samples,
                range: range,
                aggregation: aggregation,
                now: now
            )
            loadError = nil
        } catch {
            points = []
            loadError = "Progress data could not be loaded. \(error.localizedDescription)"
        }
    }

    private func deleteSession(_ session: PracticeSessionRecord) async {
        do {
            try await env.practice.deleteSession(id: session.id)
            sessionToDelete = nil
            await loadAll()
        } catch {
            loadError = "The session could not be deleted. \(error.localizedDescription)"
        }
    }

    // MARK: - Chart

    private var chartCard: some View {
        SoriCard {
            VStack(alignment: .leading, spacing: SoriSpacing.md) {
                SoriSectionHeader(
                    "Speed",
                    subtitle: "\(aggregation.title) mean in characters per minute"
                )

                Picker("Range", selection: $range) {
                    ForEach(ProgressRange.allCases) { value in
                        Text(value.title).tag(value)
                    }
                }
                .pickerStyle(.segmented)

                HStack(spacing: SoriSpacing.md) {
                    legendDot("Reading", color: color(for: .reading))
                    legendDot("Typing", color: color(for: .typing))
                    Spacer()
                    Picker("Aggregation", selection: $aggregation) {
                        ForEach(ProgressAggregation.allCases) { value in
                            Text(value.title).tag(value)
                        }
                    }
                    .pickerStyle(.menu)
                    .font(SoriFont.caption)
                }

                if points.isEmpty {
                    emptyChart
                } else {
                    Chart(points) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("CPM", point.cpm),
                            series: .value("Skill", point.skill.title)
                        )
                        .foregroundStyle(color(for: point.skill))
                        .interpolationMethod(.monotone)

                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("CPM", point.cpm)
                        )
                        .foregroundStyle(color(for: point.skill))
                        .symbolSize(26)
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                            AxisGridLine()
                            AxisValueLabel(
                                format: .dateTime.month().day(),
                                collisionResolution: .disabled
                            )
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .chartXScale(range: .plotDimension(padding: 12))
                    .frame(height: 200)
                    .accessibilityLabel("Characters per minute chart")
                }

                Text(
                    "Each point is the \(aggregation.title.lowercased()) mean of saved "
                        + "sessions in the selected range."
                )
                .font(SoriFont.caption)
                .foregroundStyle(Color.soriSecondary)
            }
        }
    }

    private var emptyChart: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    Color.soriBorder,
                    style: StrokeStyle(lineWidth: 1, dash: [5, 5])
                )
                .frame(height: 200)

            SoriEmptyState(
                symbol: "chart.xyaxis.line",
                title: "No data in this range",
                message: "Complete a reading or typing session to start the chart."
            )
        }
    }

    private func color(for skill: PracticeSkill) -> Color {
        skill == .reading ? .soriAccent : .soriWarning
    }

    // MARK: - Stats

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

    // MARK: - Sessions

    private var sessionsCard: some View {
        SoriCard {
            VStack(alignment: .leading, spacing: SoriSpacing.sm) {
                SoriSectionHeader("Sessions", subtitle: "Newest first · delete an entry")

                Picker("Filter", selection: $filter) {
                    ForEach(SessionFilter.allCases) { value in
                        Text(value.title).tag(value)
                    }
                }
                .pickerStyle(.segmented)

                if filteredSessions.isEmpty {
                    SoriEmptyState(
                        symbol: "list.bullet.rectangle",
                        title: "Nothing logged",
                        message: "Saved sessions will be listed here with their date, skill, and CPM."
                    )
                } else {
                    VStack(spacing: 0) {
                        ForEach(filteredSessions) { session in
                            sessionRow(session)

                            if session.id != filteredSessions.last?.id {
                                Divider()
                                    .overlay(Color.soriBorder)
                            }
                        }
                    }
                }
            }
        }
    }

    private var filteredSessions: [PracticeSessionRecord] {
        switch filter {
        case .all:
            sessions
        case .reading:
            sessions.filter { $0.skill == PracticeSkill.reading.rawValue }
        case .typing:
            sessions.filter { $0.skill == PracticeSkill.typing.rawValue }
        }
    }

    private func sessionRow(_ session: PracticeSessionRecord) -> some View {
        HStack(spacing: SoriSpacing.sm) {
            Image(systemName: session.skill == PracticeSkill.typing.rawValue ? "keyboard" : "book")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.soriAccent)
                .frame(width: 32, height: 32)
                .background(Color.soriAccent.opacity(0.10), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(session.skillTitle)
                    .font(SoriFont.callout)
                    .foregroundStyle(Color.soriInk)
                Text(
                    session.startedAt.formatted(
                        date: .abbreviated,
                        time: .shortened
                    )
                )
                .font(SoriFont.caption)
                .foregroundStyle(Color.soriSecondary)
            }

            Spacer(minLength: SoriSpacing.xs)

            VStack(alignment: .trailing, spacing: 1) {
                Text(formatCPM(session.cpmNet))
                    .font(SoriFont.headline)
                    .foregroundStyle(Color.soriInk)
                Text("CPM")
                    .font(SoriFont.caption)
                    .foregroundStyle(Color.soriTertiary)
            }

            Button {
                sessionToDelete = session
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.soriTertiary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete \(session.skillTitle.lowercased()) session")
        }
        .padding(.vertical, SoriSpacing.xs)
    }

    // MARK: - Time

    private var timeCard: some View {
        SoriCard {
            VStack(alignment: .leading, spacing: SoriSpacing.md) {
                SoriSectionHeader("Time spent", subtitle: "All time by tab")

                if orderedUsage.isEmpty {
                    SoriEmptyState(
                        symbol: "hourglass",
                        title: "No time recorded",
                        message: "Active time in Learn, Practice, Speak, Progress, and Settings will appear here."
                    )
                } else {
                    VStack(spacing: SoriSpacing.md) {
                        ForEach(orderedUsage) { item in
                            usageRow(item)
                        }
                    }

                    Text("Review time is counted in Learn.")
                        .font(SoriFont.caption)
                        .foregroundStyle(Color.soriTertiary)
                }
            }
        }
    }

    private var orderedUsage: [TabUsage] {
        let order = ["learn", "practice", "speak", "progress", "settings"]
        return order.compactMap { tab in
            usage.first { $0.tab == tab }
        }
    }

    private var totalUsageSeconds: Double {
        orderedUsage.reduce(0) { $0 + $1.seconds }
    }

    private func usageRow(_ item: TabUsage) -> some View {
        let fraction = totalUsageSeconds > 0 ? item.seconds / totalUsageSeconds : 0

        return VStack(spacing: 5) {
            HStack(spacing: SoriSpacing.xs) {
                Image(systemName: usageSymbol(for: item.tab))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(usageColor(for: item.tab))
                    .frame(width: 24)

                Text(usageTitle(for: item.tab))
                    .font(SoriFont.callout)
                    .foregroundStyle(Color.soriInk)

                Spacer()

                Text(formatDuration(item.seconds))
                    .font(SoriFont.captionStrong)
                    .foregroundStyle(Color.soriSecondary)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.soriBorder.opacity(0.55))
                    Capsule()
                        .fill(usageColor(for: item.tab))
                        .frame(width: max(4, proxy.size.width * fraction))
                }
            }
            .frame(height: 7)
        }
    }

    private func usageTitle(for tab: String) -> String {
        switch tab {
        case "learn": "Learn"
        case "practice": "Practice"
        case "speak": "Speak"
        case "progress": "Progress"
        case "settings": "Settings"
        default: tab.capitalized
        }
    }

    private func usageSymbol(for tab: String) -> String {
        switch tab {
        case "learn": "book"
        case "practice": "keyboard"
        case "speak": "waveform"
        case "progress": "chart.line.uptrend.xyaxis"
        case "settings": "gearshape"
        default: "circle"
        }
    }

    private func usageColor(for tab: String) -> Color {
        switch tab {
        case "learn": .soriAccent
        case "practice": .soriCorrect
        case "speak": .soriWarning
        case "progress": .soriSecondary
        default: .soriTertiary
        }
    }

    // MARK: - Helpers

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

    private func formatDuration(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        if minutes > 0 {
            return "\(minutes)m"
        }
        return "<1m"
    }

    private func errorCard(_ message: String) -> some View {
        SoriCard {
            Label {
                Text(message)
                    .font(SoriFont.caption)
                    .foregroundStyle(Color.soriInk)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.soriWarning)
            }
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
