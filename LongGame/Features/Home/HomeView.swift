import SwiftUI
import SwiftData

private enum HomeSheet: Identifiable {
    case addHours, futureSelf, support
    /// The target screen as a sheet: a new year of pace, or the first target for an older game.
    case target(first: Bool)

    var id: String {
        switch self {
        case .addHours: "add"
        case .futureSelf: "future"
        case .support: "support"
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
    @State private var askAboutReminders = false
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
    /// "1.5 h added." for a moment after hours are saved (the timer, Add past hours or a catch-up).
    @State private var toast: String?
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
    /// Set by tapping a day bar: History opens on that day.
    @State private var historyDay: Date?
    /// The gear in the bar at the top.
    @State private var showSettings = false
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

    private func summary(now: Date) -> ProgressSummary {
        ProgressSummary.make(estimates: estimates.map(\.rate), sessions: sessions.map(\.record),
                             onboardingDate: craft.createdAt, weekStart: weekStart, now: now, target: target)
    }

    var body: some View {
        let now = Date()
        let s = summary(now: now)
        let shownTotal = countingTotal ?? s.total
        // While the total counts up after a saved session, this week's hours count up with it.
        let shownWeek = max(0, s.thisWeek - (s.total - shownTotal))
        let weekTarget = target?.hoursPerWeek ?? WeeklyTarget.suggested(pace: s.pace)
        let records = sessions.map(\.record)
        let plan = StretchSource.plan(sessions: records, settings: settingsRows.first, periods: targetPeriods, now: now)
        let stretch = plan.state(running: StretchSource.runningSeconds(timer.state, craftID: craft.id, now: now))
        let figures = HomeFigures(now: now, summary: s, week: shownWeek, total: shownTotal, weekTarget: weekTarget,
                                  stretch: stretch, shown: tab == .today && stretch == .noTarget ? .week : tab)
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
        .navigationDestination(item: $historyDay) { day in
            HistoryView(craft: craft, day: day)
        }
        // A widget opens Home on its tab: back out of History and any sheet first.
        .onOpenURL { url in
            guard let link = WidgetLink.tab(from: url) else { return }
            historyDay = nil
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
        }
        .onChange(of: timer.state) { _, _ in scheduleMilestoneNotification() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                let now = summary(now: Date())
                syncIconQuietly(total: now.total)
                checkCatchUp(summary: now)
            }
        }
        .sheet(item: $catchUpGap, onDismiss: sheetClosed) { gap in
            CatchUpSheet(craft: craft, gap: gap, pace: totalPace, onFinish: catchUpFinished)
                .lgSheetCard()
        }
        .onChange(of: s.total) { old, total in
            checkMilestones(total: total)
            if total > old, showTimer || sheet != nil || catchUpGap != nil { showToast(addedHours: total - old) }
        }
        .onChange(of: sessions.count) { old, new in
            fillSessionPictures()
            refreshNotifications()
            if old == 0, new == 1, !UserDefaults.standard.bool(forKey: "notifications.asked") { askAboutReminders = true }
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
        .alert("Want a gentle nudge?", isPresented: $askAboutReminders) {
            Button("Yes, remind me") { enableDailyReminder() }
            Button("Not now", role: .cancel) { UserDefaults.standard.set(true, forKey: "notifications.asked") }
        } message: {
            Text("A daily reminder at 7 pm, when the sun is waiting. You can change it in Settings.")
        }
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
    }

    private enum ScrollSpot: Hashable { case top, details }

    private func scaleGauge(_ f: HomeFigures) -> HomeGauge {
        if (f.shown.hasScale ? f.shown : lastScaleTab) == .longGame {
            return .longGame(total: f.total, pace: f.summary.hasEnoughData ? SunSpeech.pace(f.summary.forecast.chosen, now: f.now) : nil)
        }
        let daysLeft = weekBars(f.now).filter(\.isFuture).count
        return .week(hours: f.week, target: f.weekTarget, daysLeft: daysLeft)
    }

    private func weekBars(_ now: Date) -> [DayBar] {
        WeekBars.make(sessions: sessions.map(\.record), now: now, weekStart: weekStart)
    }

    /// "Monday, 1 hour 10 minutes", "Tuesday, rest day", "Saturday, not yet": read when the sun is swiped on This week.
    private func dayReadings(_ now: Date) -> [String] {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "EEEE"
        return weekBars(now).map { bar in
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

    private func showToast(addedHours: Double) {
        let minutes = Int((addedHours * 60).rounded())
        guard minutes > 0 else { return }
        let amount = addedHours < 0.95 ? "\(minutes) m" : DurationFormat.hours(addedHours)
        let text = String(localized: "\(amount) added.")
        toast = text
        AccessibilityNotification.Announcement(text).post()
        Task {
            try? await Task.sleep(for: .seconds(2.6))
            if toast == text { toast = nil }
        }
    }

    private func hero(_ f: HomeFigures, metrics given: GaugeMetrics, extendsSky: Bool = false) -> some View {
        // The phone's column has a hero of its own height on each tab; other windows keep theirs.
        let metrics = given == .standard ? GaugeMetrics.phone(for: f.shown) : given
        let scale = scaleGauge(f)
        let onToday = f.shown == .today
        let g = onToday ? HomeGauge.today(f.stretch) : scale
        let place = GaugeHero.Place(fraction: scale.fraction, arcFraction: f.stretch.fraction, arcMix: onToday ? 1 : 0)
        let face: SunFace = onToday ? (winking ? .wink : .happy)
                                    : (countingTotal != nil || g.reachedTop ? .celebrate : .happy)
        return GaugeHero(gauge: g, fraction: place.fraction, arcFraction: place.arcFraction, arcMix: place.arcMix,
                         face: face, isRunning: onScreen && scenePhase == .active && !showTimer, glides: false,
                         extendsSky: extendsSky, metrics: metrics, final: place, dayReadings: dayReadings(f.now))
            // The sun and sea change tabs with a clean cut: no glide, no cross-fade, so the water never shows through.
            .transaction { $0.animation = nil }
    }

    /// The small navy note at the hero's top right.
    @ViewBuilder private var toastView: some View {
        if let toast {
            Text(toast)
                .lgText(LGTextStyle(size: 13, weight: .semibold, relativeTo: .subheadline), color: .white)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(LGColor.ink, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: LGColor.ink.opacity(0.25), radius: 8, y: 6)
                .padding(.top, 12).padding(.trailing, 20)
                .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                .accessibilityAddTraits(.updatesFrequently)
        }
    }

    /// The big number; each tab's replaces the other's with a cross-fade, stacked so the page doesn't jump.
    private func number(_ f: HomeFigures, style: NumberLayout) -> some View {
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
    }

    /// Phone and short window: one column. The craft name with History and + stays on top as a bar while the page
    /// scrolls under it, and the buttons stay pinned under the page.
    private func columnPage(_ f: HomeFigures, short: Bool) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                hero(f, metrics: short ? .short : .standard, extendsSky: true)
                    .overlay(alignment: .topTrailing) { toastView }
                    .padding(.top, short ? 2 : 8)
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
                        weekContent(f.summary, now: f.now, showBars: !short)
                            .transition(.opacity)
                    case .longGame:
                        longGameContent(f.summary, now: f.now)
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
        .lgTopBar(transparent: f.shown == .longGame) {
            VStack(spacing: 0) {
                header(dark: f.shown == .longGame)
                    .padding(.top, short ? 0 : 8)
                // The tabs stay pinned under the craft name; only the page below them scrolls.
                LGSegmentedControl(items: HomeTab.allCases, selection: tab, label: "Home view", title: Self.title, onSelect: selectTab)
                    .padding(.top, short ? 4 : 10).padding(.bottom, 4)
            }
            .padding(.horizontal, 24)
            .lgReadableColumn(560)
            .environment(\.lgOnDark, f.shown == .longGame)
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
                LGSegmentedControl(items: HomeTab.allCases, selection: tab, label: "Home view", title: Self.title, onSelect: selectTab)
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
                            weekContent(f.summary, now: f.now, showBars: true)
                            wideStatsRow(f.summary, now: f.now, total: f.total)
                        case .longGame:
                            longGameContent(f.summary, now: f.now)
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
            stat(ForecastText.homeMastery(s.forecast.chosen, now: now), "Finish line")
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

    /// "1 h 05 of 1 h 45 · 40 m to the moon" for the Today card.
    private func todayLine(_ stretch: StretchState) -> String {
        switch stretch {
        case .inProgress(let target, let done):
            "\(StretchText.clock(seconds: done)) of \(StretchText.clock(seconds: target)) · \(StretchText.toGo(target - done))"
        case .covered(let target, let done):
            "\(StretchText.clock(seconds: done)) of \(StretchText.clock(seconds: target))"
        case .noTarget:
            ""
        }
    }

    private func numbersCard(_ f: HomeFigures) -> some View {
        let added = WeeklyTarget.addedByEnd(target, now: f.now)
        let records = sessions.map(\.record)
        let rhythm = Rhythm.compute(daily: IPadFigures.daily(records), since: craft.createdAt, now: f.now, weekStart: weekStart)
        return IPadNumbersCard(
            pace: target.map { DurationFormat.perWeek($0.hoursPerWeek) } ?? DurationFormat.perWeek(f.summary.pace),
            finish: ForecastText.homeMastery(f.summary.forecast.chosen, now: f.now),
            byValue: added.map { "+\(DurationFormat.grouped(Int($0.rounded()))) h" } ?? "–",
            byLabel: target.map { "By \(DateText.monthYear($0.end))" } ?? "Year of pace",
            rhythm: IPadFigures.rhythmText(daysPerWeek: rhythm.daysPerWeek))
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
                    DayBarsRow(bars: weekBars(f.now)) { day in historyDay = day }
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
        if f.shown == .longGame { yearRow(now: f.now) }
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
            LGSegmentedControl(items: HomeTab.allCases, selection: tab, label: "Home view", title: Self.title, onSelect: selectTab)
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

    private func header(dark: Bool = false) -> some View {
        HStack {
            Text(craft.name).lgText(.screenTitle, color: dark ? .white : LGColor.ink)
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
        .frame(minHeight: 44)
    }

    private static func title(_ tab: HomeTab) -> LocalizedStringKey {
        switch tab {
        case .today: "Today"
        case .week: "This week"
        case .longGame: "The long game"
        }
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

    private func weekContent(_ s: ProgressSummary, now: Date, showBars: Bool) -> some View {
        VStack(spacing: 0) {
            if showBars {
                DayBarsRow(bars: weekBars(now)) { day in
                    historyDay = day
                }
                .padding(.top, 18)
            }
            targetRow(s, now: now)
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

    private func longGameContent(_ s: ProgressSummary, now: Date) -> some View {
        VStack(spacing: 0) {
            statsRow(s, now: now)
                .padding(.top, 18)
            futureSelfRow
            yearRow(now: now)
        }
    }

    /// From 1 December to 15 January only: the year card, under "Meet your future self". No notification.
    @ViewBuilder
    private func yearRow(now: Date) -> some View {
        if YearSummary.showsOnLongGame(now: now) {
            let year = YearSummary.defaultYear(now: now)
            let summary = YearSummary.make(year: year, sessions: sessions.map(\.record), estimates: estimates.map(\.rate),
                                           onboardingDate: craft.createdAt, now: now, weekStart: weekStart)
            if summary.hasEnoughData {
                NavigationLink {
                    YearScreen(craft: craft, sessions: sessions, estimates: estimates, weekStart: weekStart, year: year)
                } label: {
                    YearEntryRow(year: year)
                }
                .buttonStyle(.plain)
                .overlay(alignment: .top) { Rectangle().fill(LGColor.hairline).frame(height: 1) }
            }
        }
    }

    /// Pace, what the weekly target still adds by the end of its year, and the finish line.
    private func statsRow(_ s: ProgressSummary, now: Date) -> some View {
        let added = WeeklyTarget.addedByEnd(target, now: now)
        return HStack(spacing: 0) {
            stat(DurationFormat.perWeek(s.pace), "Pace")
            if let target, let added {
                stat("+\(DurationFormat.grouped(Int(added.rounded()))) h", "By \(DateText.monthYear(target.end))")
            } else {
                stat("–", "Year of pace")
            }
            stat(ForecastText.homeMastery(s.forecast.chosen, now: now), "Finish line")
        }
        .padding(.vertical, 14)
        .overlay(alignment: .top) { Rectangle().fill(LGColor.hairline).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(LGColor.hairline).frame(height: 1) }
    }

    /// Under the stats: opens "Meet your future self".
    private var futureSelfRow: some View {
        Button { sheet = .futureSelf } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Meet your future self").lgText(.rowStrong)
                    Text("Where 10,000 hours can take you").lgText(.caption, color: LGColor.inkMuted)
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
    private func showTargetSheetOnce() {
        guard let settings = settingsRows.first, sheet == nil, catchUpGap == nil, !showTimer,
              TargetCycle.shouldOpenSheet(settings.currentTarget, promptShownAt: settings.targetPromptShownAt, now: Date())
        else { return }
        settings.targetPromptShownAt = Date()
        try? context.save()
        sheet = .target(first: settings.currentTarget == nil)
    }

    private func stat(_ value: String, _ label: LocalizedStringKey) -> some View {
        VStack(spacing: 4) {
            Text(value).lgNumber(.statValue)
            Text(label).lgText(.caption, color: LGColor.inkMuted)
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

    private func checkMilestones(total: Double) {
        if settingsRows.isEmpty {
            context.insert(AppSettings())
            try? context.save()
            return
        }
        guard let settings = settingsRows.first else { return }
        let crossed = Milestones.newlyCrossed(total: total, seen: settings.milestonesSeen)
        guard let top = crossed.max() else { return }
        settings.milestonesSeen.append(contentsOf: crossed)
        try? context.save()
        if top >= IconPlan.heldBelow { iconHeld = true }
        Task {
            // let a saved session's count-up finish first
            try? await Task.sleep(for: .seconds(1.6))
            offerSupport = shouldOfferSupport(settings)
            celebrating = top
        }
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

    private func enableDailyReminder() {
        UserDefaults.standard.set(true, forKey: "notifications.asked")
        Task {
            guard await Notifications.requestAuthorization(), let settings = settingsRows.first else { return }
            settings.reminderTime = Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: Date())
            try? context.save()
            refreshNotifications()
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
            Notifications.scheduleMilestone(at: next.date, message: Milestones.message(hours: next.hours, craft: craft.name))
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
            let played = tab == .today && !TodaySessions.startedToday(sessions, start: \.start, now: now).isEmpty
            return tab == .today && !played ? "Begin" : "Start session"
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
