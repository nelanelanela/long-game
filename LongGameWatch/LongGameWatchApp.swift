import SwiftUI

@main
struct LongGameWatchApp: App {
    @State private var store = WatchStore()

    var body: some Scene {
        WindowGroup {
            WatchRoot()
                .environment(store)
                .preferredColorScheme(.dark)
        }
    }
}
