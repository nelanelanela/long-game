import SwiftUI
import SwiftData
import UIKit

/// Changes the home-screen icon with `setAlternateIconName`. iOS shows its own "You have changed the icon" alert,
/// so callers only use this after a celebration is dismissed, or quietly on launch / return to the foreground.
@MainActor
enum AppIconManager {
    /// Sets the icon to `stage` if the rules in `IconPlan.shouldCall` allow it, and remembers it in Settings.
    static func apply(_ stage: IconStage, settings: AppSettings, context: ModelContext, timerRunning: Bool) {
        let app = UIApplication.shared
        guard IconPlan.shouldCall(wanted: stage, currentIconName: app.alternateIconName,
                                  appActive: app.applicationState == .active,
                                  supportsAlternateIcons: app.supportsAlternateIcons,
                                  timerRunning: timerRunning) else {
            // Already showing the right icon: just keep the record in step.
            if app.alternateIconName == stage.alternateIconName, settings.appliedIconStage != stage {
                settings.appliedIconStage = stage
                try? context.save()
            }
            return
        }
        Task {
            do {
                try await app.setAlternateIconName(stage.alternateIconName)
                settings.appliedIconStage = stage
                try? context.save()
            } catch {
                // The system said no (for example the icon is not in the build). Nothing else to do.
            }
        }
    }
}
