import SwiftUI
import SwiftData

private enum HomeSheet: Identifiable {
    case addHours, oneCraft, futureSelf
    /// The target screen as a sheet: a new year of pace, or the first target for an older game.
    case target(first: Bool)

    var id: String {
        switch self {
        case .addHours: "add"
        case .oneCraft: "one"
        case .futureSelf: "future"
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
    @State private var askAboutReminders = false
    @State private var sheet: HomeSheet?
    /// False while Home is covered or in the background: the hero stops animating.
    @State private var onScreen = true
    /// Scene storage: after the system closes and reopens a window, a running session is still in front.
    @SceneStorage("home.showTimer") private var showTimer = false
    @State private var totalBeforeTimer = 0.0
    /// While set, Home shows this instead of the real total (the count-up after a save).
    @State private var countingTotal: Double?
    @State private var catchUpGap: CatchUp.Gap?
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
                if window.shape.isWide {
                    widePage(figures, window: window)
                } else {
                    columnPage(figures, short: window.shape == .short)
                }
            }
            // Folding, unfolding or resizing moves to the matching layout; the tab, sheets and timer live above it.
            .animation(.easeInOut(duration: reduceMotion ? 0.2 : 0.35), value: window.shape)
        }
        .lgScreen()
        .toolbar(.hidden, for: .navigationBar)
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
        .modifier(TodayLive(winkWhen: figures.shown == .today && figures.stretch.isCovered && !figures.stretch.isWeekCovered,
                            ticksWhen: tab == .today && onScreen && !showTimer && scenePhase == .active,
                            everySecond: timer.isActive, winking: $winking, tick: $tick))
        .onAppear {
            onScreen = true
            chooseOpeningTab()
            if showTimer && !timer.isActive { showTimer = false }
            if timer.finishRequested { openTimer(total: s.total) }
            showFutureSelfOnce()
            showTargetSheetOnce()
            checkMilestones(total: s.total)
            refreshNotifications()
            scheduleMilestoneNotification()
            checkCatchUp(summary: s)
        }
        .onChange(of: timer.state) { _, _ in scheduleMilestoneNotification() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { checkCatchUp(summary: summary(now: Date())) }
        }
        .sheet(item: $catchUpGap) { gap in
            CatchUpSheet(craft: craft, gap: gap, pace: totalPace, onFinish: catchUpFinished)
                .lgSheetCard()
        }
        .onChange(of: s.total) { _, total in checkMilestones(total: total) }
        .onChange(of: sessions.count) { old, new in
            refreshNotifications()
            if old == 0, new == 1, !UserDefaults.standard.bool(forKey: "notifications.asked") { askAboutReminders = true }
        }
        .overlay {
            if let hours = celebrating {
                MilestoneCelebration(hours: hours, craftName: craft.name) { celebrating = nil }
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: celebrating)
        .alert("Want a gentle nudge?", isPresented: $askAboutReminders) {
            Button("Yes, remind me") { enableDailyReminder() }
            Button("Not now", role: .cancel) { UserDefaults.standard.set(true, forKey: "notifications.asked") }
        } message: {
            Text("A daily reminder at 7 pm, when the sun is waiting. You can change it in Settings.")
        }
        .sheet(item: $sheet) { item in
            Group {
            switch item {
            case .addHours:
                SessionFormView(craft: craft, sessions: sessions, editing: nil)
            case .oneCraft:
                OneCraftSheet(craft: craft, totalHours: s.wholeHours)
            case .futureSelf:
                FutureSelfSheet(total: s.total, forecast: s.forecast.mid)
            case .target(let first):
                WeeklyTargetView(mode: first ? .firstTime : .newYear,
                                 initial: first ? nil : target?.hoursPerWeek,
                                 recentPace: s.pace, summary: s, onSave: saveTarget)
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
        (f.shown.hasScale ? f.shown : lastScaleTab) == .longGame ? .longGame(total: f.total) : .week(hours: f.week, target: f.weekTarget)
    }

    private func hero(_ f: HomeFigures, metrics: GaugeMetrics) -> some View {
        let scale = scaleGauge(f)
        let onToday = f.shown == .today
        let g = onToday ? HomeGauge.today(f.stretch) : scale
        let place = GaugeHero.Place(fraction: scale.fraction, arcFraction: f.stretch.fraction, arcMix: onToday ? 1 : 0)
        let face: SunFace = onToday ? (winking ? .wink : .happy)
                                    : (countingTotal != nil || g.reachedTop ? .celebrate : .happy)
        return GaugeHero(gauge: g, fraction: place.fraction, arcFraction: place.arcFraction, arcMix: place.arcMix,
                         face: face, isRunning: onScreen && scenePhase == .active && !showTimer, glides: !reduceMotion,
                         metrics: metrics, final: place)
    }

    /// The big number; each tab's replaces the other's with a cross-fade, stacked so the page doesn't jump.
    private func number(_ f: HomeFigures, style: NumberLayout) -> some View {
        ZStack(alignment: style == .leading ? .topLeading : .top) {
            switch f.shown {
            case .today:
                TodayNumber(state: f.stretch, style: style)
                    .transition(.opacity)
            case .week:
                CountingWeek(hours: f.week, target: f.weekTarget, style: style)
                    .transition(.opacity)
            case .longGame:
                CountingTotal(value: f.total, style: style)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: style == .leading ? .leading : .center)
        .accessibilityElement(children: .combine)
    }

    /// Phone and short window: one column. The craft name with History and + stays on top as a bar while the page
    /// scrolls under it, and the buttons stay pinned under the page.
    private func columnPage(_ f: HomeFigures, short: Bool) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                LGSegmentedControl(items: HomeTab.allCases, selection: tab, label: "Home view", title: Self.title, onSelect: selectTab)
                    .padding(.horizontal, 24).padding(.top, short ? 4 : 10)
                    .id(ScrollSpot.top)
                hero(f, metrics: short ? .short : .standard)
                    .padding(.top, short ? 2 : 8)
                number(f, style: short ? .inline : .stacked)
                    .padding(.top, short ? 4 : 8)
                ZStack(alignment: .top) {
                    switch f.shown {
                    case .today:
                        TodayQuietLine(state: f.stretch)
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
        .safeAreaInset(edge: .top, spacing: 0) {
            header
                .padding(.horizontal, 24).padding(.top, short ? 0 : 8)
                .lgReadableColumn(560)
                .background(LGColor.background)
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
                header.padding(.leading, inset.leading + 24).padding(.trailing, 12)
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
            stat(ForecastText.homeMastery(s.forecast.mid, now: now), "Finish line")
        }
        .padding(.vertical, 14)
        .overlay(alignment: .top) { Rectangle().fill(LGColor.hairline).frame(height: 1) }
    }

    // MARK: Pieces

    private var header: some View {
        HStack {
            Text(craft.name).lgText(.screenTitle)
                .lineLimit(1).minimumScaleFactor(0.6)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            HStack(spacing: 0) {
                Button {
                    historyDay = Calendar.current.startOfDay(for: Date())
                } label: {
                    Image(systemName: "calendar")
                        .font(.system(size: 19, weight: .regular))
                        .foregroundStyle(LGColor.ink)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("History")
                LGIconButton(systemName: "plus", label: "Add a craft") { sheet = .oneCraft }
                LGIconButton(systemName: "gearshape", label: "Settings") { showSettings = true }
            }
            .padding(.trailing, -10)
        }
        .frame(minHeight: 44)
        // Settings has its own stack: a screen that hides the navigation bar, pushed on top of another pushed screen
        // (Settings → Your estimates), sent SwiftUI into an endless layout loop. It closes back to Home.
        .fullScreenCover(isPresented: $showSettings) {
            NavigationStack {
                SettingsView(craft: craft, closeAll: { showSettings = false })
            }
        }
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
        withAnimation(.easeInOut(duration: reduceMotion ? 0.25 : 0.6)) { tab = new }
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
                DayBarsRow(bars: WeekBars.make(sessions: sessions.map(\.record), now: now, weekStart: weekStart)) { day in
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
            WeeklyTargetView(mode: .edit, initial: target?.hoursPerWeek, recentPace: s.pace, summary: s, onSave: saveTarget)
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
            stat(ForecastText.homeMastery(s.forecast.mid, now: now), "Finish line")
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
                    .font(.system(size: 13, weight: .semibold))
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
        Task {
            // let a saved session's count-up finish first
            try? await Task.sleep(for: .seconds(1.6))
            celebrating = top
        }
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

    private func startTitle(at now: Date) -> String {
        guard let state = timer.state, state.craftId == craft.id else { return "Start session" }
        // A running timer isn't waiting to be resumed: the button takes you back to it.
        let verb = state.isPaused(at: now) ? "Resume" : "Back to session"
        return verb + " · " + DurationFormat.clock(seconds: state.elapsed(at: now))
    }

    private func actionBar(sideBySide: Bool, inset: EdgeInsets) -> some View {
        Group {
            if sideBySide {
                HStack(spacing: 14) {
                    startButton
                    Button("Add past hours") { sheet = .addHours }
                        .buttonStyle(.lg(.text))
                        .fixedSize(horizontal: true, vertical: false)
                }
            } else {
                VStack(spacing: 4) {
                    startButton
                    Button("Add past hours") { sheet = .addHours }.buttonStyle(.lg(.text))
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
