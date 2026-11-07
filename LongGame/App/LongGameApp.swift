import SwiftUI
import SwiftData

@main
struct LongGameApp: App {
    @UIApplicationDelegateAdaptor(LongGameAppDelegate.self) private var appDelegate
    @State private var store: StoreHost
    @State private var timerStore = TimerStore()
    @State private var iCloud = ICloudMonitor()
    @State private var tips = TipStore()
    @State private var commands = CommandCenter()

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
            DebugWindowSize { AppRoot() }
                .modelContainer(store.container)
                .environment(store)
                .environment(timerStore)
                .environment(iCloud)
                .environment(tips)
                .environment(commands)
                .task(id: store.generation) { tips.start(context: store.container.mainContext) }
                .task { await iCloud.refresh(); iCloud.start() }
                // The Apple Watch follows the timer and the stored data from here on.
                .task(id: store.generation) { WatchBridge.shared.start(timer: timerStore, container: store.container) }
                .preferredColorScheme(.light)
                .dynamicTypeSize(...DynamicTypeSize.accessibility5)
        }
        // Hold ⌘ on an iPad with a keyboard to see these.
        .commands { LongGameCommands(center: commands) }
    }
}

/// Simulator helper (debug builds): `-debug.windowSize 1194x834` lays the app out as if its window were that size,
/// to check an iPad layout without rotating or resizing the Simulator. Does nothing without the argument.
private struct DebugWindowSize<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let at = args.firstIndex(of: "-debug.windowSize"), args.indices.contains(at + 1) {
            let parts = args[at + 1].split(separator: "x").compactMap { Double($0) }
            if parts.count == 2 {
                // Laid out at that size, then shrunk to fit the Simulator's screen.
                GeometryReader { screen in
                    let k = min(1, screen.size.width / parts[0], screen.size.height / parts[1])
                    content.frame(width: parts[0], height: parts[1])
                        .scaleEffect(k, anchor: .topLeading)
                        .frame(width: screen.size.width, height: screen.size.height, alignment: .topLeading)
                }
            } else { content }
        } else { content }
        #else
        content
        #endif
    }
}
