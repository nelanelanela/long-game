import SwiftUI

// The tap-to-giggle layer: one controller per sun, a clock-free description of the running giggle, and the
// schedule that redraws the sun only while it giggles. The pose itself comes from `GiggleMotion` (Logic/).

/// One giggle that is running or has just run: what kind, and when it began.
struct GiggleRun: Equatable, Sendable {
    var id: Int
    var kind: GiggleKind
    var start: Date
    var reduceMotion: Bool
    /// Bounces added by taps during the laugh.
    var extraBounces = 0
    /// Goes up each time a tap extends the laugh, so the redrawing carries on; `id` stays, so haptics don't repeat.
    var revision = 0

    var token: Int { id * 100 + revision }
    var duration: TimeInterval { GiggleMotion.duration(of: kind, reduceMotion: reduceMotion, extraBounces: extraBounces) }
    var end: Date { start.addingTimeInterval(duration) }
    /// When the bouncing stops; a tap before this adds bounces, a tap after it starts a new laugh.
    var laughEnd: Date { start.addingTimeInterval(GiggleMotion.laughEnd(of: kind, extraBounces: extraBounces)) }

    func pose(at date: Date) -> GigglePose? {
        GiggleMotion.pose(at: date.timeIntervalSince(start), kind: kind, reduceMotion: reduceMotion, extraBounces: extraBounces)
    }
}

/// Redraws at the screen's pace from the giggle's first moment to its last, then stops. With no giggle it
/// gives a single entry, so a still sun costs nothing.
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

    /// Gets the sound ready ahead of the first tap, when the setting is on (in the background).
    func prepare(soundOn: Bool) async { await player.prepare(enabled: soundOn) }

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
        case .giggle:
            if var current = run, current.kind == .small, !current.reduceMotion, !reduceMotion, now < current.laughEnd,
               current.extraBounces == 0 {
                // Still laughing: two more bounces instead of starting over.
                current.extraBounces = min(GiggleMotion.extraPerTap, GiggleMotion.maxBounces - GiggleMotion.smallBounces)
                current.revision += 1
                run = current
            } else if let current = run, current.kind == .small, !current.reduceMotion, !reduceMotion, now < current.laughEnd {
                break   // already at the most bounces
            } else {
                start(.small, at: now, reduceMotion: reduceMotion)
            }
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
/// It uses the built-in animation schedule, switched on by each new tap and switched off when the giggle ends,
/// because a custom schedule is not reliably restarted when a second tap replaces the first giggle.
struct GigglingSun: View {
    var run: GiggleRun?
    var content: (GigglePose) -> SunView
    /// The token of the last giggle that has finished, so its redrawing can stop.
    @State private var finishedToken = 0

    private var isPaused: Bool {
        guard let run else { return true }
        return run.token == finishedToken
    }

    var body: some View {
        TimelineView(.animation(paused: isPaused)) { timeline in
            let pose = run?.pose(at: timeline.date) ?? .rest
            content(pose)
                .sensoryFeedback(trigger: (run?.id ?? 0) * 10 + pose.hapticStep) { _, key in
                    switch key % 10 {
                    case 1: .impact(flexibility: .soft)
                    case 2: .impact(weight: .light, intensity: 1.0)
                    case 3: .impact(weight: .light, intensity: 0.7)
                    case 4: .impact(weight: .light, intensity: 0.45)
                    default: nil
                    }
                }
        }
        .task(id: run?.token) {
            guard let run else { return }
            let wait = run.end.timeIntervalSinceNow + 0.05
            if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
            if !Task.isCancelled { finishedToken = run.token }
        }
    }
}
