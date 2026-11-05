import SwiftUI
import SwiftData

@main
struct LongGameApp: App {
    @State private var store: StoreHost
    @State private var timerStore = TimerStore()
    @State private var iCloud = ICloudMonitor()
    @State private var tips = TipStore()

    init() {
        do {
            let host = try StoreHost()
            #if DEBUG
            DemoData.seedIfRequested(ModelContext(host.container))
            #endif
            _store = State(initialValue: host)
        } catch {
            fatalError("Could not open the local database: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            AppRoot()
                .modelContainer(store.container)
                .environment(store)
                .environment(timerStore)
                .environment(iCloud)
                .environment(tips)
                .task(id: store.generation) { tips.start(context: store.container.mainContext) }
                .task { await iCloud.refresh(); iCloud.start() }
                // The Apple Watch follows the timer and the stored data from here on.
                .task(id: store.generation) { WatchBridge.shared.start(timer: timerStore, container: store.container) }
                .preferredColorScheme(.light)
                .dynamicTypeSize(...DynamicTypeSize.accessibility5)
        }
    }
}
