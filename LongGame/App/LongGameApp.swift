import SwiftUI
import SwiftData

@main
struct LongGameApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([Craft.self, YearEstimate.self, Session.self, AppSettings.self])
        do {
            container = try ModelContainer(for: schema)
        } catch {
            fatalError("Could not open the local database: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            DesignGallery()
                .preferredColorScheme(.light)
        }
        .modelContainer(container)
    }
}
