import SwiftUI
import SwiftData
import UIKit

/// The full-screen timer: the sun's hour. Everything on screen is derived from
/// the stored timestamps and the clock; nothing is counted in memory.
struct TimerView: View {
    let craft: Craft

    @Environment(TimerStore.self) private var store
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    @State private var showFinish = false
    @State private var savedAt: Date?

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 1.0 / 30)) { timeline in
            if let savedAt {
                SavedScene(now: timeline.date, since: savedAt)
            } else if let state = store.state {
                RunningScene(
                    now: timeline.date, state: state, craftName: craft.name, reduceMotion: reduceMotion,
                    onMinimise: { dismiss() },
                    onToggle: { store.togglePause() },
                    onFinish: {
                        store.pause()
                        showFinish = true
                    })
            } else {
                Color.black.ignoresSafeArea()
            }
        }
        .preferredColorScheme(.dark)
        .sensoryFeedback(.success, trigger: savedAt)
        .sheet(isPresented: $showFinish) {
            if let state = store.state {
                FinishSheet(elapsed: state.elapsed(at: Date()), onSave: save, onDiscard: discard)
            }
        }
        .onChange(of: store.state == nil) { _, gone in
            if gone && savedAt == nil { dismiss() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.refresh() }
        }
        .onChange(of: store.finishRequested) { _, requested in
            if requested { openFinishFromActivity() }
        }
        .task(id: savedAt) {
            guard savedAt != nil else { return }
            try? await Task.sleep(for: .seconds(1.4))
            dismiss()
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            if store.finishRequested { openFinishFromActivity() }
        }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    private func openFinishFromActivity() {
        store.finishRequested = false
        showFinish = true
    }

    private func save(duration: TimeInterval, note: String?) {
        guard let state = store.state else { return }
        context.insert(Session(craftId: state.craftId, start: state.startedAt, durationSec: duration, source: .timer, note: note))
        try? context.save()
        store.savedSession = true
        showFinish = false
        savedAt = Date()
        store.clear()
    }

    private func discard() {
        showFinish = false
        store.clear()
        dismiss()
    }
}

// MARK: - Running

private struct RunningScene: View {
    let now: Date
    let state: TimerState
    let craftName: String
    let reduceMotion: Bool
    let onMinimise: () -> Void
    let onToggle: () -> Void
    let onFinish: () -> Void

    private static let motes: [(x: Double, y: Double, delay: Double, size: CGFloat)] = [
        (150, 330, 0, 6), (228, 340, 1.7, 4), (192, 350, 3.1, 6), (260, 300, 4.2, 4),
    ]

    var body: some View {
        let elapsed = state.elapsed(at: now)
        let paused = state.isPaused(at: now)
        let sun = SunHour(elapsed: elapsed)
        let golden = paused ? nil : sun.goldenProgress()
        let t = now.timeIntervalSinceReferenceDate

        let breath = reduceMotion ? 0 : (1 - cos(2 * .pi * t / (paused ? 8 : 4))) / 2
        let hop = golden.map { -sin($0 * .pi) * 34 } ?? 0
        let winking = !paused && golden == nil && t.truncatingRemainder(dividingBy: 9) > 8.5
        let face: SunFace = golden != nil ? .celebrate : paused ? .sleepy : winking ? .wink : .focus

        let growing = (paused || golden != nil) ? nil : sun.rayGrowProgress()
        let spin: Double = {
            if reduceMotion { return 0 }
            let hours = Double(sun.hoursCompleted)
            let extra = golden.map { 30 * (hours - 1) + 30 * Self.smooth($0) } ?? 30 * hours
            return elapsed / 120 * 360 + extra
        }()
        let glow = reduceMotion ? 0.6 : 0.35 + 0.65 * (1 - cos(2 * .pi * t / 1.6)) / 2
        let warmth: Double = {
            if reduceMotion { return 0.35 }
            guard let g = golden else { return sun.hourFraction }
            return 1 + (sun.hourFraction - 1) * Self.smooth(g)
        }()

        GeometryReader { geo in
            let centre = CGPoint(x: geo.size.width / 2, y: geo.size.height * 0.32)
            ZStack {
                TimerSky(warmth: warmth, paused: paused)

                Circle()
                    .fill(RadialGradient(colors: [LGColor.sunBody.opacity(0.32), LGColor.sunBody.opacity(0)],
                                         center: .center, startRadius: 0, endRadius: 150))
                    .frame(width: 300, height: 300)
                    .scaleEffect(1 + 0.08 * breath)
                    .opacity(paused ? 0.3 : 0.55 + 0.3 * breath)
                    .position(centre)
                    .animation(.easeOut(duration: 0.5), value: paused)

                if !reduceMotion && !paused {
                    ForEach(Array(Self.motes.enumerated()), id: \.offset) { _, m in
                        mote(m, t: t, in: geo.size)
                    }
                }

                if let g = golden, !reduceMotion {
                    Circle()
                        .stroke(LGColor.sunRaysBright.opacity(1 - g), lineWidth: 4)
                        .frame(width: 220, height: 220)
                        .scaleEffect(1 + 1.4 * g)
                        .position(centre)
                }

                SunView(face: face,
                        litRays: golden != nil ? 12 : sun.litRays,
                        glowingRay: golden != nil || paused ? nil : sun.litRays,
                        glowOpacity: glow,
                        growingRay: growing == nil ? nil : sun.litRays - 1,
                        growProgress: growing.map { reduceMotion ? $0 : Self.easeOutBack($0) } ?? 1,
                        growFade: reduceMotion,
                        raysRotation: .degrees(spin),
                        raysOpacity: paused ? 0.4 : 1,
                        rayColor: LGColor.sunRaysBright,
                        raySpread: golden.map { 1 + 1.2 * sin($0 * .pi) } ?? 1)
                    .frame(width: 220, height: 220)
                    .offset(y: paused ? 24 : 0)
                    .animation(paused ? .easeOut(duration: 0.5) : .spring(duration: 0.4, bounce: 0.35), value: paused)
                    .scaleEffect(1 + 0.045 * breath)
                    .offset(y: -4 * breath + hop)
                    .position(centre)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(sun.accessibilityLabel)
                    .accessibilityAddTraits(.isImage)

                controls(elapsed: elapsed, paused: paused, sun: sun, golden: golden)
            }
        }
        .sensoryFeedback(trigger: sun.litRays) { old, new in new > old ? .impact(weight: .light) : nil }
        .sensoryFeedback(.success, trigger: sun.hoursCompleted)
        .onChange(of: sun.litRays) { _, rays in
            AccessibilityNotification.Announcement("\(rays) of 12 rays lit, \(sun.minutesIntoHour) minutes into this hour").post()
            LiveActivityManager.sync(state, now: now)
        }
        .onChange(of: paused) { _, _ in LiveActivityManager.sync(state, now: now) }
    }

    private func controls(elapsed: TimeInterval, paused: Bool, sun: SunHour, golden: Double?) -> some View {
        VStack(spacing: 16) {
            HStack {
                LGIconButton(systemName: "chevron.down", label: "Minimise", tint: .white, action: onMinimise)
                    .padding(.leading, -10)
                Spacer()
                Text(craftName).lgText(.rowStrong, color: .white)
                Spacer()
                Color.clear.frame(width: 34, height: 44)
            }
            .frame(height: 44)

            Spacer()

            VStack(spacing: 10) {
                Text(DurationFormat.clock(seconds: elapsed))
                    .lgNumber(.timerNumber, color: .white)
                    .accessibilityLabel(Self.spoken(elapsed))
                Text(paused ? "Paused" : sun.caption)
                    .lgText(.row, color: .white.opacity(0.75))
                    .multilineTextAlignment(.center)
                beadRow(hours: sun.hoursCompleted, golden: golden)
            }

            Color.clear.frame(height: 32)

            HStack(spacing: 10) {
                Button(paused ? "Resume" : "Pause", action: onToggle).buttonStyle(.lg(.translucent))
                Button("Finish", action: onFinish).buttonStyle(.lg(.light))
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 24)
    }

    /// A gold bead for every full hour; the newest one drops in at golden hour.
    private func beadRow(hours: Int, golden: Double?) -> some View {
        HStack(spacing: 8) {
            ForEach(0..<min(hours, 12), id: \.self) { i in
                let isNew = golden != nil && i == hours - 1
                Circle()
                    .fill(LGColor.sunRaysBright)
                    .frame(width: 12, height: 12)
                    .shadow(color: LGColor.sunBody.opacity(0.6), radius: 4)
                    .offset(y: isNew ? -90 * pow(1 - (golden ?? 1), 2) : 0)
                    .opacity(isNew ? min(1, (golden ?? 1) * 4) : 1)
            }
        }
        .frame(height: 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(hours == 0 ? "" : "\(hours) golden \(hours == 1 ? "hour" : "hours") so far")
    }

    private func mote(_ m: (x: Double, y: Double, delay: Double, size: CGFloat), t: Double, in size: CGSize) -> some View {
        let phase: Double = ((t + m.delay).truncatingRemainder(dividingBy: 5)) / 5
        let fadeIn: Double = phase / 0.15 * 0.9
        let fadeOut: Double = 0.9 * (1 - (phase - 0.15) / 0.85)
        let opacity: Double = phase < 0.15 ? fadeIn : fadeOut
        let x: CGFloat = CGFloat(m.x / 390) * size.width
        let y: CGFloat = CGFloat(m.y / 844) * size.height - CGFloat(150 * phase)
        return Circle()
            .fill(LGColor.mote)
            .frame(width: m.size, height: m.size)
            .shadow(color: LGColor.mote.opacity(0.6), radius: 4)
            .scaleEffect(0.6 + 0.5 * phase)
            .opacity(opacity)
            .position(x: x, y: y)
            .accessibilityHidden(true)
    }

    private static func smooth(_ x: Double) -> Double { x * x * (3 - 2 * x) }

    private static func easeOutBack(_ x: Double) -> Double {
        let c1 = 1.4, c3 = c1 + 1
        return 1 + c3 * pow(x - 1, 3) + c1 * pow(x - 1, 2)
    }

    private static func spoken(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        var parts: [String] = []
        if h > 0 { parts.append("\(h) \(h == 1 ? "hour" : "hours")") }
        if m > 0 { parts.append("\(m) \(m == 1 ? "minute" : "minutes")") }
        if h == 0 { parts.append("\(s) \(s == 1 ? "second" : "seconds")") }
        return parts.joined(separator: " ")
    }
}

// MARK: - Saved

private struct SavedScene: View {
    let now: Date
    let since: Date

    var body: some View {
        let p = min(1, max(0, now.timeIntervalSince(since) / 1.2))
        GeometryReader { geo in
            ZStack {
                TimerSky(warmth: 1, paused: false)
                SaveBurst(progress: p)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.32)
                SunView(face: .celebrate, rayColor: LGColor.sunRaysBright, raySpread: 1 + 0.8 * sin(p * .pi))
                    .frame(width: 220, height: 220)
                    .offset(y: -sin(p * .pi) * 36)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.32)
                VStack {
                    Spacer()
                    Text("Saved").lgText(.sheetTitle, color: .white)
                        .padding(.bottom, 140)
                        .opacity(p)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Session saved")
    }
}
