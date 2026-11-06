import SwiftUI
import SwiftData
import AppKit

/// "App icon grows with you" on the Mac: the Dock icon is set to the current stage with `NSApp.applicationIconImage`.
/// (The iPhone swaps alternate app icons; the Mac cannot, so it draws the stage itself.)
@MainActor
enum AppIconManager {
    /// Sets the Dock icon to `stage` and remembers it in Settings. Same signature as the iPhone's, so shared screens call it.
    static func apply(_ stage: IconStage, settings: AppSettings, context: ModelContext, timerRunning: Bool) {
        setDockIcon(stage)
        if settings.appliedIconStage != stage {
            settings.appliedIconStage = stage
            try? context.save()
        }
    }

    static func setDockIcon(_ stage: IconStage) {
        // Stage 0 is the plain app icon from the asset catalog.
        guard stage != .start else { NSApp.applicationIconImage = nil; return }
        let renderer = ImageRenderer(content: IconStageView(stage: stage))
        renderer.scale = 0.5   // the artwork is drawn on a 1,024 pt canvas
        if let image = renderer.nsImage { NSApp.applicationIconImage = image }
    }
}
