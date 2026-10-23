import SwiftUI

enum AppTab: String, Hashable, CaseIterable {
    case learn
    case practice
    case speak
    case progress
    case settings

    static var initialForLaunch: AppTab {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "--tab"),
           arguments.indices.contains(index + 1),
           let tab = AppTab(rawValue: arguments[index + 1]) {
            return tab
        }
        #endif
        return .learn
    }
}

struct RootTabView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.scenePhase) private var scenePhase

    @State private var selection: AppTab
    @State private var splash = SplashCoordinator()

    init() {
        _selection = State(initialValue: AppTab.initialForLaunch)
    }

    var body: some View {
        root
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 0) {
                    if let error = env.startupError {
                        StartupErrorBanner(message: error)
                    }
                    if env.isSeedingLibrary {
                        LibrarySeedBanner()
                    }
                }
            }
            .overlay {
                if splash.isPresented {
                    DailySplashView(
                        stats: splash.stats,
                        autoCloseSeconds: env.settings.splashAutoCloseSeconds,
                        onClose: { splash.dismiss() }
                    )
                    .transition(.opacity)
                    .zIndex(10)
                }
            }
            .animation(.easeInOut(duration: 0.22), value: splash.isPresented)
            .task {
                await env.prepareAtLaunch()
            }
            .task {
                await splash.handleBecameActive(
                    settings: env.settings,
                    database: env.database
                )
            }
            .onAppear {
                env.usage.start(tab: selection)
            }
            .onChange(of: selection) { _, tab in
                guard scenePhase == .active else { return }
                env.usage.start(tab: tab)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    env.usage.start(tab: selection)
                } else {
                    env.usage.stop()
                }

                guard phase == .active else { return }
                Task {
                    await splash.handleBecameActive(
                        settings: env.settings,
                        database: env.database
                    )
                    await env.prepareReview()
                    await env.backup.automaticBackupIfNeeded()
                }
            }
    }

    @ViewBuilder
    private var root: some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--library") {
            NavigationStack {
                LibraryView()
            }
        } else if ProcessInfo.processInfo.arguments.contains("--sources") {
            NavigationStack {
                SourcesSettingsView()
            }
        } else if ProcessInfo.processInfo.arguments.contains("--backups") {
            NavigationStack {
                BackupsView()
            }
        } else {
            tabs
        }
        #else
        tabs
        #endif
    }

    private var tabs: some View {
        TabView(selection: $selection) {
            Tab("Learn", systemImage: "book.closed", value: AppTab.learn) {
                LearnView()
            }
            Tab("Practice", systemImage: "keyboard", value: AppTab.practice) {
                PracticeView()
            }
            Tab("Speak", systemImage: "waveform", value: AppTab.speak) {
                SpeakView()
            }
            Tab("Progress", systemImage: "chart.xyaxis.line", value: AppTab.progress) {
                ProgressDashboardView()
            }
            Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
                SettingsView()
            }
        }
    }
}

private struct StartupErrorBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: SoriSpacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.soriWarning)
            Text(message)
                .font(SoriFont.caption)
                .foregroundStyle(Color.soriInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(SoriSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.soriWarning.opacity(0.14))
    }
}

private struct LibrarySeedBanner: View {
    var body: some View {
        HStack(spacing: SoriSpacing.xs) {
            ProgressView()
                .controlSize(.small)
            Text("Preparing your starter library…")
                .font(SoriFont.caption)
                .foregroundStyle(Color.soriInk)
            Spacer(minLength: 0)
        }
        .padding(SoriSpacing.sm)
        .background(Color.soriSurface)
    }
}
