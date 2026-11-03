import Testing
import Foundation
import SwiftData
@testable import LongGame

struct StoreLocationTests {
    /// With an App Group in the entitlements, SwiftData's default would move the database into the group's folder and
    /// everyone's saved data would be left behind in the old place. The app is told to keep it where it always was.
    @Test func theDatabaseStaysInTheAppsOwnFolderEvenWithAnAppGroup() {
        let schema = Schema([Craft.self, YearEstimate.self, Session.self, AppSettings.self, TargetPeriod.self])
        let config = CloudSync.configuration(for: schema)
        #expect(!config.url.path.contains("/AppGroup/"))
        #expect(config.url.path.contains("/Application Support/"))
        #expect(config.url.lastPathComponent == "default.store")
    }
}
