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
            "Type each sentence exactly. Mistakes turn red immediately. Your net characters per minute are logged at the end."
        }
    }
}

struct PracticeView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var mode: PracticeMode = .reading
    @State private var readingSentences: [PracticeSentence] = []
    @State private var typingSentences: [PracticeSentence] = []
    @State private var showingReadingSession = false
    @State private var showingTypingSession = false
    @State private var isPreparingReading = false
    @State private var isPreparingTyping = false
    @State private var sessions: [PracticeSessionRecord] = []
    @State private var alertMessage: String?
    #if DEBUG
    @State private var didAttemptDebugStart = false
    @State private var didAttemptDebugTypingStart = false
    #endif

    private var librarySentenceCount: Int {
        env.librarySummary?.activeSentenceCount ?? 0
    }

    private var hasLibraryContent: Bool {
        librarySentenceCount > 0
    }

    private var readingSessionDuration: Int {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--reading-15") {
            return 15
        }
        #endif
        return env.settings.readingDuration
    }

    private var typingSessionDuration: Int {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--typing-15") {
            return 15
        }
        #endif
        return env.settings.typingDuration
    }

    private var effectiveKeyboardMode: KeyboardMode {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--system-keyboard") {
            return .system
        }
        #endif
        return env.settings.keyboardMode
    }

    private var isPreparing: Bool {
        isPreparingReading || isPreparingTyping
    }

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
                    .disabled(isPreparing)

                    practiceCard(mode: mode, settings: settings)
                    howItWorks
                    recentCard
                }
                .padding(SoriSpacing.lg)
                .padding(.bottom, SoriSpacing.xl)
            }
            .soriScreenBackground()
            #if DEBUG
            .defaultScrollAnchor(
                ProcessInfo.processInfo.arguments.contains("--practice-recent")
                    ? .bottom
                    : .top
            )
            #endif
            .navigationTitle("Practice")
        }
        .task {
            await loadRecentSessions()
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--typing-setup") {
                mode = .typing
            } else if ProcessInfo.processInfo.arguments.contains("--typing"), !didAttemptDebugTypingStart {
                didAttemptDebugTypingStart = true
                mode = .typing
                await startTyping()
            } else if ProcessInfo.processInfo.arguments.contains("--reading"), !didAttemptDebugStart {
                didAttemptDebugStart = true
                await startReading()
            }
            #endif
        }
        .fullScreenCover(
            isPresented: $showingReadingSession,
            onDismiss: {
                Task {
                    await loadRecentSessions()
                    await env.refreshLibrary()
                }
            }
        ) {
            ReadingSessionView(
                sentences: readingSentences,
                plannedDuration: readingSessionDuration,
                fontSize: env.settings.readingFontSize
            )
        }
        .fullScreenCover(
            isPresented: $showingTypingSession,
            onDismiss: {
                Task {
                    await loadRecentSessions()
                    await env.refreshLibrary()
                }
            }
        ) {
            TypingSessionView(
                sentences: typingSentences,
                plannedDuration: typingSessionDuration,
                fontSize: env.settings.typingFontSize,
                keyboardMode: effectiveKeyboardMode
            )
        }
        .alert(
            "Practice unavailable",
            isPresented: Binding(
                get: { alertMessage != nil },
                set: { if !$0 { alertMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private func practiceCard(mode: PracticeMode, settings: SettingsStore) -> some View {
        let duration = mode == .reading ? settings.readingDuration : settings.typingDuration
        let isReading = mode == .reading

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
                    detailChip(symbol: "books.vertical", text: "Library")
                    if mode == .typing {
                        detailChip(
                            symbol: "keyboard",
                            text: effectiveKeyboardMode == .builtIn ? "2-set" : "System"
                        )
                    } else {
                        detailChip(symbol: "textformat.size", text: "\(Int(settings.readingFontSize)) pt")
                    }
                }

                Button {
                    let requestedMode = mode
                    Task { await startSession(requestedMode) }
                } label: {
                    if isPreparing {
                        HStack(spacing: SoriSpacing.xs) {
                            ProgressView()
                                .tint(Color.soriBackground)
                            Text("Preparing sentences…")
                        }
                    } else {
                        Text("Start \(mode.title.lowercased()) practice")
                    }
                }
                .buttonStyle(SoriPrimaryButtonStyle())
                .disabled(isPreparing || !hasLibraryContent)
                .opacity(hasLibraryContent ? 1 : 0.55)

                if isReading {
                    Text(
                        hasLibraryContent
                            ? "\(librarySentenceCount.formatted()) library sentences available."
                            : "Preparing the library. Add Korean text in Library if this stays empty."
                    )
                    .font(SoriFont.caption)
                    .foregroundStyle(Color.soriSecondary)
                } else {
                    Text("Modern Hangul sentences · \(effectiveKeyboardMode.title)")
                        .font(SoriFont.caption)
                        .foregroundStyle(Color.soriSecondary)
                }
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
                bullet("Manual End discards the result; a completed timer saves it.")
                bullet("Reading counts completed sentences; typing counts correct characters.")
                bullet("CPM excludes spaces. Typing errors stay red until corrected.")
            }
        }
    }

    private var recentCard: some View {
        SoriCard {
            VStack(alignment: .leading, spacing: SoriSpacing.xs) {
                SoriSectionHeader("Recent sessions")

                if sessions.isEmpty {
                    SoriEmptyState(
                        symbol: "clock.arrow.circlepath",
                        title: "No sessions yet",
                        message: "Your first reading or typing session will appear here."
                    )
                } else {
                    ForEach(sessions) { session in
                        sessionRow(session)
                        if session.id != sessions.last?.id {
                            Divider()
                                .overlay(Color.soriBorder)
                        }
                    }
                }
            }
        }
    }

    private func sessionRow(_ session: PracticeSessionRecord) -> some View {
        HStack(spacing: SoriSpacing.sm) {
            Image(systemName: session.skill == "typing" ? "keyboard" : "text.book.closed")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.soriAccent)
                .frame(width: 34, height: 34)
                .background(Color.soriAccent.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(session.skillTitle)
                    .font(SoriFont.callout)
                    .foregroundStyle(Color.soriInk)
                Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(SoriFont.caption)
                    .foregroundStyle(Color.soriSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(session.cpmNet.rounded())) CPM")
                    .font(SoriFont.mono)
                    .foregroundStyle(Color.soriInk)
                Text("\(session.sentences) sentences · \(Int(session.durationSeconds.rounded())) s")
                    .font(SoriFont.caption)
                    .foregroundStyle(Color.soriSecondary)
            }
        }
        .padding(.vertical, SoriSpacing.xs)
    }

    private func loadRecentSessions() async {
        sessions = (try? await env.practice.recentSessions(limit: 5)) ?? []
    }

    private func startSession(_ requestedMode: PracticeMode) async {
        switch requestedMode {
        case .reading:
            await startReading()
        case .typing:
            await startTyping()
        }
    }

    private func startReading() async {
        guard mode == .reading, !isPreparingReading, !showingReadingSession else { return }
        isPreparingReading = true
        defer { isPreparingReading = false }

        do {
            let candidates = try await env.library.randomSentences(limit: 400)
            let presentable = candidates.filter { PracticeText.isPresentable($0.text) }
            guard !presentable.isEmpty else {
                alertMessage = "The library does not have any complete sentences yet. Add Korean text in Library first."
                return
            }
            readingSentences = Array(presentable.prefix(120))
            showingReadingSession = true
        } catch {
            alertMessage = "Could not prepare sentences. \(error.localizedDescription)"
        }
    }

    private func startTyping() async {
        guard mode == .typing, !isPreparingTyping, !showingTypingSession else { return }
        isPreparingTyping = true
        defer { isPreparingTyping = false }

        do {
            let candidates = try await env.library.randomSentences(limit: 500)
            let typeable = candidates.filter {
                $0.text.count <= 160 && TypingText.isTypeable($0.text)
            }
            guard !typeable.isEmpty else {
                alertMessage = "No typeable Korean sentences were found. Try importing a modern Korean text."
                return
            }
            typingSentences = Array(typeable.prefix(120))
            showingTypingSession = true
        } catch {
            alertMessage = "Could not prepare sentences. \(error.localizedDescription)"
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
