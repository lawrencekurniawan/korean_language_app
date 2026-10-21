import SwiftUI

struct DailySplashView: View {
    let stats: DashboardStats
    let autoCloseSeconds: Int
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false
    @State private var remainingSeconds: Int

    init(stats: DashboardStats, autoCloseSeconds: Int, onClose: @escaping () -> Void) {
        self.stats = stats
        self.autoCloseSeconds = autoCloseSeconds
        self.onClose = onClose
        _remainingSeconds = State(initialValue: autoCloseSeconds)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.soriBackground, Color.soriSurfaceElevated],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: SoriSpacing.lg) {
                    header
                    greeting
                    statsGrid
                    footer
                }
                .padding(SoriSpacing.lg)
                .padding(.top, SoriSpacing.lg)
                .padding(.bottom, SoriSpacing.xxl)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                HStack {
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.soriSecondary)
                            .frame(width: 34, height: 34)
                            .background(Color.soriSurface, in: Circle())
                            .overlay(Circle().strokeBorder(Color.soriBorder, lineWidth: 1))
                    }
                    .accessibilityLabel("Close daily summary")
                }
                .padding(.horizontal, SoriSpacing.lg)
                .padding(.top, SoriSpacing.xs)
            }
        }
        .opacity(hasAppeared ? 1 : 0)
        .scaleEffect(hasAppeared || reduceMotion ? 1 : 0.985)
        .onAppear {
            if reduceMotion {
                hasAppeared = true
            } else {
                withAnimation(.easeOut(duration: 0.28)) {
                    hasAppeared = true
                }
            }
        }
        .task(id: autoCloseSeconds) {
            guard autoCloseSeconds > 0 else { return }
            for _ in 0..<autoCloseSeconds {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                remainingSeconds = max(0, remainingSeconds - 1)
            }
            onClose()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: SoriSpacing.xxs) {
            Text("소리")
                .font(.system(size: 42, weight: .bold))
                .foregroundStyle(Color.soriAccent)
            Text(greetingText)
                .font(SoriFont.largeTitle)
                .foregroundStyle(Color.soriInk)
            Text(dateText)
                .font(SoriFont.callout)
                .foregroundStyle(Color.soriSecondary)
        }
        .padding(.top, SoriSpacing.md)
    }

    private var greeting: some View {
        Text("A little practice today beats a perfect plan tomorrow.")
            .font(SoriFont.body)
            .foregroundStyle(Color.soriSecondary)
            .fixedSize(horizontal: false, vertical: true)
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
                unit: stats.streakDays == 1 ? "day" : "days",
                symbol: "flame"
            )
            SoriStatTile(
                label: "Best CPM",
                value: formatCPM(stats.bestCPM),
                unit: "chars/min",
                symbol: "speedometer"
            )
            SoriStatTile(
                label: "Reviews due",
                value: "\(stats.dueCards)",
                unit: "cards",
                symbol: "arrow.triangle.2.circlepath"
            )
            SoriStatTile(
                label: "This week",
                value: "\(stats.minutesThisWeek)",
                unit: "min",
                symbol: "clock"
            )
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: SoriSpacing.md) {
            HStack(spacing: SoriSpacing.lg) {
                miniStat("Reading", formatCPM(stats.bestReadingCPM))
                miniStat("Typing", formatCPM(stats.bestTypingCPM))
                miniStat("Lessons", "\(stats.lessonsCompleted)")
            }

            Button("Start today") {
                onClose()
            }
            .buttonStyle(SoriPrimaryButtonStyle())

            Text(autoCloseSeconds > 0
                 ? "Closing in \(remainingSeconds)s"
                 : "Tap Start today to continue")
                .font(SoriFont.caption)
                .foregroundStyle(Color.soriTertiary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func miniStat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(Color.soriTertiary)
            Text(value)
                .font(SoriFont.callout)
                .foregroundStyle(Color.soriInk)
        }
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 EEEE"
        return formatter.string(from: Date())
    }

    private func formatCPM(_ value: Double?) -> String {
        guard let value else { return "–" }
        return String(format: "%.0f", value)
    }
}
