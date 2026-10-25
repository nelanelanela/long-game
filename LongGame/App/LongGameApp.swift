import SwiftUI
import SwiftData

@main
struct LongGameApp: App {
    let container: ModelContainer
    @State private var timerStore = TimerStore()
    @State private var account = AccountStore()

    init() {
        let schema = Schema([Craft.self, YearEstimate.self, Session.self, AppSettings.self])
        do {
            container = try ModelContainer(for: schema, configurations: CloudSync.configuration(for: schema))
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
                .environment(account)
                .task { await account.refreshState() }
                .preferredColorScheme(.light)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
        .modelContainer(container)
    }
}
