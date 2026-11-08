import Foundation
import CoreGraphics

// The session picture (update prompt 32, part 8): a small abstract sunrise for a session without a photo, drawn
// from the session itself. Nothing is stored as an image; these pure functions work out everything from a few numbers
// so the same session draws the same picture on every device, today and years later. Numbers are from
// design/redesign/SessionArt.dc.html.

/// The light of the day the session started in.
enum SessionDaypart: String, CaseIterable, Sendable {
    case night, morning, midday, afternoon, evening

    /// Night is before 5:30 or from 21:30, morning before 10, midday before 14:30, afternoon before 18, then evening.
    static func at(startHour: Double) -> SessionDaypart {
        if startHour < 5.5 || startHour >= 21.5 { return .night }
        if startHour < 10 { return .morning }
        if startHour < 14.5 { return .midday }
        if startHour < 18 { return .afternoon }
        return .evening
    }

    /// The word VoiceOver says.
    var word: String { rawValue }
}

/// One daypart's colours.
struct SessionPalette: Equatable, Sendable {
    var sky1: UInt32, sky2: UInt32
    var sun1: UInt32, sun2: UInt32
    var back: UInt32
    var dune1: UInt32, dune2: UInt32
    var line: UInt32
    var lineOpacity: Double
    /// The soft glow around the lines (night and evening mostly).
    var glowLineOpacity: Double
    var stars: Double
    var glow: Double

    static func of(_ part: SessionDaypart) -> SessionPalette {
        switch part {
        case .night:
            SessionPalette(sky1: 0x0E0C1C, sky2: 0x3A2116, sun1: 0xFFD58A, sun2: 0xE8862E, back: 0x2A1B22, dune1: 0x3A2418, dune2: 0x1A1210,
                           line: 0xFFC873, lineOpacity: 0.85, glowLineOpacity: 0.55, stars: 0.8, glow: 0.5)
        case .morning:
            SessionPalette(sky1: 0xFCF3D6, sky2: 0xF7E2B0, sun1: 0xFFE27A, sun2: 0xF5A93A, back: 0xF0D49A, dune1: 0xEBC27A, dune2: 0xE2AE5E,
                           line: 0xFFFFFF, lineOpacity: 0.9, glowLineOpacity: 0, stars: 0, glow: 0.45)
        case .midday:
            SessionPalette(sky1: 0xF9DD7C, sky2: 0xF3B845, sun1: 0xFFFBE6, sun2: 0xFFD86A, back: 0xEDB04A, dune1: 0xE9A23B, dune2: 0xDA8A2C,
                           line: 0xFFF6DA, lineOpacity: 0.85, glowLineOpacity: 0, stars: 0, glow: 0.6)
        case .afternoon:
            SessionPalette(sky1: 0xF6C860, sky2: 0xEC8A3A, sun1: 0xFFE9A8, sun2: 0xFFB04A, back: 0xE58A3A, dune1: 0xDC6E2E, dune2: 0xB9501F,
                           line: 0xFFE3B0, lineOpacity: 0.8, glowLineOpacity: 0.25, stars: 0, glow: 0.5)
        case .evening:
            SessionPalette(sky1: 0xD2602E, sky2: 0x4E2030, sun1: 0xFFC27A, sun2: 0xE8562A, back: 0x6A2A2E, dune1: 0x40192A, dune2: 0x1E0F18,
                           line: 0xFF9A5A, lineOpacity: 0.85, glowLineOpacity: 0.5, stars: 0.35, glow: 0.55)
        }
    }
}

enum SessionPictureSeed {
    /// A stable hash of the session's id, its start minute and its length in minutes (FNV-1a, so it never changes
    /// between launches, devices or iOS versions the way Swift's own `Hasher` does).
    static func make(id: UUID, startMinute: Int, minutes: Int) -> UInt32 {
        var h: UInt32 = 2_166_136_261
        func mix(_ byte: UInt8) { h = (h ^ UInt32(byte)) &* 16_777_619 }
        withUnsafeBytes(of: id.uuid) { $0.forEach(mix) }
        for value in [Int32(truncatingIfNeeded: startMinute), Int32(truncatingIfNeeded: minutes)] {
            withUnsafeBytes(of: value.littleEndian) { $0.forEach(mix) }
        }
        return h
    }

    /// The start of the session as minutes into its day (07:40 is 460).
    static func startMinute(of start: Date, calendar: Calendar = .current) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: start)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }
}

/// A small, fast, repeatable random stream (mulberry32).
struct SessionPictureRandom {
    private var a: UInt32
    init(seed: UInt32, startMinute: Int, minutes: Int) {
        a = seed &* 2_654_435_761 &+ UInt32(truncatingIfNeeded: startMinute) &* 40_503 &+ UInt32(truncatingIfNeeded: minutes) &* 97
    }
    mutating func next() -> Double {
        a = a &+ 0x6D2B79F5
        var t = a
        t = (t ^ (t >> 15)) &* (t | 1)
        t ^= t &+ ((t ^ (t >> 7)) &* (t | 61))
        return Double((t ^ (t >> 14))) / 4_294_967_296
    }
}

/// Everything needed to draw one picture, in a 240 × 240 design space.
struct SessionPictureLayout: Equatable, Sendable {
    var daypart: SessionDaypart
    var palette: SessionPalette
    var horizon: Double
    var sunX: Double
    var sunY: Double
    var sunRadius: Double
    var backDune: [CGPoint]
    var frontDune: [CGPoint]
    var lines: [[CGPoint]]
    var stars: [(x: Double, y: Double, r: Double)]

    static func == (l: SessionPictureLayout, r: SessionPictureLayout) -> Bool {
        l.daypart == r.daypart && l.horizon == r.horizon && l.sunX == r.sunX && l.sunY == r.sunY && l.sunRadius == r.sunRadius
            && l.backDune == r.backDune && l.frontDune == r.frontDune && l.lines == r.lines
            && l.stars.count == r.stars.count && zip(l.stars, r.stars).allSatisfy { $0.x == $1.x && $0.y == $1.y && $0.r == $1.r }
    }

    /// The number of fine lines: one for every five minutes, from 2 to 18.
    static func lineCount(minutes: Int) -> Int { max(2, min(18, Int((Double(minutes) / 5).rounded()))) }

    /// The sun's radius: bigger for a longer session, up to 150 minutes.
    static func sunRadius(minutes: Int) -> Double { 18 + Double(min(max(minutes, 1), 150)) / 150 * 34 }

    static func make(seed: UInt32, startMinute: Int, minutes rawMinutes: Int, progress rawProgress: Double) -> SessionPictureLayout {
        let minutes = max(1, rawMinutes)
        let progress = max(0, min(1, rawProgress))
        var random = SessionPictureRandom(seed: seed, startMinute: startMinute, minutes: minutes)
        let daypart = SessionDaypart.at(startHour: Double(startMinute) / 60)
        let palette = SessionPalette.of(daypart)

        let horizon = 150 + random.next() * 14
        let sunX = 60 + random.next() * 120
        let radius = sunRadius(minutes: minutes)
        let sunY = horizon + radius * 0.15 - progress * 90

        func wave(_ base: Double, _ amp: Double, _ phase: Double, _ freq: Double) -> [CGPoint] {
            var points = [CGPoint(x: -10, y: base + amp * sin(phase))]
            var x = 0.0
            while x <= 250 {
                let y = base + amp * sin(x / 240 * .pi * freq + phase) + amp * 0.35 * sin(x / 240 * .pi * freq * 2.3 + phase * 1.7)
                points.append(CGPoint(x: x, y: y))
                x += 10
            }
            return points
        }

        let ph1 = random.next() * 6.28, ph2 = random.next() * 6.28
        let f1 = 1.2 + random.next() * 1.2, f2 = 1 + random.next() * 1.4
        let backTop = wave(horizon, 7 + random.next() * 6, ph1, f1)
        let frontBase = horizon + 22 + random.next() * 10
        let frontAmp = 9 + random.next() * 9
        let frontTop = wave(frontBase, frontAmp, ph2, f2)
        let n = lineCount(minutes: minutes)
        var lines: [[CGPoint]] = []
        for i in 0..<n {
            let t = Double(i + 1) / Double(n + 1)
            lines.append(wave(frontBase + 4 + t * (232 - frontBase), frontAmp * (1 - t * 0.5), ph2 + t * 0.25, f2))
        }
        var stars: [(x: Double, y: Double, r: Double)] = []
        if palette.stars > 0 {
            for _ in 0..<14 {
                let x = random.next() * 240
                let y = random.next() * (horizon - 30)
                let r = random.next() < 0.2 ? 1.1 : 0.6
                stars.append((x, y, r))
            }
        }
        return SessionPictureLayout(daypart: daypart, palette: palette, horizon: horizon, sunX: sunX, sunY: sunY, sunRadius: radius,
                                    backDune: backTop, frontDune: frontTop, lines: lines, stars: stars)
    }
}

/// Where today's sunrise stood when a session ended (0 = on the horizon, 1 = fully up), worked out from the day's order
/// of sessions: the minutes played that day up to and including this one, over that day's stretch.
enum SessionSunrise {
    struct Entry: Equatable, Sendable {
        var id: UUID
        var start: Date
        var durationSec: Double
    }

    static func progressAtEnd(of id: UUID, among dayEntries: [Entry], target: TimeInterval?) -> Double {
        let ordered = dayEntries.sorted { ($0.start, $0.id.uuidString) < ($1.start, $1.id.uuidString) }
        var played = 0.0
        for entry in ordered {
            played += max(0, entry.durationSec)
            if entry.id == id { break }
        }
        return TimerSunrise.progress(doneSaved: played, running: 0, target: target)
    }
}
