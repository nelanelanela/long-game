import SwiftUI
import SwiftData

private enum HomeSheet: Identifiable {
    case addHours, oneCraft, edit(Session)

    var id: String {
        switch self {
        case .addHours: "add"
        case .oneCraft: "one"
        case .edit(let s): "edit-\(s.persistentModelID.hashValue)"
        }
    }
}

struct HomeView: View {
    let craft: Craft

    @Query private var sessions: [Session]
    @Query private var estimates: [YearEstimate]
    @Query private var settingsRows: [AppSettings]
    @Environment(\.modelContext) private var context
    @Environment(TimerStore.self) private var timer
    @Environment(\.scenePhase) private var scenePhase
    @State private var celebrating: Int?
    @State private var askAboutReminders = false
    @State private var sheet: HomeSheet?
    @State private var showTimer = false
    @State private var totalBeforeTimer = 0.0
    /// While set, Home shows this instead of the real total (the count-up after a save).
    @State private var countingTotal: Double?
    @State private var catchUpGap: CatchUp.Gap?
    @State private var totalBeforeCatchUp = 0.0

    init(craft: Craft) {
        self.craft = craft
        let id = craft.id
        _sessions = Query(filter: #Predicate<Session> { $0.craftId == id }, sort: \Session.start, order: .reverse)
        _estimates = Query(filter: #Predicate<YearEstimate> { $0.craftId == id })
    }

    private var weekStart: WeekStart { settingsRows.first?.weekStart ?? .localeDefault }

    private func summary(now: Date) -> ProgressSummary {
        ProgressSummary.make(estimates: estimates.map(\.rate), sessions: sessions.map(\.record),
                             onboardingDate: craft.createdAt, weekStart: weekStart, now: now)
    }

    var body: some View {
        let now = Date()
        let s = summary(now: now)
        ScrollView {
            VStack(spacing: 20) {
                header
                SunriseCard(total: countingTotal ?? s.total, face: countingTotal == nil ? .happy : .celebrate)
                statsRow(s, now: now)
                recent(now: now)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .safeAreaInset(edge: .bottom) { actionBar }
        .lgScreen()
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(isPresented: $showTimer, onDismiss: timerDismissed) {
            TimerView(craft: craft, baseTotal: totalBeforeTimer)
        }
        .onChange(of: timer.finishRequested) { _, requested in
            if requested { openTimer(total: s.total) }
        }
        .onAppear {
            if timer.finishRequested { openTimer(total: s.total) }
            checkMilestones(total: s.total)
            refreshNotifications()
            checkCatchUp(summary: s)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { checkCatchUp(summary: summary(now: Date())) }
        }
        .sheet(item: $catchUpGap) { gap in
            CatchUpSheet(craft: craft, gap: gap, pace: totalPace, onFinish: catchUpFinished)
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
            switch item {
            case .addHours:
                SessionFormView(craft: craft, sessions: sessions, editing: nil)
            case .edit(let session):
                SessionFormView(craft: craft, sessions: sessions, editing: session)
            case .oneCraft:
                OneCraftSheet(craft: craft, totalHours: s.wholeHours)
            }
        }
    }

    // MARK: Pieces

    private var header: some View {
        HStack {
            Text(craft.name).lgText(.screenTitle)
                .lineLimit(1).minimumScaleFactor(0.6)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            HStack(spacing: 0) {
                NavigationLink {
                    SettingsView(craft: craft)
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 19, weight: .regular))
                        .foregroundStyle(LGColor.ink)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Settings")
                NavigationLink {
                    HistoryView(craft: craft)
                } label: {
                    Image(systemName: "calendar")
                        .font(.system(size: 19, weight: .regular))
                        .foregroundStyle(LGColor.ink)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("History")
                LGIconButton(systemName: "plus", label: "Add a craft") { sheet = .oneCraft }
            }
            .padding(.trailing, -10)
        }
        .frame(minHeight: 44)
    }

    private func statsRow(_ s: ProgressSummary, now: Date) -> some View {
        HStack(spacing: 0) {
            stat(DurationFormat.hours(s.thisWeek), "This week")
            Divider().overlay(LGColor.divider)
            stat(DurationFormat.perWeek(s.pace), "Pace")
            Divider().overlay(LGColor.divider)
            stat(ForecastText.homeMastery(s.forecast.mid, now: now), "Finish line")
        }
        .padding(.vertical, 18)
        .fixedSize(horizontal: false, vertical: true)
        .lgCard()
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).lgNumber(.statValue)
            Text(label).lgText(.caption, color: LGColor.inkMuted)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func recent(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            LGSectionLabel("Recent")
            if sessions.isEmpty {
                VStack(spacing: 8) {
                    SunView(face: .sleepy).frame(width: 64, height: 64)
                    Text("No sessions yet. Start one, or add past hours.")
                        .lgText(.row, color: LGColor.inkMuted).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).padding(20).lgCard()
            } else {
                let recent = Array(sessions.prefix(5))
                VStack(spacing: 0) {
                    ForEach(Array(recent.enumerated()), id: \.element.persistentModelID) { index, session in
                        Button { sheet = .edit(session) } label: {
                            HStack {
                                Text(RelativeDay.label(session.start, now: now)).lgText(.row)
                                Spacer()
                                Text(DurationFormat.short(seconds: session.durationSec))
                                    .lgText(.row, color: LGColor.inkMuted)
                            }
                            .frame(minHeight: 52)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Edit this session")
                        if index < recent.count - 1 { Divider().overlay(LGColor.divider) }
                    }
                }
                .padding(.horizontal, 18)
                .lgCard()
            }
        }
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
        let (time, days, streak) = (settings.reminderTime, settings.reminderDays, settings.streakReminder)
        Task {
            await NotificationPlanner.refresh(craftName: name, reminderTime: time, reminderDays: days,
                                              streakReminder: streak, sessions: records)
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

    private func openTimer(total: Double) {
        totalBeforeTimer = total
        if !timer.isActive { timer.start(craft: craft) }
        showTimer = true
    }

    /// After a saved session the total counts up from old to new.
    private func timerDismissed() {
        guard timer.savedSession else { return }
        timer.savedSession = false
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
        return "Resume · " + DurationFormat.clock(seconds: state.elapsed(at: now))
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button("Add past hours") { sheet = .addHours }.buttonStyle(.lg(.secondary))
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                Button(startTitle(at: timeline.date)) { openTimer(total: summary(now: Date()).total) }
                    .buttonStyle(.lg(.primary))
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(LGColor.background.opacity(0.94))
    }
}
