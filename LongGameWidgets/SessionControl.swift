import AppIntents
import SwiftUI
import WidgetKit

/// "Long Game" in Control Centre and on the Lock Screen (iOS 18 and later): one toggle.
/// - Idle: the sun and "Begin". A tap begins a session (and its Live Activity).
/// - Playing: the craft's name and the running clock, tinted gold. A tap pauses; a tap again resumes.
/// With no craft set up yet, a tap opens the app. Finishing stays on the Live Activity and in the app.
@available(iOS 18.0, *)
struct SessionControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: SessionControlKind.kind, provider: SessionControlProvider()) { value in
            ControlWidgetToggle(isOn: value.playing, action: SessionControlIntent()) {
                Text(verbatim: value.title)
            } valueLabel: { isOn in
                if let start = value.clockStart {
                    // Counts on its own from the timestamps; frozen while paused.
                    if let pausedElapsed = value.pausedElapsed {
                        Label(String(localized: "Paused · \(DurationFormat.clock(seconds: pausedElapsed))"), systemImage: "sun.max")
                    } else {
                        Label {
                            Text(timerInterval: start...start.addingTimeInterval(TimerState.autoPauseAfter), countsDown: false)
                        } icon: {
                            Image(systemName: "sun.max.fill")
                        }
                    }
                } else {
                    Label("Begin", systemImage: "sun.max.fill")
                }
            }
            .tint(LGColor.timerGold)
        }
        .displayName("Long Game")
        .description("Begin a session, or pause the one that's running.")
    }
}

@available(iOS 18.0, *)
struct SessionControlValue: Sendable {
    var playing: Bool
    /// The craft while a session runs, "Long Game" otherwise.
    var title: String
    /// "now − elapsed" while a session exists, so the clock can count.
    var clockStart: Date?
    var pausedElapsed: TimeInterval?
}

@available(iOS 18.0, *)
struct SessionControlProvider: ControlValueProvider {
    var previewValue: SessionControlValue { SessionControlValue(playing: false, title: "Long Game") }

    func currentValue() async throws -> SessionControlValue {
        let now = Date()
        guard let state = TimerPersistence.load() else {
            return SessionControlValue(playing: false, title: String(localized: "Long Game"))
        }
        let elapsed = state.elapsed(at: now)
        let paused = state.isPaused(at: now)
        return SessionControlValue(playing: !paused, title: state.craftName,
                                   clockStart: now.addingTimeInterval(-elapsed), pausedElapsed: paused ? elapsed : nil)
    }
}
