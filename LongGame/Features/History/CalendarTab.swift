import SwiftUI
import SwiftData

struct CalendarTab: View {
    let craft: Craft
    let sessions: [Session]
    let weekStart: WeekStart

    @State private var selected: Date
    @State private var editing: Session?
    @State private var explaining: StatInfo?
    /// The session whose photo is open full screen.
    @State private var viewing: Session?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var isAccessibilitySize: Bool { dynamicTypeSize.isAccessibilitySize }

    init(craft: Craft, sessions: [Session], weekStart: WeekStart, initialDay: Date? = nil) {
        self.craft = craft
        self.sessions = sessions
        self.weekStart = weekStart
        _selected = State(initialValue: Calendar.current.startOfDay(for: initialDay ?? Date()))
    }

    private let cell: CGFloat = 14
    private let gap: CGFloat = 4
    private var calendar: Calendar { .current }

    var body: some View {
        let now = Date()
        let weeks = CalendarGrid.weeks(endingOn: now, weekStart: weekStart, calendar: calendar)
        let daily = Practice.dailySeconds(sessions.map(\.record), calendar: calendar)
        let windowStart = weeks.first?.first ?? now

        VStack(spacing: 14) {
            gridCard(weeks: weeks, daily: daily, windowStart: windowStart, now: now)
            statsCard(daily: daily, windowStart: windowStart, now: now)
            dayCard(daily: daily, now: now)
        }
        .sheet(item: $editing) { session in
            SessionFormView(craft: craft, sessions: sessions, editing: session)
                .lgSheetCard()
        }
        .sheet(item: $explaining) { info in
            StatExplainer(info: info)
                .lgSheetCard()
        }
        .fullScreenCover(item: $viewing) { session in
            PhotoViewer(sessions: photoSessions, startAt: session)
        }
    }

    /// Every session with a photo, oldest first (the newest is last in the viewer).
    private var photoSessions: [Session] {
        sessions.filter(\.hasPhoto).sorted { $0.start < $1.start }
    }

    // MARK: Grid

    private func gridCard(weeks: [[Date]], daily: [Date: Double], windowStart: Date, now: Date) -> some View {
        let today = calendar.startOfDay(for: now)
        let photoDays = SessionPhotos.daysWithPhoto(sessions.map { ($0.start, $0.hasPhoto) }, calendar: calendar)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 4) {
                weekdayLabels(weeks: weeks)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: gap) {
                        let labels = monthLabels(weeks: weeks)
                        ForEach(Array(weeks.enumerated()), id: \.offset) { index, week in
                            VStack(spacing: gap) {
                                Text(labels[index] ?? "")
                                    .lgText(LGTextStyle(size: 11, weight: .semibold, relativeTo: .caption2), color: LGColor.inkMuted)
                                    .fixedSize()
                                    .dynamicTypeSize(...DynamicTypeSize.xLarge)
                                    .frame(width: cell, height: cell, alignment: .leading)
                                    .accessibilityHidden(true)
                                ForEach(week, id: \.self) { day in
                                    dayCell(day, daily: daily, today: today, hasPhoto: photoDays.contains(day))
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 4).padding(.vertical, 4)
                }
                .defaultScrollAnchor(.trailing)
            }

            // At the accessibility sizes the legend stacks, so "Less" and "More" never break mid-word.
            let legend = isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                : AnyLayout(HStackLayout())
            legend {
                legendSwatch(.rest, "Rest is part of the craft.")
                if !isAccessibilitySize { Spacer() }
                HStack(spacing: 4) {
                    Text("Less").lgText(.tiny, color: LGColor.inkMuted).padding(.trailing, 4)
                    ForEach(CalendarLevel.allCases.dropFirst(), id: \.self) { CalendarLevelMark(level: $0, size: 12) }
                    Text("More").lgText(.tiny, color: LGColor.inkMuted).padding(.leading, 4)
                }
            }
            .accessibilityHidden(true)

            // Only once there is a photo: what the white dot means.
            if !photoDays.isEmpty {
                HStack(spacing: 8) {
                    CalendarLevelMark(level: .from2to3, size: 12, hasPhoto: true)
                    Text("White dot: a day with a photo").lgText(.tiny, color: LGColor.inkMuted)
                }
                .padding(.top, -4)
                .accessibilityHidden(true)
            }
        }
        .padding(16)
        .lgCard(radius: 22)
    }

    private func dayCell(_ day: Date, daily: [Date: Double], today: Date, hasPhoto: Bool) -> some View {
        let isFuture = day > today
        let seconds = daily[day] ?? 0
        let level = CalendarLevel.level(hours: seconds / 3600)
        let isSelected = day == selected
        return Button { if !isFuture { selected = day } } label: {
            // Future days are left empty; every other day is its level's shape (a rest day is the small dot).
            Group {
                if isFuture { Color.clear } else { CalendarLevelMark(level: level, size: cell, hasPhoto: hasPhoto) }
            }
            .frame(width: cell, height: cell)
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 5.5)
                            .stroke(LGColor.ink, lineWidth: 1.5)
                            .padding(-3)
                    }
                }
                // The touch area reaches halfway into the gaps, so neighbouring days never overlap.
                .contentShape(Rectangle().inset(by: -gap / 2))
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .accessibilityLabel(Self.spoken(day, seconds: seconds, calendar: calendar, hasPhoto: hasPhoto))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHidden(isFuture)
    }

    private func weekdayLabels(weeks: [[Date]]) -> some View {
        VStack(alignment: .leading, spacing: gap) {
            Color.clear.frame(width: 1, height: cell)
            ForEach(Array((weeks.first ?? []).enumerated()), id: \.offset) { _, date in
                // M, W and F, plus the last row: single letters, as on the board.
                let weekday = calendar.component(.weekday, from: date)
                let isLastRow = date == weeks.first?.last
                Text([2, 4, 6].contains(weekday) || (isLastRow && [1, 7].contains(weekday)) ? Self.weekdayLetter(date, calendar) : "")
                    .lgText(LGTextStyle(size: 9, weight: .semibold, relativeTo: .caption2), color: LGColor.inkMuted)
                    .fixedSize()
                    .dynamicTypeSize(...DynamicTypeSize.xLarge)
                    .frame(height: cell, alignment: .leading)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityHidden(true)
    }

    private func legendSwatch(_ level: CalendarLevel, _ title: String) -> some View {
        HStack(spacing: 8) {
            CalendarLevelMark(level: level, size: 12)
            Text(title).lgText(.tiny, color: LGColor.inkMuted)
        }
    }

    private func monthLabels(weeks: [[Date]]) -> [Int: String] {
        var result: [Int: String] = [:]
        var lastMonth = -1
        for (i, week) in weeks.enumerated() {
            guard let first = week.first else { continue }
            let c = calendar.dateComponents([.day, .month], from: first)
            if (c.day ?? 99) <= 7, c.month != lastMonth {
                result[i] = Self.shortMonth(first, calendar)
                lastMonth = c.month ?? -1
            }
        }
        return result
    }

    // MARK: Day detail

    private func dayCard(daily: [Date: Double], now: Date) -> some View {
        let day = selected
        let daySessions = sessions
            .filter { calendar.isDate($0.start, inSameDayAs: day) }
            .sorted { $0.start < $1.start }
        let seconds = daily[day] ?? 0
        let firstNote = daySessions.compactMap(\.note).first(where: { !$0.isEmpty })
        let afterBreak = !daySessions.isEmpty && daySessions.allSatisfy { $0.source == .catchUp }

        return VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(RelativeDay.full(day, calendar: calendar))
                        .lgText(LGTextStyle(size: 16, weight: .semibold, relativeTo: .body))
                    Spacer(minLength: 8)
                    if seconds > 0 {
                        Text(TodaySessions.duration(seconds))
                            .lgText(LGTextStyle(size: 16, weight: .bold, relativeTo: .body))
                    }
                }
                if daySessions.isEmpty {
                    Text("Rest day").lgText(.caption, color: LGColor.inkMuted)
                } else if afterBreak {
                    Text("Added after a break").lgText(.caption, color: LGColor.inkMuted)
                }
            }
            .accessibilityElement(children: .combine)

            ForEach(daySessions, id: \.persistentModelID) { session in
                sessionRow(session)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lgCard(radius: 22)
    }

    /// One session in the day card: its photo or drawn picture (56 pt), then "Evening · 1 h 15" over its note, or a
    /// quiet "No note". Tapping the photo opens it full screen; tapping anywhere else edits the session.
    private func sessionRow(_ session: Session) -> some View {
        HStack(alignment: .center, spacing: 12) {
            if session.hasPhoto, let data = session.photo {
                Button { viewing = session } label: {
                    PhotoThumb(id: session.id, data: data, side: 56, radius: 12)
                        .frame(minWidth: 56, minHeight: 56)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(SessionPhotos.spokenLabel(start: session.start))
                .accessibilityHint("Opens the photo")
            } else if !session.hidesDefaultPicture {
                SessionPictureThumb(id: session.id, start: session.start, durationSec: session.durationSec,
                                    progress: session.sunriseProgressAtEnd ?? 0, side: 56, radius: 12)
            }
            Button { editing = session } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(sessionTitle(session)) · \(TodaySessions.duration(session.durationSec))")
                        .lgText(LGTextStyle(size: 14, weight: .semibold, relativeTo: .subheadline))
                    if let note = session.note, !note.isEmpty {
                        Text(note)
                            .lgText(.caption, color: LGColor.inkMuted)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    } else {
                        Text("No note").lgText(.caption, color: LGColor.gaugeLabel)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Edit or delete this session")
        }
    }

    /// "Morning", "Evening"… for a timed session; hours typed in later have no real time of day.
    private func sessionTitle(_ s: Session) -> String {
        if s.source == .catchUp { return String(localized: "Added after a break") }
        if s.source == .manual { return String(localized: "Added hours") }
        let c = calendar.dateComponents([.hour, .minute], from: s.start)
        let part = SessionDaypart.at(startHour: Double(c.hour ?? 0) + Double(c.minute ?? 0) / 60)
        return part.rawValue.prefix(1).uppercased() + part.rawValue.dropFirst()
    }

    // MARK: Stats

    private func statsCard(daily: [Date: Double], windowStart: Date, now: Date) -> some View {
        let rhythm = Rhythm.compute(daily: daily, since: craft.createdAt, now: now, weekStart: weekStart, calendar: calendar)
        let active = Practice.activeDays(daily: daily, from: windowStart, to: now, calendar: calendar)
        let needed = max(1, rhythm.daysPerWeek - 1)
        // A plain row between two hairlines, the middle figure between two more: no card.
        return HStack(spacing: 0) {
            stat(rhythm.daysPerWeek > 0 ? Labels.daysPerWeek(rhythm.daysPerWeek) : "–", "Rhythm", info: .rhythm)
            stat(rhythm.daysPerWeek > 0 ? Labels.weeks(rhythm.steadyWeeks) : "–", "Steady for",
                 info: .steady(daysNeeded: rhythm.daysPerWeek > 0 ? needed : nil))
                .overlay(alignment: .leading) { Rectangle().fill(LGColor.hairline).frame(width: 1) }
                .overlay(alignment: .trailing) { Rectangle().fill(LGColor.hairline).frame(width: 1) }
            stat("\(active)", "Active days", info: .active)
        }
        .padding(.vertical, 12)
        .fixedSize(horizontal: false, vertical: true)
        .overlay(alignment: .top) { Rectangle().fill(LGColor.hairline).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(LGColor.hairline).frame(height: 1) }
    }

    /// Tapping a stat explains how it is worked out.
    private func stat(_ value: String, _ label: String, info: StatInfo) -> some View {
        Button { explaining = info } label: {
            VStack(spacing: 2) {
                Text(label).lgText(.statLabel, color: LGColor.inkMuted)
                Text(value).lgNumber(.statFigure)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Shows how this is worked out")
    }

    // MARK: Formatting

    private static func formatter(_ format: String, _ calendar: Calendar) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.dateFormat = format
        return f
    }

    private static func weekdayLetter(_ d: Date, _ c: Calendar) -> String { formatter("EEEEE", c).string(from: d) }
    private static func shortMonth(_ d: Date, _ c: Calendar) -> String { formatter("MMM", c).string(from: d) }

    /// "Thursday 22 October. 2 hours, a good day. Has a photo." or "Thursday 22 October. Rest day."
    static func spoken(_ day: Date, seconds: Double, calendar: Calendar, hasPhoto: Bool = false) -> String {
        SunSpeech.calendarDay(date: formatter("EEEE d MMMM", calendar).string(from: day), seconds: seconds, hasPhoto: hasPhoto)
    }
}

/// What each Calendar stat means, shown when it is tapped.
enum StatInfo: Identifiable {
    case rhythm
    case steady(daysNeeded: Int?)
    case active

    var id: String {
        switch self {
        case .rhythm: "rhythm"
        case .steady: "steady"
        case .active: "active"
        }
    }

    var title: String {
        switch self {
        case .rhythm: "Rhythm"
        case .steady: "Steady for"
        case .active: "Active days"
        }
    }

    var paragraphs: [String] {
        switch self {
        case .rhythm:
            ["Your typical number of practice days in a week.",
             "For each of the last 8 full weeks, and this week so far, we count the days with any time logged. Rhythm is the middle of those numbers, so one busy or quiet week barely moves it.",
             "Weeks from before you began aren't counted."]
        case .steady(let needed):
            ["How many weeks in a row, counting back from this week, you practised on at least one day fewer than your Rhythm.",
             needed.map { "Right now that means \($0) \($0 == 1 ? "day" : "days") a week." } ?? "Once you have a Rhythm, this shows how long you've kept it up.",
             "This week counts once it gets there, and it never ends your run while it's still going. Nothing ever breaks: a quiet week just starts a new run."]
        case .active:
            ["The number of days with any practice in the last 12 months, the same days you see lit up in the grid above.",
             "Hours added after a break count like any other."]
        }
    }
}

private struct StatExplainer: View {
    let info: StatInfo
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(info.title).lgText(.sheetTitle)
                .accessibilityAddTraits(.isHeader)
            ForEach(info.paragraphs, id: \.self) { text in
                Text(text).lgText(.body, color: LGColor.inkMuted)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button("Got it") { dismiss() }.buttonStyle(.lg(.primary))
        }
        .padding(.horizontal, 24).padding(.top, 28).padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(LGColor.background)
        .presentationDetents([.height(400), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
    }
}

