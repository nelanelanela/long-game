import SwiftUI
import SwiftData

/// The small navy note after a save: "40 m added" with Undo, or "Removed.".
private struct HomeToast: Equatable {
    let id = UUID()
    var text: String
    /// What VoiceOver reads ("40 minutes added").
    var spoken: String
    /// The sessions the save created, when Undo is offered.
    var undo: [UUID]?
}

private enum HomeSheet: Identifiable {
    case addHours, futureSelf, support
    /// The weekly look-back, and Your weekly pace opened from it.
    case lookBack(WeekLookBack), editPace
    /// The target screen as a sheet: a new year of pace, or the first target for an older game.
    case target(first: Bool)

    var id: String {
        switch self {
        case .addHours: "add"
        case .futureSelf: "future"
        case .support: "support"
        case .lookBack: "lookBack"
        case .editPace: "editPace"
        case .target: "target"
        }
    }
}

struct HomeView: View {
    let craft: Craft

    @Query private var sessions: [Session]
    @Query private var estimates: [YearEstimate]
    @Query private var settingsRows: [AppSettings]
    @Query private var targetPeriods: [TargetPeriod]
    @Environment(\.modelContext) private var context
    @Environment(TimerStore.self) private var timer
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var celebrating: Int?
    /// A 1,000+ hour celebration is due or showing: the icon waits until its main button is tapped.
    @State private var iconHeld = false
    @State private var offerSupport = false
    @State private var sheet: HomeSheet?
    /// The session opened from Today's sessions to edit.
    @State private var editingSession: Session?
    /// False while Home is covered or in the background: the hero stops animating.
    @State private var onScreen = true
    /// Scene storage: after the system closes and reopens a window, a running session is still in front.
    @SceneStorage("home.showTimer") private var showTimer = false
    @State private var totalBeforeTimer = 0.0
    /// While set, Home shows this instead of the real total (the count-up after a save).
    @State private var countingTotal: Double?
    @State private var catchUpGap: CatchUp.Gap?
    /// "1.5 h added." for a moment after hours are saved (the timer, Add past hours or a catch-up), with Undo.
    @State private var toast: HomeToast?
    /// The sessions Home has already seen, so a save's new ones are known (what its Undo removes).
    @State private var knownSessionIDs: Set<UUID>?
    @AccessibilityFocusState private var toastFocused: Bool
    /// Today's small anniversary ("A year since you started."), if any.
    @State private var anniversary: Anniversary?
    /// The sun's celebrate face for a moment on the first open of an anniversary day.
    @State private var anniversaryFace = false
    @AppStorage("anniversary.faceDay") private var anniversaryFaceDay: Double = 0
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverOn
    @State private var totalBeforeCatchUp = 0.0
    /// Today, This week or The long game. Home opens on Today; right after onboarding it opens on The long game once
    /// (`AppSettings.lastHomeTab` holds the one to open on). Tapping another tab is not remembered for next time.
    @SceneStorage("home.tab") private var tab: HomeTab = .today
    /// The tab with a scale the sun last stood on, so Today's sun glides back to the right height.
    @State private var lastScaleTab: HomeTab = .week
    /// Today's sun winks for a moment when the stretch is covered.
    @State private var winking = false
    /// Bumped by a timer loop so Today's numbers follow the clock (every second while a session runs).
    @State private var tick = Date()
    /// The opening tab is chosen once, the first time this Home appears, not each time it comes back from History.
    @State private var choseOpeningTab = false
    /// Which part of the page is at the top, so a fold, unfold or resize keeps the scroll position.
    @State private var scrollSpot: ScrollSpot?
    /// Which History to push: on a day (a tapped day bar, the calendar button) or on the Growth chart (the Finish
    /// line figure). One destination for both: a second `navigationDestination(isPresented:)` beside the day one
    /// looped forever when the Finish line was tapped (Home redraws every second) and iOS closed the app.
    @State private var historyRoute: HistoryRoute?
    /// The day History opens on, read and set through `historyRoute`.
    private var historyDay: Date? {
        get { if case .day(let day) = historyRoute { day } else { nil } }
        nonmutating set { historyRoute = newValue.map(HistoryRoute.day) }
    }
    /// The gear in the bar at the top.
    @State private var showSettings = false
    /// The phone's bar is transparent: once the page has scrolled past the hero the craft name fades, so it never
    /// sits on top of the content. Only the title reads it, so scrolling never makes all of Home work itself out again.
    @State private var barFade = BarFade()
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    /// The sidebar layout's view (the Play views follow `tab`; History and Settings are kept here).
    @SceneStorage("sidebar.section") private var section: SidebarSection = .today
    /// The window's layout, kept for the keyboard commands.
    @State private var shape: WindowShape = .compact
    @Environment(CommandCenter.self) private var commands: CommandCenter?

    init(craft: Craft, initialTab: HomeTab = .today) {
        self.craft = craft
        _tab = SceneStorage(wrappedValue: initialTab, "home.tab")
        let id = craft.id
        _sessions = Query(filter: #Predicate<Session> { $0.craftId == id }, sort: \Session.start, order: .reverse)
        _estimates = Query(filter: #Predicate<YearEstimate> { $0.craftId == id })
    }

    private var weekStart: WeekStart { settingsRows.first?.weekStart ?? .localeDefault }
    private var target: TargetRecord? { settingsRows.first?.currentTarget }

    /// `records` is the sessions already read out of the store this redraw (reading thousands of them is the
    /// slow part, so the body does it once and shares the result).
    private func summary(now: Date, records: [SessionRecord]? = nil) -> ProgressSummary {
        ProgressSummary.make(estimates: estimates.map(\.rate), sessions: records ?? sessions.map(\.record),
                             onboardingDate: craft.createdAt, weekStart: weekStart, now: now, target: target)
    }

    var body: some View {
        let now = Date()
        let records = sessions.map(\.record)
        let s = summary(now: now, records: records)
        let shownTotal = countingTotal ?? s.total
        // While the total counts up after a saved session, this week's hours count up with it.
        let shownWeek = max(0, s.thisWeek - (s.total - shownTotal))
        let weekTarget = target?.hoursPerWeek ?? WeeklyTarget.suggested(pace: s.pace)
        let plan = StretchSource.plan(sessions: records, settings: settingsRows.first, periods: targetPeriods, now: now)
        let stretch = plan.state(running: StretchSource.runningSeconds(timer.state, craftID: craft.id, now: now))
        let figures = HomeFigures(now: now, summary: s, week: shownWeek, total: shownTotal, weekTarget: weekTarget,
                                  stretch: stretch, shown: tab == .today && stretch == .noTarget ? .week : tab,
                                  records: records,
                                  bars: WeekBars.make(sessions: records, now: now, weekStart: weekStart),
                                  lastWeek: WeekBars.lastWeek(sessions: records, now: now, weekStart: weekStart,
                                                              onboardingDate: craft.createdAt))
        let _ = tick
        let page = AdaptiveLayout { window in
            Group {
                if window.shape == .sidebar {
                    sidebarPage(figures, window: window)
                } else if window.shape == .tall {
                    tallPage(figures)
                } else if window.shape.isWide {
                    widePage(figures, window: window)
                } else {
                    columnPage(figures, short: window.shape == .short)
                }
            }
            // Folding, unfolding or resizing moves to the matching layout; the tab, sheets and timer live above it.
            .animation(.easeInOut(duration: reduceMotion ? 0.2 : 0.35), value: window.shape)
            .onAppear { shape = window.shape }
            .onChange(of: window.shape) { _, new in shape = new }
        }
        .lgWarmScreen()
        .lgHidesNavigationBar()
        // Settings has its own stack: a screen that hides the navigation bar, pushed on top of another pushed screen
        // (Settings → Your estimates), sent SwiftUI into an endless layout loop. It closes back to Home.
        .fullScreenCover(isPresented: $showSettings, onDismiss: sheetClosed) {
            NavigationStack {
                SettingsView(craft: craft, closeAll: { showSettings = false })
            }
        }
        .onChange(of: commands?.issued) { _, issued in
            if let command = issued?.command { handle(command, total: s.total) }
        }
        .navigationDestination(item: $historyRoute) { route in
            switch route {
            case .day(let day): HistoryView(craft: craft, day: day)
            case .growth: HistoryView(craft: craft, opensOnGrowth: true)
            }
        }
        // A widget opens Home on its tab: back out of History and any sheet first.
        .onOpenURL { url in
            guard let link = WidgetLink.tab(from: url) else { return }
            historyRoute = nil
            sheet = nil
            showSettings = false
            selectTab(link)
        }
        .fullScreenCover(isPresented: $showTimer, onDismiss: timerDismissed) {
            // Read live rather than from state, so the timer never starts from a stale total.
            TimerView(craft: craft, baseTotal: summary(now: Date()).total)
                .allowsRotation()
        }
        .onChange(of: timer.finishRequested) { _, requested in
            if requested { openTimer(total: s.total) }
        }
        .onDisappear { onScreen = false }
        lifecycle(page, figures: figures, s: s)
    }

    /// The page's lifecycle, sheets and alerts, kept apart from `body` so the compiler can type-check each.
    private func lifecycle<V: View>(_ page: V, figures: HomeFigures, s: ProgressSummary) -> some View {
        page
        .modifier(TodayLive(winkWhen: figures.shown == .today && figures.stretch.isCovered,
                            ticksWhen: tab == .today && onScreen && !showTimer && scenePhase == .active,
                            everySecond: timer.isActive, winking: $winking, tick: $tick))
        .onAppear {
            onScreen = true
            if knownSessionIDs == nil { knownSessionIDs = Set(sessions.map(\.id)) }
            refreshAnniversary()
            chooseOpeningTab()
            fillSessionPictures()
            if showTimer && !timer.isActive { showTimer = false }
            if timer.finishRequested { openTimer(total: s.total) }
            showFutureSelfOnce()
            showTargetSheetOnce()
            syncIconQuietly(total: s.total)
            checkMilestones(total: s.total)
            refreshNotifications()
            scheduleMilestoneNotification()
            checkCatchUp(summary: s)
            checkLookBack(summary: s)
        }
        .onChange(of: timer.state) { _, _ in scheduleMilestoneNotification() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                refreshAnniversary()
                let now = summary(now: Date())
                syncIconQuietly(total: now.total)
                checkCatchUp(summary: now)
                checkLookBack(summary: now)
            }
        }
        .sheet(item: $catchUpGap, onDismiss: sheetClosed) { gap in
            CatchUpSheet(craft: craft, gap: gap, pace: totalPace, total: s.total, onFinish: catchUpFinished,
                         onBreak: {
                             selectTab(.today)
                             showMessage(String(localized: "Rest is part of the craft."))
                         })
                .lgSheetCard()
        }
        .onChange(of: s.total) { old, total in
            let celebrates = checkMilestones(total: total)
            let before = knownSessionIDs ?? []
            knownSessionIDs = Set(sessions.map(\.id))
            if total > old, showTimer || sheet != nil || catchUpGap != nil {
                let undo = UndoSave.offer(before: before, after: sessions.map(\.id), celebrates: celebrates)
                showToast(addedHours: total - old, undo: undo)
                // The timer plays its own save feeling; Add past hours and Catch up play theirs here.
                if !showTimer && !celebrates { playAddedHaptic(created: undo ?? [], figures: figures) }
            }
        }
        // Back from Settings (the debug buttons there can ask for the look-back or an anniversary).
        .onChange(of: showSettings) { _, open in
            guard !open else { return }
            refreshAnniversary()
            Task { try? await Task.sleep(for: .seconds(0.6)); checkLookBack(summary: summary(now: Date())) }
        }
        .onChange(of: toastFocused) { was, now in
            // With VoiceOver the toast stays until focus moves away from it.
            if was && !now, toast?.undo != nil { toast = nil }
        }
        .onChange(of: sessions.count) { old, new in
            fillSessionPictures()
            refreshAnniversary()
            refreshNotifications()
        }
        .overlay {
            if let hours = celebrating {
                MilestoneCelebration(hours: hours, craftName: craft.name, offerSupport: offerSupport,
                                     iconGrows: settingsRows.first?.iconGrows ?? true,
                                     onSupport: { iconHeld = false; celebrating = nil; sheet = .support },
                                     onDone: { celebrationDone(hours: hours) })
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: celebrating)
        .animation(.easeInOut(duration: reduceMotion ? 0.1 : 0.25), value: toast)
        .sheet(item: $editingSession, onDismiss: sheetClosed) { session in
            SessionFormView(craft: craft, sessions: sessions, editing: session)
                .lgSheetCard()
        }
        .sheet(item: $sheet, onDismiss: sheetClosed) { item in
            Group {
            switch item {
            case .addHours:
                SessionFormView(craft: craft, sessions: sessions, editing: nil)
            case .futureSelf:
                FutureSelfSheet(total: s.total, forecast: s.forecast.chosen)
            case .support:
                TipJarView(isSheet: true)
            case .lookBack(let look):
                WeekLookBackSheet(craft: craft, look: look,
                                  lastWeekPace: paceFor(day: look.weekStart),
                                  thisWeekPace: target?.hoursPerWeek,
                                  total: s.total, thisWeekSoFar: s.thisWeek,
                                  finish: String(ForecastText.shortFinish(s.forecast.chosen, now: Date()).drop { $0 == "~" }),
                                  sessions: Array(sessions),
                                  onChangePace: {
                                      Task { try? await Task.sleep(for: .seconds(0.5)); sheet = .editPace }
                                  })
            case .editPace:
                NavigationStack {
                    WeeklyTargetView(mode: .edit, initial: target?.hoursPerWeek, actualPace: s.pace, onSave: saveTarget)
                }
            case .target(let first):
                WeeklyTargetView(mode: first ? .firstTime : .newYear,
                                 initial: first ? nil : target?.hoursPerWeek,
                                 actualPace: s.pace, onSave: saveTarget)
            }
            }
            .lgSheetCard()
        }
    }

    // MARK: Layouts

    /// Everything the layouts show, worked out once per refresh.
    private struct HomeFigures {
        var now: Date
        var summary: ProgressSummary
        var week: Double
        var total: Double
        var weekTarget: Double
        var stretch: StretchState
        /// The tab on show: Today falls back to This week when there is no weekly target yet.
        var shown: HomeTab
        /// The craft's sessions as plain values, read once per redraw.
        var records: [SessionRecord]
        /// This week's day bars.
        var bars: [DayBar]
        /// Last week's hours per weekday, faint behind the bars (nil in the first week or after an empty week).
        var lastWeek: [Double]?
    }

    private enum ScrollSpot: Hashable { case top, details }

    private func scaleGauge(_ f: HomeFigures) -> HomeGauge {
        if (f.shown.hasScale ? f.shown : lastScaleTab) == .longGame {
            return .longGame(total: f.total, pace: f.summary.hasEnoughData ? SunSpeech.pace(f.summary.forecast.chosen, now: f.now) : nil)
        }
        let daysLeft = f.bars.filter(\.isFuture).count
        return .week(hours: f.week, target: f.weekTarget, daysLeft: daysLeft)
    }

    /// "Monday, 1 hour 10 minutes", "Tuesday, rest day", "Saturday, not yet": read when the sun is swiped on This week.
    private func dayReadings(_ bars: [DayBar]) -> [String] {
        let formatter = CachedFormatter.pattern("EEEE", calendar: .current, locale: .current)
        return bars.map { bar in
            let name = formatter.string(from: bar.day)
            if bar.isFuture { return String(localized: "\(name), not yet") }
            if bar.hours <= 0 { return String(localized: "\(name), rest day") }
            return "\(name), " + Labels.spoken(seconds: Int((bar.hours * 60).rounded()) * 60, includeSeconds: false)
        }
    }

    /// A picture dropped on a session row: processed like the picker's, then saved with that session.
    private func attachDropped(_ data: Data, to session: Session?) {
        guard let session else { return }
        Task {
            let prepared = await Task.detached(priority: .userInitiated) { PhotoProcessing.prepare(data) }.value
            guard let prepared else { return }
            session.setPhoto(prepared)
            try? context.save()
        }
    }

    /// Today's sessions: the saved ones that started today, oldest first, and the running timer as the first row.
    /// The rows add up to the big number above.
    private func todaySessions(_ f: HomeFigures) -> some View {
        let today = TodaySessions.startedToday(sessions, start: \.start, now: f.now)
        let rows = today.map { TodaySession(id: $0.id, start: $0.start, end: $0.end, durationSec: $0.durationSec,
                                            note: $0.note, photo: $0.hasPhoto ? $0.photo : nil,
                                            sunriseProgress: $0.sunriseProgressAtEnd ?? 0,
                                            hidesDefaultPicture: $0.hidesDefaultPicture) }
        let running = timer.state.flatMap { state -> TimeInterval? in
            state.craftId == craft.id && StretchSource.startedToday(state, now: f.now) ? state.elapsed(at: f.now) : nil
        }
        return TodaySessionsList(rows: rows, running: running, onSelect: { id in
            editingSession = today.first { $0.id == id }
        }, onDropImage: { id, data in attachDropped(data, to: today.first { $0.id == id }) })
    }

    /// Gives every session its sunrise number (existing ones once, new manual and catch-up ones as they come).
    private func fillSessionPictures() {
        SessionPictures.fillMissing(sessions: sessions, settings: settingsRows.first, periods: targetPeriods, context: context)
    }

    private func showToast(addedHours: Double, undo: [UUID]?) {
        let minutes = Int((addedHours * 60).rounded())
        guard minutes > 0 else { return }
        let amount = addedHours < 0.95 ? "\(minutes) m" : DurationFormat.hours(addedHours)
        let spokenAmount = addedHours < 0.95 ? Labels.spoken(seconds: minutes * 60, includeSeconds: false)
                                             : DurationFormat.hours(addedHours)
        let shown = HomeToast(text: String(localized: "\(amount) added"), spoken: String(localized: "\(spokenAmount) added"),
                              undo: undo)
        toast = shown
        // After the timer, its screen stays up for a moment (the save burst) before Home is back in view.
        let covered: Double = showTimer ? 1.4 : 0
        if undo != nil && voiceOverOn {
            // Focus moves to it ("40 minutes added. Undo, button.") and it stays until focus moves on.
            Task { try? await Task.sleep(for: .seconds(covered + 0.4)); toastFocused = true }
            return
        }
        AccessibilityNotification.Announcement(shown.spoken).post()
        Task {
            try? await Task.sleep(for: .seconds(covered + (undo == nil ? 2.6 : UndoSave.showFor)))
            if toast?.id == shown.id { toast = nil }
        }
    }

    /// "Time is added": a soft tap, two taps if it covered today's stretch, rising three if it reached the weekly pace.
    private func playAddedHaptic(created: [UUID], figures: HomeFigures) {
        let ids = Set(created)
        let new = sessions.filter { ids.contains($0.id) }
        let calendar = Calendar.current
        let addedToday = new.filter { calendar.isDate($0.start, inSameDayAs: figures.now) }.reduce(0) { $0 + $1.durationSec }
        let weekStartDate = WeekMath.startOfWeek(figures.now, weekStart: weekStart)
        let addedThisWeek = new.filter { $0.start >= weekStartDate }.reduce(0) { $0 + $1.durationSec } / 3600
        let covers: Bool = {
            guard let t = figures.stretch.target, addedToday > 0 else { return false }
            return figures.stretch.done >= t && figures.stretch.done - addedToday < t
        }()
        let paceReached = figures.weekTarget > 0 && addedThisWeek > 0
            && figures.summary.thisWeek >= figures.weekTarget && figures.summary.thisWeek - addedThisWeek < figures.weekTarget
        Haptics.play(HapticPlan.save(timer: false, coversStretch: covers, reachesMilestone: false, reachesWeeklyPace: paceReached))
    }

    /// A plain note in the toast's place for a few seconds ("Rest is part of the craft.").
    private func showMessage(_ text: String) {
        let shown = HomeToast(text: text, spoken: text, undo: nil)
        toast = shown
        AccessibilityNotification.Announcement(text).post()
        Task {
            try? await Task.sleep(for: .seconds(3))
            if toast?.id == shown.id { toast = nil }
        }
    }

    /// Undo: deletes exactly what that save created, with its note and photo, then says "Removed." for 2 seconds.
    /// Totals, the icon stage, widgets and notifications follow as for any deletion.
    private func undoLastSave() {
        guard let ids = toast?.undo else { return }
        Haptics.play(.undo)
        for session in UndoSave.toRemove(Array(sessions), id: \.id, offered: ids) { context.delete(session) }
        try? context.save()
        countingTotal = nil
        let removed = HomeToast(text: String(localized: "Removed."), spoken: String(localized: "Removed."), undo: nil)
        toast = removed
        AccessibilityNotification.Announcement(removed.spoken).post()
        Task {
            try? await Task.sleep(for: .seconds(UndoSave.removedFor))
            if toast?.id == removed.id { toast = nil }
        }
    }

    private func hero(_ f: HomeFigures, metrics given: GaugeMetrics, extendsSky: Bool = false) -> some View {
        // The phone's column has a hero of its own height on each tab; other windows keep theirs.
        let metrics = given == .standard ? GaugeMetrics.phone(for: f.shown) : given
        let scale = scaleGauge(f)
        let onToday = f.shown == .today
        let g = onToday ? HomeGauge.today(f.stretch) : scale
        let place = GaugeHero.Place(fraction: scale.fraction, arcFraction: f.stretch.fraction, arcMix: onToday ? 1 : 0)
        let face: SunFace = anniversaryFace ? .celebrate
            : onToday ? (winking ? .wink : .happy)
                      : (countingTotal != nil || g.reachedTop ? .celebrate : .happy)
        return GaugeHero(gauge: g, fraction: place.fraction, arcFraction: place.arcFraction, arcMix: place.arcMix,
                         face: face, isRunning: onScreen && scenePhase == .active && !showTimer, glides: false,
                         extendsSky: extendsSky, dawnSky: onToday && isEmptyDay(f.stretch), metrics: metrics, final: place,
                         dayReadings: dayReadings(f.bars))
            // The sun and sea change tabs with a clean cut: no glide, no cross-fade, so the water never shows through.
            .transaction { $0.animation = nil }
    }

    /// The small navy note at the hero's top right.
    @ViewBuilder private var toastView: some View {
        if let toast {
            HStack(spacing: 10) {
                Text(verbatim: toast.text)
                    .lgText(LGTextStyle(size: 14, weight: .semibold, relativeTo: .subheadline), color: .white)
                if toast.undo != nil {
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 18)
                    Button(action: undoLastSave) {
                        Text("Undo")
                            .lgText(LGTextStyle(size: 14, weight: .semibold, relativeTo: .subheadline), color: LGColor.timerGold)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 30)
                            .background(LGColor.toastUndoPill, in: Capsule())
                            // A 44 pt target around the 30 pt pill.
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.leading, 14).padding(.trailing, toast.undo != nil ? 6 : 14)
            .frame(minHeight: 40)
            .background(LGColor.ink, in: Capsule())
            .shadow(color: LGColor.ink.opacity(0.25), radius: 8, y: 6)
            .padding(.top, 12).padding(.trailing, 20)
            .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: toast.undo != nil ? toast.spoken + ". " + String(localized: "Undo") : toast.spoken))
            .accessibilityAddTraits(toast.undo != nil ? .isButton : .updatesFrequently)
            .accessibilityAction { if toast.undo != nil { undoLastSave() } }
            .accessibilityFocused($toastFocused)
        }
    }

    /// The big number; each tab's replaces the other's with a cross-fade, stacked so the page doesn't jump.
    private func number(_ f: HomeFigures, style: NumberLayout) -> some View {
        VStack(alignment: style.isLeading ? .leading : .center, spacing: 8) {
            ZStack(alignment: style.isLeading ? .topLeading : .top) {
                switch f.shown {
                case .today:
                    if isEmptyDay(f.stretch) {
                        EmptyDayHeading().transition(.opacity)
                    } else {
                        TodayNumber(state: f.stretch, style: style)
                            .transition(.opacity)
                    }
                case .week:
                    CountingWeek(hours: f.week, target: f.weekTarget, style: style)
                        .transition(.opacity)
                case .longGame:
                    CountingTotal(value: f.total, style: style)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, alignment: style.isLeading ? .leading : .center)
            .accessibilityElement(children: .combine)

            // Today's small anniversary: one line under the number, for that calendar day only.
            if let anniversary {
                Text(verbatim: anniversary.line)
                    .lgText(LGTextStyle(size: 13, weight: .semibold, relativeTo: .footnote), color: LGColor.ember)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .frame(minHeight: 28)
                    .background(LGColor.anniversaryPill, in: Capsule())
                    .transition(.opacity)
            }
        }
    }

    /// Today's anniversary (nil on most days), worked out when sessions change or the app comes back.
    private func refreshAnniversary() {
        let now = Date()
        let calendar = Calendar.current
        let loggedToday = sessions.filter { calendar.isDate($0.createdAt, inSameDayAs: now) }.reduce(0) { $0 + $1.durationSec } / 3600
        let total = summary(now: now).total
        let found = Anniversary.today(.init(loggedAt: sessions.map(\.createdAt), starts: sessions.map(\.start),
                                            hourMilestoneToday: Anniversary.hourMilestoneToday(totalAtStartOfToday: total - loggedToday, total: total)),
                                      now: now, calendar: calendar)
        #if DEBUG
        anniversary = DebugOptions.fakeAnniversary ?? found
        #else
        anniversary = found
        #endif
        // The sun celebrates on the first open of the day that has one.
        let today = calendar.startOfDay(for: now).timeIntervalSince1970
        if anniversary != nil, anniversaryFaceDay != today {
            anniversaryFaceDay = today
            anniversaryFace = true
            Task {
                try? await Task.sleep(for: .seconds(4))
                anniversaryFace = false
            }
        }
    }

    /// Phone and short window: one column. The craft name with History and + stays on top as a bar while the page
    /// scrolls under it, and the buttons stay pinned under the page.
    private func columnPage(_ f: HomeFigures, short: Bool) -> some View {
        // The sky behind the bar is dark on The long game and on the empty day.
        let darkSky = f.shown == .longGame || (f.shown == .today && isEmptyDay(f.stretch))
        let heroTop: CGFloat = short ? 2 : 8
        let fade = barFade
        return ScrollView {
            VStack(spacing: 0) {
                hero(f, metrics: short ? .short : .standard, extendsSky: true)
                    // Where the hero ends on screen: the title fades once it has gone up past the bar.
                    .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).maxY } action: { fade.heroBottom = $0 }
                    .overlay(alignment: .topTrailing) { toastView }
                    .padding(.top, heroTop)
                    .id(ScrollSpot.top)
                number(f, style: short ? .inline : .stacked)
                    .padding(.top, short ? 4 : 8)
                ZStack(alignment: .top) {
                    switch f.shown {
                    case .today:
                        VStack(spacing: short ? 12 : 18) {
                            if !isEmptyDay(f.stretch) { TodayQuietLine(state: f.stretch) }
                            todaySessions(f)
                        }
                        .padding(.top, short ? 6 : 14)
                        .transition(.opacity)
                    case .week:
                        weekContent(f, showBars: !short)
                            .transition(.opacity)
                    case .longGame:
                        longGameContent(f)
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, 24)
                .id(ScrollSpot.details)
            }
            .lgReadableColumn(560)
            .padding(.bottom, 24)
            .scrollTargetLayout()
        }
        .scrollPosition(id: $scrollSpot)
        // No warm wash on the phone's Home: the sky is the only thing behind the bar, the plain background below it.
        .background(LGColor.background.ignoresSafeArea())
        .lgTopBar(transparent: true) {
            VStack(spacing: 0) {
                header(dark: darkSky, paired: true, fade: reduceTransparency ? nil : fade)
                    .padding(.top, short ? 0 : 8)
                // The tabs stay pinned under the craft name; only the page below them scrolls.
                LGSegmentedControl(items: HomeTab.allCases, selection: tab, label: "Home view", title: Self.title, onSelect: tapTab)
                    .padding(.top, short ? 4 : 10).padding(.bottom, 4)
            }
            .padding(.horizontal, 24)
            .lgReadableColumn(560)
            .environment(\.lgOnDark, darkSky)
            .environment(\.lgOverSky, true)
            .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).maxY } action: { fade.barBottom = $0 }
        }
        .safeAreaInset(edge: .bottom) { actionBar(sideBySide: short, inset: EdgeInsets()) }
    }

    /// Wide window (the Duo open, an iPad window): the sun gauge on the left, the numbers and buttons on the right.
    /// The content keeps clear of the safe areas on both sides, the vertical Dynamic Island included; only the
    /// sea runs to the edge.
    private func widePage(_ f: HomeFigures, window: WindowInfo) -> some View {
        let inset = window.safeArea
        let leftWidth = (window.size.width * 0.52).rounded()
        let metrics = GaugeMetrics.wide(height: WideGauge.height(forWindow: window.size.height - inset.top - inset.bottom),
                                         leadingInset: inset.leading)
        return HStack(spacing: 0) {
            VStack(spacing: 0) {
                header().padding(.leading, inset.leading + 24).padding(.trailing, 12)
                LGSegmentedControl(items: HomeTab.allCases, selection: tab, label: "Home view", title: Self.title, onSelect: tapTab)
                    .padding(.leading, inset.leading + 24).padding(.trailing, 12).padding(.top, 8)
                Spacer(minLength: 0)
                hero(f, metrics: metrics)
                Spacer(minLength: 0)
            }
            .frame(width: leftWidth)
            .padding(.top, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    number(f, style: .leading).id(ScrollSpot.top)
                    VStack(spacing: 0) {
                        switch f.shown {
                        case .today:
                            TodayQuietLine(state: f.stretch, leading: true)
                                .padding(.top, 6)
                            todaySessions(f)
                                .padding(.top, 18)
                        case .week:
                            weekContent(f, showBars: true)
                            wideStatsRow(f.summary, now: f.now, total: f.total)
                        case .longGame:
                            longGameContent(f)
                        }
                    }
                    .padding(.top, 8)
                    .id(ScrollSpot.details)
                }
                .padding(.leading, 20).padding(.trailing, inset.trailing + 32)
                .padding(.top, 24).padding(.bottom, 16)
                .scrollTargetLayout()
            }
            .scrollPosition(id: $scrollSpot)
            .safeAreaInset(edge: .bottom) {
                actionBar(sideBySide: true, inset: EdgeInsets(top: 0, leading: -4, bottom: 0, trailing: inset.trailing + 8))
            }
        }
        .ignoresSafeArea(.container, edges: .horizontal)
    }

    /// The wide window's stats under the target row: the long-game total, pace and the finish line.
    private func wideStatsRow(_ s: ProgressSummary, now: Date, total: Double) -> some View {
        HStack(spacing: 0) {
            stat("\(DurationFormat.grouped(Totals.wholeHours(total: total))) h", "The long game")
            stat(DurationFormat.perWeek(s.pace), "Pace")
            finishLineStat(ForecastText.homeMastery(s.forecast.chosen, now: now))
        }
        .padding(.vertical, 14)
        .overlay(alignment: .top) { Rectangle().fill(LGColor.hairline).frame(height: 1) }
    }


    // MARK: iPad

    /// The view on show in the sidebar layout. The Play views are the Home tab; the others are kept in `section`.
    private var sidebarSelection: SidebarSection {
        section.homeTab == nil ? section : SidebarSection(tab: tab)
    }

    private func selectSection(_ new: SidebarSection) {
        if let homeTab = new.homeTab { selectTab(homeTab) }
        section = new
    }

    /// ⌘N, ⌘L, ⌘1–⌘5 and ⌘, from the keyboard (the timer handles Space and ⌘N while it is open).
    private func handle(_ command: AppCommand, total: Double) {
        guard !showTimer else { return }
        switch command {
        case .startOrFinish:
            guard sheet == nil, editingSession == nil else { return }
            openTimer(total: summary(now: Date()).total)
        case .addHours:
            guard sheet == nil, editingSession == nil else { return }
            sheet = .addHours
        case .show(let new):
            if shape == .sidebar { selectSection(new) }
            else if let homeTab = new.homeTab { selectTab(homeTab) }
            else if new != .settings { historyDay = Calendar.current.startOfDay(for: Date()) }
        case .settings:
            if shape == .sidebar { selectSection(.settings) } else { showSettings = true }
        case .pauseResume:
            break
        }
    }

    /// "1 h 05 of 1 h 45 · 40 m to go" for the Today card.
    private func todayLine(_ stretch: StretchState) -> String { StretchText.cardLine(stretch) }

    private func numbersCard(_ f: HomeFigures) -> some View {
        let added = WeeklyTarget.addedByEnd(target, now: f.now)
        let rhythm = Rhythm.compute(daily: IPadFigures.daily(f.records), since: craft.createdAt, now: f.now, weekStart: weekStart)
        return IPadNumbersCard(
            pace: target.map { DurationFormat.perWeek($0.hoursPerWeek) } ?? DurationFormat.perWeek(f.summary.pace),
            finish: ForecastText.homeMastery(f.summary.forecast.chosen, now: f.now),
            byValue: added.map { "+\(DurationFormat.grouped(Int($0.rounded()))) h" } ?? "–",
            byLabel: target.map { "By \(DateText.monthYear($0.end))" } ?? "Year of pace",
            rhythm: IPadFigures.rhythmText(daysPerWeek: rhythm.daysPerWeek),
            showGrowth: { if shape == .sidebar { selectSection(.growth) } else { historyRoute = .growth } })
    }

    private func todayCard(_ f: HomeFigures) -> some View {
        IPadCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Today").lgText(LGTextStyle(size: 14, weight: .semibold, relativeTo: .subheadline))
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: 8)
                    Text(verbatim: todayLine(f.stretch))
                        .lgText(.caption, color: LGColor.inkMuted)
                        .multilineTextAlignment(.trailing)
                }
                todaySessions(f)
            }
        }
    }

    private func futureSelfCard() -> some View {
        FutureSelfRowCard { sheet = .futureSelf }
    }

    /// The cards under (or beside) the sun on the iPad: the numbers, Today with today's sessions, Meet your future self.
    @ViewBuilder
    private func cardColumn(_ f: HomeFigures, sideBySide: Bool = false) -> some View {
        if f.shown == .week {
            IPadCard {
                VStack(spacing: 0) {
                    DayBarsRow(bars: f.bars, lastWeek: f.lastWeek) { day in historyDay = day }
                    targetRow(f.summary, now: f.now)
                }
            }
        }
        if sideBySide {
            HStack(alignment: .top, spacing: 14) {
                numbersCard(f)
                todayCard(f)
            }
        } else if f.shown == .today {
            todayCard(f)
            numbersCard(f)
        } else {
            numbersCard(f)
            todayCard(f)
        }
        futureSelfCard()
        if f.shown == .longGame { yearRow(f) }
    }

    /// Wide iPad windows: a sidebar, a title bar, the sun gauge on the left and a 340 pt column of cards on the right.
    private func sidebarPage(_ f: HomeFigures, window: WindowInfo) -> some View {
        let current = sidebarSelection
        let hasBar = current != .settings && current != .year
        let barTitle: LocalizedStringKey = SidebarView.title(current)
        let metrics = GaugeMetrics.large(height: min(340, max(260, window.size.height - 330)), sun: 190)
        return HStack(spacing: 0) {
            SidebarView(craftName: craft.name, totalHours: f.summary.wholeHours,
                        yearTitle: String(YearSummary.defaultYear(now: f.now)),
                        selection: Binding(get: { sidebarSelection }, set: { selectSection($0) }))
            VStack(spacing: 0) {
                if hasBar {
                    SidebarTitleBar(title: barTitle, startTitle: startTitle(at: f.now),
                                    onAddHours: { sheet = .addHours },
                                    onStart: { openTimer(total: summary(now: Date()).total) })
                }
                Group {
                    switch current {
                    case .today, .week, .longGame:
                        HStack(alignment: .top, spacing: 28) {
                            VStack(alignment: .leading, spacing: 10) {
                                hero(f, metrics: metrics).frame(maxWidth: 560)
                                number(f, style: .sidebar).padding(.leading, 4)
                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            ScrollView {
                                VStack(spacing: 14) { cardColumn(f) }
                                    .padding(.bottom, 8)
                            }
                            .frame(width: 340)
                        }
                        .padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 24)
                    case .calendar:
                        ScrollView {
                            CalendarTab(craft: craft, sessions: sessions, weekStart: weekStart, initialDay: historyDay)
                                .padding(.horizontal, 24).padding(.bottom, 24)
                                .lgReadableColumn(980)
                        }
                    case .growth:
                        ScrollView {
                            GrowthTab(craft: craft, sessions: sessions, estimates: estimates, weekStart: weekStart, target: target)
                                .padding(.horizontal, 24).padding(.bottom, 24)
                                .lgReadableColumn(980)
                        }
                    case .year:
                        YearScreen(craft: craft, sessions: sessions, estimates: estimates, weekStart: weekStart,
                                   year: YearSummary.defaultYear(now: f.now))
                            .environment(\.lgEmbedded, true)
                    case .settings:
                        SettingsView(craft: craft, closeAll: { selectSection(.longGame) })
                            .environment(\.lgEmbedded, true)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    /// Tall iPad windows (portrait): floating tabs, the craft name at 34 pt, a bigger sun, two cards side by side and
    /// the two 56 pt buttons at the bottom. Content is no wider than 760 pt.
    private func tallPage(_ f: HomeFigures) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                HStack {
                    Text(craft.name).lgText(.ipadCraftTitle)
                        .id(ScrollSpot.top)
                        .lineLimit(1).minimumScaleFactor(0.6)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    HStack(spacing: 10) {
                        LGIconButton(systemName: "calendar", label: "History", size: 19, weight: .regular) {
                            historyDay = Calendar.current.startOfDay(for: Date())
                        }
                        LGIconButton(systemName: "gearshape", label: "Settings") { showSettings = true }
                    }
                    .padding(.trailing, -10)
                }
                .frame(minHeight: 56)
                .padding(.top, 14)
                hero(f, metrics: .large(height: 440, sun: 220)).padding(.top, 4)
                number(f, style: .tall).padding(.top, 8)
                VStack(spacing: 14) {
                    cardColumn(f, sideBySide: true)
                }
                .padding(.top, 22)
                .id(ScrollSpot.details)
            }
            .padding(.horizontal, 32).padding(.bottom, 24)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .scrollTargetLayout()
        }
        .scrollPosition(id: $scrollSpot)
        .lgTopBar {
            // Pinned: the tabs never scroll away.
            LGSegmentedControl(items: HomeTab.allCases, selection: tab, label: "Home view", title: Self.title, onSelect: tapTab)
                .frame(maxWidth: 520)
                .padding(.top, 12).padding(.bottom, 4)
                .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 16) {
                Button("Add past hours") { sheet = .addHours }.buttonStyle(.lg(.secondary))
                startButton
            }
            .frame(maxWidth: 760 - 64)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 32).padding(.top, 12).padding(.bottom, 4)
            .background(LGColor.background.opacity(0.94))
        }
    }

    // MARK: Pieces

    /// `paired` (the phone's transparent bar): from iOS 26 the two glass circles share one glass container.
    private func header(dark: Bool = false, paired: Bool = false, fade: BarFade? = nil) -> some View {
        HStack {
            BarTitle(fade: fade) {
                Text(craft.name).lgText(.screenTitle, color: dark ? .white : LGColor.ink)
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .accessibilityAddTraits(.isHeader)
            }
            Spacer()
            headerButtons(paired: paired)
                .padding(.trailing, -10)
        }
        .frame(minHeight: 44)
    }

    @ViewBuilder private func headerButtons(paired: Bool) -> some View {
        let buttons = HStack(spacing: 10) {
            LGIconButton(systemName: "calendar", label: "History", size: 19, weight: .regular) {
                historyDay = Calendar.current.startOfDay(for: Date())
            }
            LGIconButton(systemName: "gearshape", label: "Settings") { showSettings = true }
        }
        if #available(iOS 26, macOS 26, *), paired {
            GlassEffectContainer(spacing: 4) { buttons }
        } else {
            buttons
        }
    }

    private static func title(_ tab: HomeTab) -> LocalizedStringKey {
        switch tab {
        case .today: "Today"
        case .week: "This week"
        case .longGame: "The long game"
        }
    }

    /// A tab tapped on the switcher: the tick, then the switch.
    private func tapTab(_ new: HomeTab) {
        if new != tab { Haptics.play(.tabSwitch) }
        selectTab(new)
    }

    private func selectTab(_ new: HomeTab) {
        guard new != tab else { return }
        if new.hasScale { lastScaleTab = new }
        withAnimation(.easeInOut(duration: 0.25)) { tab = new }
    }

    /// Opens on Today, except right after onboarding: then on The long game, once, with the whole game in view.
    /// Whatever was chosen is reset to Today straight away, so the next launch starts there. (A value saved by an
    /// older version, This week, also opens on Today.)
    private func chooseOpeningTab() {
        guard !choseOpeningTab else { return }
        choseOpeningTab = true
        guard let settings = settingsRows.first else { return }
        tab = settings.lastHomeTab == .longGame ? .longGame : .today
        if tab.hasScale { lastScaleTab = tab }
        if settings.lastHomeTab != .today {
            settings.lastHomeTab = .today
            try? context.save()
        }
    }

    // MARK: This week

    private func weekContent(_ f: HomeFigures, showBars: Bool) -> some View {
        VStack(spacing: 0) {
            if showBars {
                DayBarsRow(bars: f.bars, lastWeek: f.lastWeek) { day in
                    historyDay = day
                }
                .padding(.top, 18)
            }
            targetRow(f.summary, now: f.now)
                .padding(.top, showBars ? 0 : 6)
        }
    }

    /// Under the day bars: this week against the target; opens "Your pace for the year" to change it.
    private func targetRow(_ s: ProgressSummary, now: Date) -> some View {
        NavigationLink {
            WeeklyTargetView(mode: .edit, initial: target?.hoursPerWeek, actualPace: s.pace, onSave: saveTarget)
        } label: {
            TargetRow(target: target, hoursThisWeek: s.thisWeek, weekStart: weekStart, now: now)
        }
        .buttonStyle(.plain)
    }

    // MARK: The long game

    private func longGameContent(_ f: HomeFigures) -> some View {
        VStack(spacing: 0) {
            statsRow(f.summary, now: f.now)
                .padding(.top, 16)
            yearRow(f)
            futureSelfRow
        }
    }

    /// From 1 December to 15 January only: the year card, under "Meet your future self". No notification.
    @ViewBuilder
    private func yearRow(_ f: HomeFigures) -> some View {
        let now = f.now
        if YearSummary.showsOnLongGame(now: now) {
            let year = YearSummary.defaultYear(now: now)
            let summary = YearSummary.make(year: year, sessions: f.records, estimates: estimates.map(\.rate),
                                           onboardingDate: craft.createdAt, now: now, weekStart: weekStart)
            if summary.hasEnoughData {
                NavigationLink {
                    YearScreen(craft: craft, sessions: sessions, estimates: estimates, weekStart: weekStart, year: year)
                } label: {
                    YearEntryRow(year: year)
                }
                .buttonStyle(.plain)
                .overlay(alignment: .bottom) { Rectangle().fill(LGColor.hairline).frame(height: 1) }
            }
        }
    }

    /// Pace, what the weekly target still adds by the end of its year, and the finish line.
    private func statsRow(_ s: ProgressSummary, now: Date) -> some View {
        let added = WeeklyTarget.addedByEnd(target, now: now)
        return HStack(spacing: 0) {
            stat(DurationFormat.perWeek(s.pace), "Pace")
            Group {
                if let target, let added {
                    stat("+\(DurationFormat.grouped(Int(added.rounded()))) h", "By \(DateText.monthYear(target.end))")
                } else {
                    stat("–", "Year of pace")
                }
            }
            // Hairlines either side of the middle figure, as on the board.
            .overlay(alignment: .leading) { Rectangle().fill(LGColor.hairline).frame(width: 1) }
            .overlay(alignment: .trailing) { Rectangle().fill(LGColor.hairline).frame(width: 1) }
            finishLineStat(ForecastText.homeMastery(s.forecast.chosen, now: now), colour: LGColor.ember)
        }
        .padding(.vertical, 12)
        .overlay(alignment: .top) { Rectangle().fill(LGColor.hairline).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(LGColor.hairline).frame(height: 1) }
    }

    /// Under the stats: opens "Meet your future self".
    private var futureSelfRow: some View {
        Button { sheet = .futureSelf } label: {
            HStack(spacing: 12) {
                SunView(idle: false, face: .happy, eyesOpen: 1).frame(width: 40, height: 40).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Meet your future self").lgText(.rowStrong)
                    Text("Who you’re playing for").lgText(.caption, color: LGColor.inkMuted)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .lgIcon(13, weight: .semibold)
                    .foregroundStyle(LGColor.inkMuted)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens a short note about where your hours are heading")
    }

    /// The first time Home appears after onboarding, "Meet your future self" opens on its own, once.
    private func showFutureSelfOnce() {
        guard let settings = settingsRows.first, !settings.futureSelfShown,
              sheet == nil, catchUpGap == nil, !showTimer else { return }
        settings.futureSelfShown = true
        try? context.save()
        sheet = .futureSelf
    }

    /// Saves a new year of pace: 12 months from today, the old one moves into the history.
    private func saveTarget(_ hours: Double) {
        guard let settings = settingsRows.first else { return }
        TargetSaving.apply(hours: hours, settings: settings, context: context)
    }

    /// Once, when the year of pace is over (the old value filled in) or a game has never had a target.
    /// The weekly pace that applied on a day (from the stored target periods), nil when there was none.
    private func paceFor(day: Date) -> Double? {
        let records = targetPeriods.map { TargetRecord(hoursPerWeek: $0.hoursPerWeek, start: $0.start, end: $0.end) }
        let current = target
        if let current, day >= current.start, day < current.end { return current.hoursPerWeek }
        return records.first { day >= $0.start && day < $0.end }?.hoursPerWeek ?? current?.hoursPerWeek
    }

    /// The weekly look-back: the first open in a new week, once, if last week had a session; never in the first week,
    /// and never over a running session or another sheet (it waits for the next open).
    private func checkLookBack(summary s: ProgressSummary) {
        guard let settings = settingsRows.first else { return }
        let now = Date()
        var force = false
        #if DEBUG
        force = DebugOptions.takeLookBackRequest()
        #endif
        let entries = sessions.map { WeekLookBack.Entry(id: $0.id, start: $0.start, seconds: $0.durationSec, hasPhoto: $0.hasPhoto,
                                                        viewCount: $0.viewCount, note: $0.note) }
        let look = WeekLookBack.make(entries, now: now, weekStart: weekStart)
        let busy = sheet != nil || catchUpGap != nil || celebrating != nil || showTimer || editingSession != nil || showSettings
        guard let look else { return }
        guard force && !busy || WeekLookBack.shouldShow(now: now, weekStart: weekStart, onboardingDate: craft.createdAt,
                                                         lastShownWeek: settings.lastLookBackWeek, lastWeekHadSession: true,
                                                         sessionRunning: timer.isActive, sheetOpen: busy) else { return }
        settings.lastLookBackWeek = WeekMath.startOfWeek(now, weekStart: weekStart)
        try? context.save()
        sheet = .lookBack(look)
    }

    private func showTargetSheetOnce() {
        guard let settings = settingsRows.first, sheet == nil, catchUpGap == nil, !showTimer,
              TargetCycle.shouldOpenSheet(settings.currentTarget, promptShownAt: settings.targetPromptShownAt, now: Date())
        else { return }
        settings.targetPromptShownAt = Date()
        try? context.save()
        sheet = .target(first: settings.currentTarget == nil)
    }

    /// The Finish line figure: tapping it opens History on the Growth chart, where the finish line is drawn.
    private func finishLineStat(_ value: String, colour: Color = LGColor.ink) -> some View {
        Button { historyRoute = .growth } label: {
            stat(value, "Finish line", colour: colour)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens the Growth chart")
    }

    /// A small label over its figure (12 pt over 17 pt bold), as on the boards.
    private func stat(_ value: String, _ label: LocalizedStringKey, colour: Color = LGColor.ink) -> some View {
        VStack(spacing: 2) {
            Text(label).lgText(.statLabel, color: LGColor.inkMuted)
            Text(value).lgNumber(.statFigure, color: colour)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: Welcome back

    private var totalPace: Double { summary(now: Date()).pace }

    /// Offers Welcome back after a break of 7+ days, at most once every 7 days.
    private func checkCatchUp(summary s: ProgressSummary) {
        guard catchUpGap == nil, sheet == nil, !showTimer, !timer.isActive, celebrating == nil,
              let settings = settingsRows.first else { return }
        let now = Date()
        var starts = sessions.map(\.start)
        var force = false
        #if DEBUG
        if let days = DebugOptions.takePretendLastSessionDaysAgo() {
            starts = [Calendar.current.date(byAdding: .day, value: -days, to: now) ?? now]
            force = true
        }
        #endif
        let gap = CatchUp.gap(sessionStarts: starts, onboardingDate: craft.createdAt, today: now)
        guard force ? (gap?.days ?? 0) >= CatchUp.minGapDays
                    : CatchUp.shouldPrompt(gap: gap, lastPromptAt: settings.lastCatchUpPromptAt, now: now) else { return }
        // Any outcome counts as asked: adding, "No, I took a break" or dismissing.
        settings.lastCatchUpPromptAt = now
        try? context.save()
        totalBeforeCatchUp = s.total
        catchUpGap = gap
    }

    private func catchUpFinished(addedHours: Double) {
        guard addedHours > 0 else { return }
        guard !reduceMotion else { return }
        let new = totalBeforeCatchUp + addedHours
        countingTotal = totalBeforeCatchUp
        withAnimation(.easeOut(duration: 1.2)) { countingTotal = new }
        Task {
            try? await Task.sleep(for: .seconds(1.4))
            countingTotal = nil
        }
    }

    // MARK: Milestones and reminders

    /// Returns whether a milestone celebration is coming (the "added" toast then has no Undo).
    @discardableResult
    private func checkMilestones(total: Double) -> Bool {
        if settingsRows.isEmpty {
            context.insert(AppSettings())
            try? context.save()
            return false
        }
        guard let settings = settingsRows.first else { return false }
        let crossed = Milestones.newlyCrossed(total: total, seen: settings.milestonesSeen)
        guard let top = crossed.max() else { return false }
        settings.milestonesSeen.append(contentsOf: crossed)
        try? context.save()
        if top >= IconPlan.heldBelow { iconHeld = true }
        Task {
            // let a saved session's count-up finish first
            try? await Task.sleep(for: .seconds(1.6))
            offerSupport = shouldOfferSupport(settings)
            celebrating = top
        }
        return true
    }

    /// The celebration's main button: close it, then (only for 1,000 hours and up) let the icon grow. One change,
    /// straight to the stage for the whole total, even if a big save jumped over several milestones.
    private func celebrationDone(hours: Int) {
        celebrating = nil
        iconHeld = false
        guard let settings = settingsRows.first else { return }
        let total = summary(now: Date()).total
        if let stage = IconPlan.afterCelebration(hours: hours, totalHours: total, growsWithYou: settings.iconGrows,
                                                  applied: settings.appliedIconStage) {
            AppIconManager.apply(stage, settings: settings, context: context, timerRunning: timer.isActive)
        }
    }

    /// A sheet, the timer or Settings has fully closed (their `onDismiss` runs after the animation): a thousand that
    /// the saved session crossed, and that has no celebration, changes the icon now, over Home.
    private func sheetClosed() {
        syncIconQuietly(total: summary(now: Date()).total)
    }

    /// On launch, on return to the foreground and when Home first appears: set the right icon once, quietly.
    /// A lower total (Replace my craft, deleted sessions, lower estimates) lowers the icon here; never during a session.
    private func syncIconQuietly(total: Double) {
        // Never while a sheet or the timer is up: iOS's "You have changed the icon" alert must land over Home.
        // Each of them calls this again once it has fully closed.
        guard let settings = settingsRows.first, !timer.isActive, sheet == nil, editingSession == nil, catchUpGap == nil, !showTimer,
              !showSettings else { return }
        let due = !Milestones.newlyCrossed(total: total, seen: settings.milestonesSeen)
            .filter { $0 >= IconPlan.heldBelow }.isEmpty
        if let stage = IconPlan.quietStage(totalHours: total, growsWithYou: settings.iconGrows,
                                           applied: settings.appliedIconStage,
                                           celebrationPending: due || iconHeld || celebrating != nil) {
            AppIconManager.apply(stage, settings: settings, context: context, timerRunning: timer.isActive)
        }
    }

    /// The one gentle offer; recorded as soon as it is shown. Never a pop-up of its own.
    private func shouldOfferSupport(_ settings: AppSettings) -> Bool {
        let now = Date()
        guard TipRules.shouldOffer(now: now, onboardedAt: craft.createdAt, lastOfferAt: settings.lastTipOfferAt,
                                   lastTipAt: settings.lastTipAt, timerRunning: timer.isActive,
                                   lastSessionEndedAt: sessions.map(\.end).max()) else { return false }
        settings.lastTipOfferAt = now
        try? context.save()
        return true
    }

    private func refreshNotifications() {
        guard let settings = settingsRows.first else { return }
        let records = sessions.map(\.record)
        let name = craft.name
        let (time, days, nudge) = (settings.reminderTime, settings.reminderDays, settings.rhythmNudge)
        Task {
            await NotificationPlanner.refresh(craftName: name, reminderTime: time, reminderDays: days,
                                              rhythmNudge: nudge, sessions: records)
        }
    }

    /// While a session runs, plans a notification for the moment its hours would carry the total over the next
    /// milestone, in case the app is in the background by then. Pausing, finishing or a new milestone re-plans it.
    private func scheduleMilestoneNotification() {
        guard let state = timer.state, state.craftId == craft.id, let settings = settingsRows.first else {
            Notifications.scheduleMilestone(at: nil, message: "")
            return
        }
        let base = summary(now: Date()).total
        if let next = Milestones.nextCrossing(baseTotal: base, state: state, seen: settings.milestonesSeen, now: Date()) {
            Notifications.scheduleMilestone(at: next.date, message: Milestones.notificationMessage(hours: next.hours, craft: craft.name))
        } else {
            Notifications.scheduleMilestone(at: nil, message: "")
        }
    }

    private func openTimer(total: Double) {
        totalBeforeTimer = total
        if !timer.isActive { timer.start(craft: craft) }
        showTimer = true
    }

    /// After a saved session the total counts up from old to new.
    private func timerDismissed() {
        defer { sheetClosed() }
        guard timer.savedSession else { return }
        timer.savedSession = false
        guard !reduceMotion else { return }
        let new = summary(now: Date()).total
        countingTotal = totalBeforeTimer
        withAnimation(.easeOut(duration: 1.2)) { countingTotal = new }
        Task {
            try? await Task.sleep(for: .seconds(1.4))
            countingTotal = nil
        }
    }

    /// Nothing played today yet: Today says so in words instead of showing "0 m".
    private func isEmptyDay(_ stretch: StretchState) -> Bool {
        if case .inProgress(_, let done) = stretch { return done < 1 }
        return false
    }

    private func startTitle(at now: Date) -> String {
        guard let state = timer.state, state.craftId == craft.id else {
            return String(localized: "Begin")
        }
        // A running timer isn't waiting to be resumed: the button takes you back to it.
        let verb = state.isPaused(at: now) ? "Resume" : "Back to session"
        return verb + " · " + DurationFormat.clock(seconds: state.elapsed(at: now))
    }

    private func actionBar(sideBySide: Bool, inset: EdgeInsets) -> some View {
        Group {
            if sideBySide {
                HStack(spacing: 20) {
                    startButton
                    Button("Add past hours") { sheet = .addHours }
                        .buttonStyle(.lg(.quiet))
                        .fixedSize(horizontal: true, vertical: false)
                }
            } else {
                VStack(spacing: 12) {
                    startButton
                    Button("Add past hours") { sheet = .addHours }.buttonStyle(.lg(.quiet))
                }
            }
        }
        .padding(.leading, 24 + inset.leading).padding(.trailing, 24 + inset.trailing)
        .padding(.top, 12)
        .padding(.bottom, 4)
        .background(LGColor.background.opacity(0.94))
    }

    private var startButton: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            Button(startTitle(at: timeline.date)) { openTimer(total: summary(now: Date()).total) }
                .buttonStyle(.lg(.primary))
        }
    }
}

/// Today's live bits: the sun winks for a moment when the stretch is covered, and the numbers follow the clock
/// (every second while a session runs, otherwise now and then so a new day starts fresh).
private struct TodayLive: ViewModifier {
    var winkWhen: Bool
    var ticksWhen: Bool
    var everySecond: Bool
    @Binding var winking: Bool
    @Binding var tick: Date

    func body(content: Content) -> some View {
        content
            .task(id: winkWhen) {
                winking = winkWhen
                guard winkWhen else { return }
                try? await Task.sleep(for: .seconds(1.6))
                winking = false
            }
            .task(id: ticksWhen) {
                guard ticksWhen else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(everySecond ? 1 : 30))
                    tick = Date()
                }
            }
    }
}

/// Where the phone's top bar and the hero end on screen, for fading the craft name. Kept outside `HomeView`'s state:
/// only `BarTitle` reads it, so the measurements never make all of Home work itself out again (which looped at launch).
@MainActor @Observable
final class BarFade {
    var barBottom: CGFloat = 0
    /// Where the hero's bottom is on screen (far below the bar at rest).
    var heroBottom: CGFloat = .infinity

    /// 1 at rest; once the hero has gone up past the bar it fades to 0 over 24 pt, in 5% steps.
    var titleOpacity: Double {
        guard barBottom > 0, heroBottom.isFinite else { return 1 }
        let faded = Double(min(max((barBottom - heroBottom) / 24, 0), 1))
        return 1 - (faded * 20).rounded() / 20
    }
}

/// The craft name, faded by `BarFade` (nil: never fades, e.g. with Reduce Transparency).
private struct BarTitle<Content: View>: View {
    var fade: BarFade?
    @ViewBuilder var content: Content

    var body: some View {
        content.opacity(fade?.titleOpacity ?? 1)
    }
}

/// Where Home's History push opens.
enum HistoryRoute: Hashable, Identifiable {
    case day(Date)
    case growth
    var id: Self { self }
}
