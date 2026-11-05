import SwiftUI

// The tap-to-giggle layer: one controller per sun, a clock-free description of the running giggle, and the
// schedule that redraws the sun only while it giggles. The pose itself comes from `GiggleMotion` (Logic/).

/// One giggle that is running or has just run: what kind, and when it began.
struct GiggleRun: Equatable, Sendable {
    var id: Int
    var kind: GiggleKind
    var start: Date
    var reduceMotion: Bool

    var duration: TimeInterval { GiggleMotion.duration(of: kind, reduceMotion: reduceMotion) }
    var end: Date { start.addingTimeInterval(duration) }

    func pose(at date: Date) -> GigglePose? {
        GiggleMotion.pose(at: date.timeIntervalSince(start), kind: kind, reduceMotion: reduceMotion)
    }
}

/// Redraws at the screen's pace from the giggle's first moment to its last, then stops. With no giggle it
/// gives a single entry, so a resting sun costs nothing.
struct GiggleSchedule: TimelineSchedule {
    var run: GiggleRun?

    func entries(from startDate: Date, mode: Mode) -> [Date] {
        guard let run, startDate < run.end else { return [startDate] }
        var dates: [Date] = []
        var d = max(startDate, run.start)
        while d < run.end {
            dates.append(d)
            d.addTimeInterval(1.0 / 60)
        }
        dates.append(run.end)
        return dates
    }
}

/// Owns one sun's tap rules and its running giggle.
@MainActor
@Observable
final class GiggleController {
    private(set) var run: GiggleRun?
    private var taps = GiggleTaps()
    private var counter = 0
    @ObservationIgnored private let player: GiggleSoundPlayer

    init(player: GiggleSoundPlayer = .shared) { self.player = player }

    /// Gets the sound ready ahead of the first tap, when the setting is on.
    func prepare(soundOn: Bool) { player.prepare(enabled: soundOn) }

    /// A tap on the sun. `winkOnly` is the Timer: a soft wink, never sound or wiggle.
    func tap(soundOn: Bool, reduceMotion: Bool, winkOnly: Bool = false, now: Date = .now) {
        if winkOnly {
            start(.wink, at: now, reduceMotion: reduceMotion)
            return
        }
        let response = taps.tap(at: now, soundAllowed: soundOn)
        switch response.action {
        case .ignore: return
        case .wink: start(.wink, at: now, reduceMotion: reduceMotion)
        case .giggle: start(.small, at: now, reduceMotion: reduceMotion)
        case .bigLaugh: start(.big, at: now, reduceMotion: reduceMotion)
        }
        if response.playsSound, let length = player.play(big: response.action == .bigLaugh, enabled: soundOn) {
            taps.soundStarted(at: now, length: length)
        }
    }

    private func start(_ kind: GiggleKind, at now: Date, reduceMotion: Bool) {
        counter += 1
        run = GiggleRun(id: counter, kind: kind, start: now, reduceMotion: reduceMotion)
    }
}

// MARK: Settings

private struct GiggleSoundOnKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// Settings → Sounds → Giggle sound. On unless the person turned it off.
    var giggleSoundOn: Bool {
        get { self[GiggleSoundOnKey.self] }
        set { self[GiggleSoundOnKey.self] = newValue }
    }
}

// MARK: The sun with a giggle

/// The sun drawn through a running giggle: redrawn only while it lasts, with the three haptics.
struct GigglingSun: View {
    var run: GiggleRun?
    var content: (GigglePose) -> SunView

    var body: some View {
        TimelineView(GiggleSchedule(run: run)) { timeline in
            let pose = run?.pose(at: timeline.date) ?? .rest
            content(pose)
                .sensoryFeedback(trigger: (run?.id ?? 0) * 10 + pose.hapticStep) { _, key in
                    switch key % 10 {
                    case 1: .impact(flexibility: .soft)
                    case 2, 3: .impact(weight: .light)
                    default: nil
                    }
                }
        }
    }
}
