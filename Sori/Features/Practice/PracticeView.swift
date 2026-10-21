import SwiftUI

private enum PracticeMode: String, CaseIterable, Identifiable {
    case reading
    case typing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .reading: "Reading"
        case .typing: "Typing"
        }
    }

    var symbol: String {
        switch self {
        case .reading: "text.book.closed"
        case .typing: "keyboard"
        }
    }

    var headline: String {
        switch self {
        case .reading: "Read as much as you can"
        case .typing: "Type the sentence exactly"
        }
    }

    var blurb: String {
        switch self {
        case .reading:
            "Short sentences appear one at a time. Tap Next when you finish a sentence. Your characters per minute are logged at the end."
        case .typing:
            "Type each sentence using the built-in 2-set keyboard. Mistakes turn red immediately. Your net characters per minute are logged at the end."
        }
    }

    var milestone: String {
        switch self {
        case .reading: "Reading arrives in M2"
        case .typing: "Typing arrives in M3"
        }
    }
}

struct PracticeView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var mode: PracticeMode = .reading

    var body: some View {
        @Bindable var settings = env.settings

        NavigationStack {
            ScrollView {
                VStack(spacing: SoriSpacing.lg) {
                    Picker("Practice mode", selection: $mode) {
                        ForEach(PracticeMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    practiceCard(mode: mode, settings: settings)
                    howItWorks
                    recentCard
                }
                .padding(SoriSpacing.lg)
                .padding(.bottom, SoriSpacing.xl)
            }
            .soriScreenBackground()
            .navigationTitle("Practice")
        }
    }

    private func practiceCard(mode: PracticeMode, settings: SettingsStore) -> some View {
        let duration = mode == .reading ? settings.readingDuration : settings.typingDuration

        return SoriCard {
            VStack(alignment: .leading, spacing: SoriSpacing.md) {
                HStack {
                    Image(systemName: mode.symbol)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.soriAccent)
                        .frame(width: 42, height: 42)
                        .background(Color.soriAccent.opacity(0.12), in: Circle())

                    Spacer()

                    SoriBadge(text: duration.soriClock, tint: .soriSecondary)
                }

                VStack(alignment: .leading, spacing: SoriSpacing.xxs) {
                    Text(mode.headline)
                        .font(SoriFont.title)
                        .foregroundStyle(Color.soriInk)
                    Text(mode.blurb)
                        .font(SoriFont.body)
                        .foregroundStyle(Color.soriSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: SoriSpacing.sm) {
                    detailChip(symbol: "timer", text: "\(duration) s")
                    if mode == .typing {
                        detailChip(symbol: "keyboard", text: settings.keyboardMode.title)
                    } else {
                        detailChip(symbol: "textformat.size", text: "\(Int(settings.readingFontSize)) pt")
                    }
                }

                Button("Start \(mode.title.lowercased()) practice") {}
                    .buttonStyle(SoriPrimaryButtonStyle())
                    .disabled(true)
                    .opacity(0.55)

                Text(mode.milestone)
                    .font(SoriFont.caption)
                    .foregroundStyle(Color.soriSecondary)
            }
        }
    }

    private var howItWorks: some View {
        SoriCard {
            VStack(alignment: .leading, spacing: SoriSpacing.sm) {
                Text("How a session works")
                    .font(SoriFont.headline)
                    .foregroundStyle(Color.soriInk)

                bullet("The timer starts only when you tap Start.")
                bullet("The session runs for the configured duration.")
                bullet("Ending early discards the result.")
                bullet("Saved sessions use characters per minute, excluding spaces.")
            }
        }
    }

    private var recentCard: some View {
        SoriCard {
            VStack(alignment: .leading, spacing: SoriSpacing.xs) {
                SoriSectionHeader("Recent sessions")
                SoriEmptyState(
                    symbol: "clock.arrow.circlepath",
                    title: "No sessions yet",
                    message: "Your first reading or typing session will appear here."
                )
            }
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: SoriSpacing.xs) {
            Circle()
                .fill(Color.soriAccent)
                .frame(width: 4, height: 4)
                .padding(.top, 7)
            Text(text)
                .font(SoriFont.body)
                .foregroundStyle(Color.soriSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func detailChip(symbol: String, text: String) -> some View {
        Label(text, systemImage: symbol)
            .font(SoriFont.captionStrong)
            .foregroundStyle(Color.soriSecondary)
            .padding(.horizontal, SoriSpacing.sm)
            .padding(.vertical, 7)
            .background(Color.soriSurfaceElevated, in: Capsule())
    }
}
