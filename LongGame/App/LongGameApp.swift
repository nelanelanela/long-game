import SwiftUI
import SwiftData

@main
struct LongGameApp: App {
    let container: ModelContainer
    @State private var timerStore = TimerStore()

    init() {
        let schema = Schema([Craft.self, YearEstimate.self, Session.self, AppSettings.self])
        do {
            container = try ModelContainer(for: schema)
            #if DEBUG
            DemoData.seedIfRequested(ModelContext(container))
            #endif
        } catch {
            fatalError("Could not open the local database: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            AppRoot()
                .environment(timerStore)
                .preferredColorScheme(.light)
        }
        .modelContainer(container)
    }
}
