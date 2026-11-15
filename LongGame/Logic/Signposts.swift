import os

/// Named markers for Instruments (docs/PERFORMANCE_PLAN.md). Each `measure` shows as a labelled bar on the
/// "Points of Interest" track of any recording, so a slow moment can be matched to the app's own words.
/// When Instruments isn't recording, a marker costs next to nothing.
enum Signposts {
    static let poster = OSSignposter(subsystem: "com.wehavesun.LongGame", category: .pointsOfInterest)

    /// Runs `work` inside a named interval, e.g. `Signposts.measure("Home summary") { ... }`.
    @inline(__always)
    static func measure<T>(_ name: StaticString, _ work: () throws -> T) rethrows -> T {
        let state = poster.beginInterval(name)
        defer { poster.endInterval(name, state) }
        return try work()
    }

    /// A single moment (no length), e.g. "Widget publish".
    @inline(__always)
    static func event(_ name: StaticString) {
        poster.emitEvent(name)
    }
}
