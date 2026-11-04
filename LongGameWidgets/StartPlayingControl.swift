import AppIntents
import SwiftUI
import WidgetKit

/// A "Start playing" button for Control Center, the Lock Screen and the Action button (iOS 18 and later).
@available(iOS 18.0, *)
struct StartPlayingControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "app.longgame.startPlaying") {
            ControlWidgetButton(action: StartPlayingIntent()) {
                Label("Start playing", systemImage: "sun.max.fill")
            }
        }
        .displayName("Start playing")
        .description("Starts a session for your craft.")
    }
}
