import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#endif

/// The full-screen timer: the sun's hour. Everything on screen is derived from
/// the stored timestamps and the clock; nothing is counted in memory.
struct TimerView: View {
    let craft: Craft
    /// The overall total before this session; the running session is added on top.
    let baseTotal: Double

    @Environment(TimerStore.self) private var store
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    @Query private var sessions: [Session]
    @Query private var settingsRows: [AppSettings]
    @Query private var targetPeriods: [TargetPeriod]

    @State private var showFinish = false
    @Environment(CommandCenter.self) private var commands: CommandCenter?
    @State private var savedAt: Date?
    /// The last state the timer had. Discarding clears the timer a moment before the screen has slid away, and
    /// without this the screen would show plain black until it is gone.
    @State private var lastState: TimerState?

    init(craft: Craft, baseTotal: Double) {
        self.craft = craft
        self.baseTotal = baseTotal
        let id = craft.id
        _sessions = Query(filter: #Predicate<Session> { $0.craftId == id })
    }

    /// Today's stretch as it stood before this session: fixed for the day, the live part is added per frame.
    private var stretchPlan: StretchPlan {
        StretchSource.plan(sessions: sessions.map(\.record), settings: settingsRows.first, periods: targetPeriods, now: Date())
    }

    var body: some View {
        let plan = stretchPlan
        TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 1.0 / 30)) { timeline in
            if let savedAt {
                SavedScene(now: timeline.date, since: savedAt, reduceMotion: reduceMotion)
            } else if let state = store.state ?? lastState {
                RunningScene(
                    now: timeline.date, state: state, craftName: craft.name + (store.startedOn.map { " · " + ActiveSessionText.startedOn($0) } ?? ""), baseTotal: baseTotal, reduceMotion: reduceMotion,
                    stretchPlan: plan,
                    onMinimise: { dismiss() },
                    onToggle: { store.togglePause() },
                    onFinish: {
                        store.pause()
                        showFinish = true
                    })
            } else {
                LGColor.night.ignoresSafeArea()
            }
        }
        .onChange(of: store.state, initial: true) { _, new in if let new { lastState = new } }
        .preferredColorScheme(.dark)
        .sensoryFeedback(.success, trigger: savedAt)
        .onChange(of: savedAt) { _, new in
            if new != nil { AccessibilityNotification.Announcement(String(localized: "Session saved")).post() }
        }
        .sheet(isPresented: $showFinish) {
            if let state = store.state {
                FinishSheet(elapsed: state.elapsed(at: Date()),
                            coversStretch: { StretchSource.startedToday(state) && plan.isCovered(byAdding: $0) },
                            onSave: save, onDiscard: discard)
                    .lgSheetCard()
            }
        }
        // ⌘N finishes the session; Space (below) pauses or resumes it. Neither while the Finish sheet is up.
        .onChange(of: commands?.issued) { _, issued in
            guard !showFinish, store.state != nil, savedAt == nil else { return }
            switch issued?.command {
            case .startOrFinish: store.pause(); showFinish = true
            case .pauseResume: store.togglePause()
            default: break
            }
        }
        .background {
            Button("Pause or resume") { store.togglePause() }
                .keyboardShortcut(.space, modifiers: [])
                .disabled(showFinish || savedAt != nil)
                .frame(width: 0, height: 0).opacity(0)
                .accessibilityHidden(true)
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
            #if os(iOS)
            UIApplication.shared.isIdleTimerDisabled = true
            #endif
            if store.finishRequested { openFinishFromActivity() }
        }
        .onDisappear {
            #if os(iOS)
            UIApplication.shared.isIdleTimerDisabled = false
            #endif
        }
    }

    private func openFinishFromActivity() {
        store.finishRequested = false
        showFinish = true
    }

    private func save(duration: TimeInterval, note: String?, photo: Data?) {
        guard let state = store.state else { return }
        let session = Session(craftId: state.craftId, start: state.startedAt, durationSec: duration, source: .timer,
                              note: note, photo: photo)
        // Where today's sunrise stands as this session ends: what the day had before it, plus its own length.
        if StretchSource.startedToday(state) {
            session.sunriseProgressAtEnd = TimerSunrise.progress(doneSaved: stretchPlan.doneSaved, running: duration,
                                                                 target: stretchPlan.target)
        }
        context.insert(session)
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
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverOn
    let baseTotal: Double
    let reduceMotion: Bool
    let stretchPlan: StretchPlan
    let onMinimise: () -> Void
    let onToggle: () -> Void
    let onFinish: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// A tap on the sun gets a soft wink here: no sound, no wiggle, so a session is never disturbed.
    @State private var tapWink = GiggleController()

    private static let motes: [(x: Double, y: Double, delay: Double, size: CGFloat)] = [
        (150, 330, 0, 6), (228, 340, 1.7, 4), (192, 350, 3.1, 6), (260, 300, 4.2, 4),
    ]

    var body: some View {
        let elapsed = state.elapsed(at: now)
        let paused = state.isPaused(at: now)
        let sun = SunHour(elapsed: elapsed)
        let golden = paused ? nil : sun.goldenProgress()
        let t = now.timeIntervalSinceReferenceDate
        // Small win: the overall total just crossed a whole hour.
        let win = paused ? nil : TimerMoments.secondsSinceWholeHour(baseTotal: baseTotal, elapsed: elapsed)
        let sunLabel = SunSpeech.timer(elapsed: elapsed, total: baseTotal + elapsed / 3600)
        let winScale = (win.map { reduceMotion ? 1 : TimerMoments.bounceScale(secondsSince: $0) }) ?? 1
        let sparkle = win.map { TimerMoments.shimmerOpacity(secondsSince: $0) } ?? 0

        let breath = reduceMotion ? 0 : (1 - cos(2 * .pi * t / (paused ? 8 : 4))) / 2
        let hop = golden.map { -sin($0 * .pi) * 34 } ?? 0

        // One sunrise a day: the sun follows today's stretch, not this session. It starts where the day left off and,
        // once the stretch is covered, stays up for the rest of the day.
        let startedToday = StretchSource.startedToday(state)
        let running = startedToday ? elapsed : 0
        let stretch = stretchPlan.state(running: running)
        let p = TimerSunrise.progress(doneSaved: stretchPlan.doneSaved + Self.debugDayHead(stretchPlan), running: running, target: stretchPlan.target)
        let palette = TimerPalette(p: p)
        let sinceCovered = startedToday ? stretchPlan.coveredAfter().map { elapsed - $0 } : nil
        let celebrating = !paused && TimerSunrise.isCelebrating(sinceCovered: sinceCovered)
        let justCovered = sinceCovered.map { $0 >= 0 } ?? false
        let tapped = tapWink.run?.pose(at: now)?.face == .wink
        let winking = !paused && golden == nil && !celebrating && (t.truncatingRemainder(dividingBy: 9) > 8.5 || tapped)
        let face: SunFace = golden != nil || celebrating ? .celebrate : paused ? .sleepy : winking ? .wink : (p >= 1 ? .happy : .focus)

        let growing = (paused || golden != nil) ? nil : sun.rayGrowProgress()
        let spin: Double = {
            if reduceMotion { return 0 }
            let hours = Double(sun.hoursCompleted)
            let extra = golden.map { 30 * (hours - 1) + 30 * Self.smooth($0) } ?? 30 * hours
            return elapsed / 120 * 360 + extra
        }()
        let glow = reduceMotion ? 0.6 : 0.35 + 0.65 * (1 - cos(2 * .pi * t / 1.6)) / 2

        // The outer reader keeps the safe areas (for padding); the inner one fills the whole screen for the sky.
        GeometryReader { safeProxy in
        GeometryReader { outer in
            // Wide windows put the sun on the left and the clock and buttons on the right. A big iPad window gets the
            // 340 pt sun and the 104 pt clock; a tall one is the iPhone Timer laid out small and scaled up to fit.
            // The reader fills the whole screen (the sky runs under the status bar); the safe areas are padding.
            let full = outer.size
            let insets = safeProxy.safeAreaInsets
            let shape = WindowShape.make(width: full.width, height: full.height, isRegularWidth: horizontalSizeClass == .regular)
            let wide = shape.isWide
            let big = shape == .sidebar
            let k: CGFloat = shape.isTall ? 1.35 : 1
            let geo = VirtualCanvas(size: CGSize(width: outer.size.width / k, height: outer.size.height / k))
            let safe = EdgeInsets(top: insets.top / k, leading: insets.leading / k, bottom: insets.bottom / k, trailing: insets.trailing / k)
            let sunSize: CGFloat = big ? 340 : 200
            let horizonY = geo.size.height * TimerSunrise.horizonFraction
            let rise = geo.size.height * TimerSunrise.riseFraction
            let centreX = wide ? geo.size.width * 0.28 : geo.size.width / 2
            // The sun sinks 24 pt when paused through its own animated offset below, so the glow follows it there.
            let centre = CGPoint(x: centreX, y: TimerSunrise.sunCentreY(p: p, horizonY: horizonY, rise: rise))
            ZStack(alignment: .topLeading) {
                TimerSunriseSky(p: p, paused: paused, horizonY: horizonY,
                                sunCentre: CGPoint(x: centre.x, y: centre.y + (paused ? 24 : 0)))
                    .frame(width: geo.size.width, height: geo.size.height)

                if !reduceMotion && !paused && p < 0.7 {
                    ForEach(Array(Self.motes.enumerated()), id: \.offset) { _, m in
                        mote(m, t: t, in: geo.size)
                    }
                }

                if let g = golden, !reduceMotion {
                    Circle()
                        .stroke(LGColor.sunRaysBright.opacity(1 - g), lineWidth: 4)
                        .frame(width: sunSize, height: sunSize)
                        .scaleEffect(1 + 1.4 * g)
                        .position(centre)
                }

                SunView(idle: false, face: face,
                        litRays: golden != nil || p >= 1 && !paused ? 12 : sun.litRays,
                        glowingRay: golden != nil || paused ? nil : sun.litRays,
                        glowOpacity: glow,
                        growingRay: growing == nil ? nil : sun.litRays - 1,
                        growProgress: growing.map { reduceMotion ? $0 : Self.easeOutBack($0) } ?? 1,
                        growFade: reduceMotion,
                        raysRotation: .degrees(spin),
                        raysOpacity: paused ? 0.4 : 1,
                        rayColor: LGColor.sunRaysBright,
                        raySpread: golden.map { 1 + 1.2 * sin($0 * .pi) } ?? 1)
                    .frame(width: sunSize, height: sunSize)
                    .overlay {
                        SparkleRing(opacity: sparkle, progress: (win ?? 0) / TimerMoments.shimmerDuration, still: reduceMotion)
                            .scaleEffect(sunSize / 220)
                    }
                    .scaleEffect(winScale)
                    .offset(y: paused ? 24 : 0)
                    .animation(paused ? .easeOut(duration: 0.5) : .spring(duration: 0.4, bounce: 0.35), value: paused)
                    .scaleEffect(1 + 0.045 * breath)
                    .offset(y: -4 * breath + hop)
                    .position(centre)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(sunLabel)
                    .accessibilityAddTraits(.isImage)
                    .accessibilityAction(named: Text("Tickle the sun")) { tapWink.tap(soundOn: false, reduceMotion: reduceMotion, winkOnly: true) }
                    .onTapGesture { tapWink.tap(soundOn: false, reduceMotion: reduceMotion, winkOnly: true) }

                // The sea is drawn after the sun: always in front of it, at every height.
                TimerSunriseLand(p: p, horizonY: horizonY)
                    .frame(width: geo.size.width, height: geo.size.height)

                if wide {
                    wideControls(elapsed: elapsed, paused: paused, sun: sun, golden: golden, stretch: stretch, palette: palette,
                                 big: big)
                        .padding(.leading, geo.size.width * 0.5)
                        .padding(.top, safe.top).padding(.bottom, safe.bottom)
                        .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                } else {
                    controls(elapsed: elapsed, paused: paused, sun: sun, stretch: stretch, p: p, palette: palette,
                             size: geo.size, safe: safe)
                        .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .scaleEffect(k, anchor: .topLeading)
            .frame(width: outer.size.width, height: outer.size.height, alignment: .topLeading)
            .sensoryFeedback(trigger: justCovered) { old, new in !old && new ? .success : nil }
            .onChange(of: justCovered) { _, new in
                if new { AccessibilityNotification.Announcement(String(localized: "Today's stretch covered.")).post() }
            }
        }
        .ignoresSafeArea()
        }
        .sensoryFeedback(trigger: sun.litRays) { old, new in new > old ? .impact(weight: .light) : nil }
        .sensoryFeedback(.success, trigger: sun.hoursCompleted)
        .sensoryFeedback(trigger: Int((baseTotal + elapsed / 3600).rounded(.down))) { old, new in
            new > old ? .impact(weight: .light) : nil
        }
        .onChange(of: sun.litRays) { _, _ in rayLit(sun: sun, paused: paused) }
        .onChange(of: paused) { _, isPaused in pauseChanged(isPaused) }
    }

    private func rayLit(sun: SunHour, paused: Bool) {
        if voiceOverOn && !paused {
            // Quiet and queued: it waits for VoiceOver to finish speaking and never interrupts.
            #if os(iOS)
            let text = NSAttributedString(string: SunSpeech.rayLit(sun), attributes: [
                .accessibilitySpeechQueueAnnouncement: true,
                .accessibilitySpeechAnnouncementPriority: UIAccessibilityPriority.low,
            ])
            UIAccessibility.post(notification: .announcement, argument: text)
            #else
            var announcement = AttributedString(SunSpeech.rayLit(sun))
            announcement.accessibilitySpeechAnnouncementPriority = .low
            AccessibilityNotification.Announcement(announcement).post()
            #endif
        }
        LiveActivityManager.sync(state, now: now)
    }

    private func pauseChanged(_ isPaused: Bool) {
        LiveActivityManager.sync(state, now: now)
        let message = isPaused ? String(localized: "Timer paused") : String(localized: "Timer resumed")
        AccessibilityNotification.Announcement(message).post()
    }

    /// The quiet line under the clock: the next ray, "Today's stretch covered." or the pause.
    private func quietLine(_ note: TimerSunrise.Note, palette: TimerPalette) -> some View {
        let text: String
        var colour = palette.muted
        var weight = Font.Weight.regular
        switch note {
        case .nextRay(let seconds):
            text = String(localized: "Next ray in \(DurationFormat.minutesSeconds(seconds: seconds))")
        case .covered:
            text = String(localized: "Today's stretch covered.")
            colour = palette.covered
            weight = .semibold
        case .paused:
            text = String(localized: "Paused. The sun is resting.")
        }
        return Text(text)
            .lgText(LGTextStyle(size: 13, weight: weight, relativeTo: .footnote), color: colour)
            .multilineTextAlignment(.center)
    }

    private func pauseButton(paused: Bool, palette: TimerPalette) -> some View {
        Button(paused ? "Resume" : "Pause", action: onToggle)
            .buttonStyle(TimerPillStyle(look: paused ? .gold : .quiet, palette: palette))
    }

    private func finishButton(paused: Bool, palette: TimerPalette) -> some View {
        Button("Finish", action: onFinish)
            .buttonStyle(TimerPillStyle(look: paused ? .quiet : .solid, palette: palette))
    }

    /// The phone's controls: minimise and the craft at the top; today's number, the bar, this session's clock and
    /// a quiet line from 59% of the way down; Pause and Finish at the bottom.
    private func controls(elapsed: TimeInterval, paused: Bool, sun: SunHour, stretch: StretchState, p: Double,
                          palette: TimerPalette, size: CGSize, safe: EdgeInsets) -> some View {
        let plan = stretchPlan
        let done = stretch.done
        let bar = TimerSunrise.bar(doneSaved: plan.doneSaved, running: StretchSource.startedToday(state) ? elapsed : 0, target: plan.target)
        let note = TimerSunrise.note(paused: paused, covered: stretch.isCovered, secondsToNextRay: sun.secondsToNextRay)
        return ZStack(alignment: .top) {
            HStack {
                Button(action: onMinimise) {
                    Image(systemName: "chevron.down").lgIcon(20, weight: .semibold)
                        .foregroundStyle(palette.ink)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Minimise")
                .padding(.leading, -10)
                Spacer()
                Text(craftName + (paused ? " · " + String(localized: "Paused") : ""))
                    .lgText(.rowStrong, color: palette.ink.opacity(0.85))
                    .lineLimit(1).minimumScaleFactor(0.7)
                Spacer()
                Color.clear.frame(width: 34, height: 44)
            }
            .frame(height: 44)
            .padding(.horizontal, 24)
            .padding(.top, safe.top + 8)

            VStack(spacing: 0) {
                if plan.target != nil {
                    Text(verbatim: StretchText.clock(seconds: done))
                        .lgNumber(LGTextStyle(size: 48, weight: .bold, relativeTo: .largeTitle, tracking: -1.9), color: palette.gold)
                    Text(StretchText.ofToday(plan.target ?? 0))
                        .lgText(LGTextStyle(size: 14, weight: .regular, relativeTo: .subheadline), color: palette.muted)
                        .padding(.top, 6)
                    progressBar(bar, palette: palette)
                        .padding(.top, 14)
                }
                Text("This session").lgText(.caption, color: palette.muted)
                    .padding(.top, plan.target != nil ? 22 : 0)
                Text(DurationFormat.clock(seconds: elapsed))
                    .lgNumber(LGTextStyle(size: 60, weight: .light, relativeTo: .largeTitle, tracking: -1.2), color: palette.ink)
                    .opacity(paused ? 0.6 : 1)
                    .accessibilityLabel("This session, " + Self.spoken(elapsed))
                quietLine(note, palette: palette).padding(.top, 4)
                Spacer(minLength: 12)
                HStack(spacing: 12) {
                    pauseButton(paused: paused, palette: palette)
                    finishButton(paused: paused, palette: palette)
                }
            }
            .accessibilityElement(children: .contain)
            .padding(.horizontal, 24)
            .padding(.top, size.height * 0.5924)
            .padding(.bottom, max(safe.bottom, 12) + 12)
        }
    }

    /// Today's bar: the part played before this session in a softer gold, then the part played now.
    private func progressBar(_ bar: (before: Double, now: Double), palette: TimerPalette) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(palette.track)
                Capsule().fill(palette.beforeBar).frame(width: w * bar.before)
                Capsule()
                    .fill(LinearGradient(colors: [Color(hex: 0xFFD66B), Color(hex: 0xF0922A)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: w * bar.now)
                    .shadow(color: Color(hex: 0xFFBE5A, opacity: 0.6), radius: 5)
                    .offset(x: w * bar.before)
            }
        }
        .frame(width: 260, height: 6)
        .accessibilityHidden(true)
    }

    /// The wide window's right side: clock and total on the left-aligned column, the buttons under them.
    private func wideControls(elapsed: TimeInterval, paused: Bool, sun: SunHour, golden: Double?,
                              stretch: StretchState, palette: TimerPalette, big: Bool = false) -> some View {
        let total = baseTotal + elapsed / 3600
        if big { return AnyView(bigControls(elapsed: elapsed, paused: paused, sun: sun, golden: golden, stretch: stretch, total: total, palette: palette)) }
        return AnyView(VStack(alignment: .leading, spacing: 10) {
            HStack {
                LGIconButton(systemName: "chevron.down", label: "Minimise", tint: palette.ink, action: onMinimise)
                    .padding(.leading, -10)
                Spacer()
            }
            .frame(height: 44)

                .frame(maxWidth: 360)

            Spacer(minLength: 0)

            Text("\(craftName) · this session").lgText(.row, color: palette.muted)
            Text(DurationFormat.clock(seconds: elapsed))
                .lgNumber(.timerNumberWide, color: palette.ink)
                .accessibilityLabel("This session, " + Self.spoken(elapsed))
            Text("\(DurationFormat.totalHours(total)) of 10,000 h" + (paused ? " · Paused" : " · " + sun.caption))
                .lgText(.rowStrong, color: palette.gold)
                .accessibilityLabel("Overall total \(DurationFormat.grouped(Totals.wholeHours(total: total))) hours, \(Totals.percent(total: total)) percent of 10,000. \(paused ? "Paused" : sun.caption)")
            quietLine(TimerSunrise.note(paused: paused, covered: stretch.isCovered, secondsToNextRay: sun.secondsToNextRay), palette: palette)
            beadRow(hours: sun.hoursCompleted, golden: golden)
                .padding(.top, 4)

            HStack(spacing: 10) {
                pauseButton(paused: paused, palette: palette)
                finishButton(paused: paused, palette: palette)
            }
            .padding(.top, 18)

            Spacer(minLength: 0)
        }
        .padding(.trailing, 36)
        .padding(.vertical, 8))
    }

    /// An iPad window wide enough for the sidebar: the craft, the gold total (56), "of 10,000 hours · 33%", then
    /// "This session", a 104 pt clock and "Next ray in", with Pause and Finish as 180 pt capsules.
    private func bigControls(elapsed: TimeInterval, paused: Bool, sun: SunHour, golden: Double?,
                             stretch: StretchState, total: Double, palette: TimerPalette) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                LGIconButton(systemName: "chevron.down", label: "Minimise", tint: palette.ink, action: onMinimise)
                    .padding(.leading, -10)
                Spacer()
            }
            .frame(height: 44)
            Spacer(minLength: 0)
            Text(craftName).lgText(.rowStrong, color: palette.muted)
            Text(DurationFormat.totalHours(total)).lgNumber(.timerTotal, color: palette.gold)
            Text("of 10,000 hours · \(Totals.percent(total: total))%").lgText(.row, color: palette.muted)
                .accessibilityLabel("Overall total \(DurationFormat.grouped(Totals.wholeHours(total: total))) hours, \(Totals.percent(total: total)) percent of 10,000")
            Text("This session").lgText(.caption, color: palette.muted).padding(.top, 22)
            Text(DurationFormat.clock(seconds: elapsed))
                .lgNumber(.timerNumberIPad, color: palette.ink)
                .accessibilityLabel("This session, " + Self.spoken(elapsed))
            Text(paused ? "Paused" : sun.caption).lgText(.row, color: palette.muted)
            quietLine(TimerSunrise.note(paused: paused, covered: stretch.isCovered, secondsToNextRay: sun.secondsToNextRay), palette: palette)
            beadRow(hours: sun.hoursCompleted, golden: golden).padding(.top, 4)
            HStack(spacing: 14) {
                pauseButton(paused: paused, palette: palette).frame(width: 180)
                finishButton(paused: paused, palette: palette).frame(width: 180)
            }
            .padding(.top, 20)
            Spacer(minLength: 0)
        }
        .padding(.trailing, 36)
        .padding(.vertical, 8)
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
        .accessibilityLabel(hours == 0 ? "" : Labels.goldenHoursSoFar(hours))
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

    /// Debug builds only: launch with `-timerProgress 0.6` (or the environment variable LG_TIMER_PROGRESS=0.6) to pretend 60% of today's stretch was already played, so
    /// the later stages of the sunrise can be looked at without waiting for them.
    private static func debugDayHead(_ plan: StretchPlan) -> TimeInterval {
        #if DEBUG
        let info = ProcessInfo.processInfo
        let args = info.arguments
        if let i = args.firstIndex(of: "-timerProgress"), args.indices.contains(i + 1), let f = Double(args[i + 1]) {
            return f * (plan.target ?? TimerSunrise.fallbackStretch)
        }
        if let value = info.environment["LG_TIMER_PROGRESS"], let f = Double(value) {
            return f * (plan.target ?? TimerSunrise.fallbackStretch)
        }
        #endif
        return 0
    }

    private static func smooth(_ x: Double) -> Double { x * x * (3 - 2 * x) }

    private static func easeOutBack(_ x: Double) -> Double {
        let c1 = 1.4, c3 = c1 + 1
        return 1 + c3 * pow(x - 1, 3) + c1 * pow(x - 1, 2)
    }

    private static func spoken(_ seconds: TimeInterval) -> String {
        Labels.spoken(seconds: Int(seconds), includeSeconds: true)
    }
}

/// The size the Timer is laid out in; a tall iPad window lays out small and scales up.
private struct VirtualCanvas { var size: CGSize }

/// A ring of gold sparkles that shimmers once around the sun.
private struct SparkleRing: View {
    let opacity: Double
    /// 0...1 through the shimmer.
    let progress: Double
    /// Reduce Motion: the ring just fades in and out.
    let still: Bool

    var body: some View {
        ZStack {
            ForEach(0..<16, id: \.self) { i in
                let angle = Double(i) / 16 * 2 * .pi
                Circle()
                    .fill(LGColor.mote)
                    .frame(width: i.isMultiple(of: 2) ? 5 : 3, height: i.isMultiple(of: 2) ? 5 : 3)
                    .shadow(color: LGColor.mote.opacity(0.7), radius: 3)
                    .offset(x: cos(angle) * 101, y: sin(angle) * 101)
            }
        }
        .rotationEffect(.degrees(still ? 0 : 40 * progress))
        .scaleEffect(still ? 1 : 0.94 + 0.1 * progress)
        .opacity(opacity)
        .accessibilityHidden(true)
    }
}

// MARK: - Saved

private struct SavedScene: View {
    let now: Date
    let since: Date
    let reduceMotion: Bool

    var body: some View {
        let p = min(1, max(0, now.timeIntervalSince(since) / 1.2))
        // Reduce Motion: no burst and no jump, the sun just smiles and "Saved" fades in.
        let motion = reduceMotion ? 0.0 : 1.0
        GeometryReader { geo in
            ZStack {
                TimerSky(warmth: 1, paused: false)
                SaveBurst(progress: p)
                    .opacity(motion)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.29)
                SunView(idle: false, face: .celebrate, rayColor: LGColor.sunRaysBright, raySpread: 1 + 0.8 * motion * sin(p * .pi))
                    .frame(width: 220, height: 220)
                    .offset(y: -sin(p * .pi) * 36 * motion)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.29)
                VStack {
                    Spacer()
                    Text("Saved").lgText(.sheetTitle, color: .white).accessibilityAddTraits(.isHeader)
                        .padding(.bottom, 140)
                        .opacity(p)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Session saved")
    }
}
