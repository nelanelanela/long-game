import Foundation

/// The words of the Mac menu bar sun: what sits beside the icon and the lines in its popover.
/// Pure functions of the stored timestamps and saved sessions, so they are always derived, never counted.
enum MenuBarText {
    /// Beside the sun: the running clock ("25:18", "1:02:03") while a session exists, otherwise the time played
    /// today ("1 h 05", "40 m"). A paused session shows its frozen clock.
    static func title(timer: TimerState?, savedToday: TimeInterval, now: Date) -> String {
        if let timer { return DurationFormat.clock(seconds: timer.elapsed(at: now)) }
        return StretchText.clock(seconds: savedToday)
    }

    /// While a session runs the clock ticks every second; otherwise the label only changes with the minute.
    static func ticksEverySecond(timer: TimerState?) -> Bool { timer != nil }

    /// "1 h 30 of 1 h 45 · 15 m to go" (running popover and the title of today's arc); covered, "· done" or
    /// "· 25 m extra".
    static func todayLine(_ stretch: StretchState) -> String {
        switch stretch {
        case .inProgress(let target, let done):
            "\(StretchText.clock(seconds: done)) of \(StretchText.clock(seconds: target)) · \(StretchText.toGo(target - done))"
        case .covered(let target, let done):
            "\(StretchText.clock(seconds: done)) of \(StretchText.clock(seconds: target)) · \(coveredTail(target: target, done: done))"
        case .noTarget:
            ""
        }
    }

    /// The big time of the idle popover: "1 h 05".
    static func bigTime(_ stretch: StretchState) -> String { StretchText.clock(seconds: stretch.done) }

    /// Under the big time: "of today's 1 h 45 · 40 m to go", or "today's 1 h 45 · done" ("· 25 m extra" when over).
    static func idleCaption(_ stretch: StretchState) -> String {
        switch stretch {
        case .inProgress(let target, let done):
            "\(StretchText.ofToday(target)) · \(StretchText.toGo(target - done))"
        case .covered(let target, let done):
            String(localized: "today's \(StretchText.clock(seconds: target))") + " · " + coveredTail(target: target, done: done)
        case .noTarget:
            String(localized: "played today")
        }
    }

    /// "done", or "25 m extra" when a minute or more over.
    private static func coveredTail(target: TimeInterval, done: TimeInterval) -> String {
        let extra = StretchText.extraMinutes(target: target, done: done)
        return extra > 0 ? String(localized: "\(StretchText.clock(seconds: TimeInterval(extra * 60))) extra") : String(localized: "done")
    }

    /// "Next ray in 2:42" for the running card, from the same sun rule as the Timer.
    static func nextRay(timer: TimerState, now: Date) -> String {
        SunHour(elapsed: timer.elapsed(at: now)).caption
    }

    /// What VoiceOver reads for the menu bar item.
    static func accessibilityLabel(timer: TimerState?, savedToday: TimeInterval, now: Date) -> String {
        if let timer {
            let spoken = Labels.spoken(seconds: Int(timer.elapsed(at: now)), includeSeconds: true)
            return timer.isPaused(at: now)
                ? String(localized: "Long Game, session paused at \(spoken)")
                : String(localized: "Long Game, session running, \(spoken)")
        }
        return String(localized: "Long Game, \(StretchText.spoken(seconds: savedToday)) played today")
    }

    /// "Pause" or "Resume" for the popover's main button.
    static func pauseTitle(timer: TimerState, now: Date) -> String {
        timer.isPaused(at: now) ? String(localized: "Resume") : String(localized: "Pause")
    }
}

/// Whether the Dock shows the app. The accessory policy leaves only the menu bar sun.
enum DockVisibility {
    static let defaultsKey = "mac.showInDock"

    /// On unless turned off.
    static func isShown(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: defaultsKey) as? Bool ?? true
    }
}
