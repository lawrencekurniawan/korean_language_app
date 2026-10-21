import SwiftUI

@main
struct SoriApp: App {
    @State private var environment: AppEnvironment

    init() {
        _environment = State(initialValue: AppEnvironment.live())
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(environment)
                .preferredColorScheme(environment.settings.appearance.colorScheme)
                .tint(.soriAccent)
        }
    }
}
