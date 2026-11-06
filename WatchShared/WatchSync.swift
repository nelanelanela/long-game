import Foundation

// What the iPhone and the Apple Watch send each other, and how the watch works out what to show.
//
// One session at a time across both: the running timer is just timestamps (`TimerState`), copied to the other device
// whenever it changes, the newest change winning. A session finished on the watch travels to the phone as a
// `FinishedSession` and is saved there, once (its id is the session's id). The phone sends the watch its stored data
// (`WidgetSnapshot`), and the watch works out the same numbers the phone does.

/// The running timer (or none) and when it last changed, so the newest change wins on both devices.
struct TimerUpdate: Codable, Equatable, Sendable {
    var state: TimerState?
    var changedAt: Date

    /// True when this change is newer than the one a device already has.
    func supersedes(_ lastChangeAt: Date) -> Bool { changedAt > lastChangeAt }
}

/// A session the watch finished. The phone saves it with the same id, so it is never saved twice.
struct FinishedSession: Codable, Equatable, Sendable, Identifiable {
    var id: UUID
    var craftId: UUID
    var start: Date
    var durationSec: Double

    var entry: WidgetSnapshot.Entry { .init(start: start, seconds: durationSec, id: id) }
}

/// Keys and coding for WatchConnectivity messages (property lists, so each value is JSON `Data`).
enum WatchMessage {
    static let timerKey = "timer"
    static let sessionKey = "session"
    /// A file transfer carrying the phone's stored data (the metadata names its kind).
    static let snapshotKind = "snapshot"
    static let kindKey = "kind"
    /// Sent instead of a file when the phone has no craft any more.
    static let snapshotClearedKey = "snapshotCleared"

    private static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .secondsSince1970
        return e
    }

    private static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .secondsSince1970
        return d
    }

    static func timerPayload(_ update: TimerUpdate) -> [String: Any] {
        (try? encoder.encode(update)).map { [timerKey: $0] } ?? [:]
    }

    static func timerUpdate(from payload: [String: Any]) -> TimerUpdate? {
        guard let data = payload[timerKey] as? Data else { return nil }
        return try? decoder.decode(TimerUpdate.self, from: data)
    }

    static func sessionPayload(_ session: FinishedSession) -> [String: Any] {
        (try? encoder.encode(session)).map { [sessionKey: $0] } ?? [:]
    }

    static func finishedSession(from payload: [String: Any]) -> FinishedSession? {
        guard let data = payload[sessionKey] as? Data else { return nil }
        return try? decoder.decode(FinishedSession.self, from: data)
    }
}

/// Sessions finished on the watch that the phone has not shown up in its data yet. They still count on the watch.
enum PendingSessions {
    static let fileName = "watch-pending.json"
    /// Anything older than this that the phone never confirmed is dropped, so a lost session can't linger.
    static let expiry: TimeInterval = 30 * 86_400

    static func load() -> [FinishedSession] {
        guard let url = WidgetSnapshot.fileURL(fileName), let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return (try? decoder.decode([FinishedSession].self, from: data)) ?? []
    }

    static func store(_ sessions: [FinishedSession]) {
        guard let url = WidgetSnapshot.fileURL(fileName) else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        if let data = try? encoder.encode(sessions) { try? data.write(to: url, options: .atomic) }
    }

    /// What is still waiting for the phone: not yet in its data, and not expired.
    static func outstanding(_ pending: [FinishedSession], snapshot: WidgetSnapshot?, now: Date) -> [FinishedSession] {
        let known = Set((snapshot?.sessions ?? []).compactMap(\.id))
        return pending.filter { !known.contains($0.id) && now.timeIntervalSince($0.start) < expiry }
    }
}

/// What the watch shows, from the phone's data plus the sessions still on their way to it.
struct WatchHomeState: Equatable, Sendable {
    var widget: WidgetState
    var craftId: UUID?
    /// "3 days left" on the This week page.
    var daysLeftText: String
    /// "~2036" on The long game page.
    var finish: String

    var weekCaption: String { "of \(DurationFormat.hours(widget.weekTarget)) · \(daysLeftText)" }
    var longGameCaption: String { "\(widget.longGamePercent)% · finish \(finish)" }
}

enum WatchModel {
    /// The snapshot with the pending sessions added (those it doesn't already hold).
    static func merged(_ snapshot: WidgetSnapshot, pending: [FinishedSession]) -> WidgetSnapshot {
        var copy = snapshot
        let known = Set(snapshot.sessions.compactMap(\.id))
        copy.sessions += pending.filter { !known.contains($0.id) }.map(\.entry)
        return copy
    }

    static func state(snapshot: WidgetSnapshot, pending: [FinishedSession] = [], now: Date,
                      calendar: Calendar = .current) -> WatchHomeState {
        let merged = merged(snapshot, pending: pending)
        let widget = WidgetModel.make(merged, at: now, calendar: calendar)
        let weekStart = WeekStart(rawValue: merged.weekStart) ?? .monday
        let summary = ProgressSummary.make(
            estimates: merged.estimates.map { YearRate(year: $0.year, hoursPerWeek: $0.hoursPerWeek) },
            sessions: WidgetModel.records(merged), onboardingDate: merged.onboardingDate, weekStart: weekStart, now: now,
            target: merged.target.map { TargetRecord(hoursPerWeek: $0.hoursPerWeek, start: $0.start, end: $0.end) },
            calendar: calendar)
        let week = WeekTarget.make(hoursThisWeek: widget.weekHours, target: widget.weekTarget, now: now,
                                   weekStart: weekStart, calendar: calendar)
        return WatchHomeState(widget: widget, craftId: merged.craftId, daysLeftText: week.daysLeftText,
                              finish: ForecastText.homeMastery(summary.forecast.chosen, now: now, calendar: calendar))
    }

    /// The timer screen's numbers: the clock, the overall total with the session counted in, and the next ray.
    static func timerLine(baseTotal: Double, elapsed: TimeInterval) -> String {
        let sun = SunHour(elapsed: elapsed)
        return "\(DurationFormat.totalHours(baseTotal + elapsed / 3600)) h · next ray \(DurationFormat.minutesSeconds(seconds: sun.secondsToNextRay))"
    }

    /// The Finished screen: "+42 m" and "7.2 of 12 h this week".
    static func addedText(_ session: FinishedSession) -> String { "+" + DurationFormat.short(seconds: session.durationSec) }

    static func finishedCaption(_ state: WatchHomeState) -> String {
        "\(WeeklyTarget.number(state.widget.weekHours)) of \(WeeklyTarget.number(state.widget.weekTarget)) h this week"
    }
}
