import SwiftUI
import SwiftData

/// The weekly look-back (`design/redesign/WeekLookBack.dc.html`): the first open of a new week, once, if last week had
/// a session. Calm words whatever the total; the comparison line only shows when the week was up.
struct WeekLookBackSheet: View {
    let craft: Craft
    let look: WeekLookBack
    /// The weekly pace that applied last week ("of your 12 h pace"); nil shows the hours alone.
    let lastWeekPace: Double?
    /// The pace for this week ("This week: 12 h, about 1 h 45 a day."); nil leaves the line out.
    let thisWeekPace: Double?
    /// The long game now, and the hours added since last week ended (this week so far).
    let total: Double
    let thisWeekSoFar: Double
    /// "Nov 2035".
    let finish: String
    let sessions: [Session]
    let onChangePace: () -> Void
    /// Previews and the render check draw the page without its scroll view.
    var scrolls = true

    @Environment(\.dismiss) private var dismiss
    @State private var viewing: Session?
    @State private var editing: Session?

    private var momentSession: Session? {
        guard let id = look.moment?.sessionId else { return nil }
        return sessions.first { $0.id == id }
    }

    var body: some View {
        Group {
            if scrolls { ScrollView { page }.scrollBounceBehavior(.basedOnSize) } else { page }
        }
        .background(LGColor.background)
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(30)
        .fullScreenCover(item: $viewing) { session in
            PhotoViewer(sessions: sessions.filter(\.hasPhoto).sorted { $0.start < $1.start }, startAt: session)
        }
        .sheet(item: $editing) { session in
            SessionFormView(craft: craft, sessions: sessions, editing: session).lgSheetCard()
        }
    }

    private var page: some View {
            VStack(alignment: .leading, spacing: 0) {
                SceneHero(tone: .day, height: 166, skyHeight: 110, horizon: 0.84, landTop: 46, sunSize: 90, sunTop: 32,
                          face: .happy, hidden: true)
                    .padding(.horizontal, -24)

                HStack(alignment: .firstTextBaseline) {
                    Text("LAST WEEK")
                        .lgText(LGTextStyle(size: 12, weight: .semibold, relativeTo: .caption, tracking: 1.7), color: LGColor.finishLabel)
                    Spacer()
                    Text(verbatim: look.dates()).lgText(.caption, color: LGColor.inkMuted)
                }
                .accessibilityElement(children: .combine)

                headline.padding(.top, 8)

                if let more = look.moreThanBefore {
                    Text("\(StretchText.clock(seconds: more)) more than the week before.")
                        .lgText(LGTextStyle(size: 14, weight: .semibold, relativeTo: .subheadline), color: LGColor.ember)
                        .padding(.top, 6)
                }

                bars.padding(.top, 12)
                figures.padding(.top, 14)
                if let moment = look.moment { momentCard(moment).padding(.top, 14) }
                longGame.padding(.top, 14)

                if let pace = thisWeekPace, pace > 0 {
                    Text("This week: \(WeeklyTarget.number(pace)) h, about \(StretchText.clock(seconds: Stretch.stretch(weeklyHours: pace))) a day.")
                        .lgText(LGTextStyle(size: 14, weight: .regular, relativeTo: .subheadline), color: LGColor.inkMuted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 24)
                }

                Button("Start the week") { dismiss() }
                    .buttonStyle(.lg(.primary))
                    .padding(.top, 12)
                Button("Change my pace") {
                    dismiss()
                    onChangePace()
                }
                .buttonStyle(.lg(.text))
                .padding(.top, 2)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
    }

    // MARK: Pieces

    private var headline: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(verbatim: StretchText.clock(seconds: (look.hours * 3600).rounded()))
                .lgNumber(LGTextStyle(size: 48, weight: .bold, relativeTo: .largeTitle, tracking: -2.2))
            if let pace = lastWeekPace, pace > 0 {
                Text("of your \(WeeklyTarget.number(pace)) h pace")
                    .lgText(LGTextStyle(size: 15, weight: .regular, relativeTo: .body), color: LGColor.inkMuted)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// Gold bars on a scale where the longest day is the tallest; rest days a small pale dot; only the longest day
    /// carries its hours, in ember, with its letter in bold.
    private var bars: some View {
        let top = max(look.dayHours.max() ?? 0, 0.01)
        let letters = CachedFormatter.pattern("EEEEE", calendar: .current)
        return HStack(spacing: 8) {
            ForEach(look.days.indices, id: \.self) { i in
                let longest = i == look.longestDay
                VStack(spacing: 6) {
                    Text(verbatim: longest ? StretchText.clock(seconds: (look.dayHours[i] * 3600).rounded()) : " ")
                        .lgText(LGTextStyle(size: 11, weight: .bold, relativeTo: .caption2), color: LGColor.ember)
                        .lineLimit(1).minimumScaleFactor(0.6)
                        .frame(height: 14)
                    ZStack(alignment: .bottom) {
                        Color.clear.frame(width: 22, height: 64)
                        if look.dayHours[i] > 0 {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(LinearGradient(colors: [LGColor.dayBarTop, LGColor.amber], startPoint: .top, endPoint: .bottom))
                                .frame(width: 22, height: max(6, 64 * look.dayHours[i] / top))
                                .shadow(color: LGColor.amber.opacity(0.3), radius: 5, y: 4)
                        } else {
                            Circle().fill(LGColor.rest).frame(width: 6, height: 6)
                        }
                    }
                    Text(verbatim: letters.string(from: look.days[i]))
                        .lgText(LGTextStyle(size: 12, weight: longest ? .bold : .medium, relativeTo: .caption),
                                color: longest ? LGColor.ink : LGColor.inkMuted)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: look.spokenBars()))
    }

    private var figures: some View {
        HStack(spacing: 0) {
            figure("Days played", String(localized: "\(look.daysPlayed) of 7"))
            Rectangle().fill(LGColor.hairline).frame(width: 1)
            figure("Longest day", look.longestDayText() ?? "–")
            Rectangle().fill(LGColor.hairline).frame(width: 1)
            figure("Mostly", look.mostly?.plural ?? "–")
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 12)
        .overlay(alignment: .top) { Rectangle().fill(LGColor.hairline).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(LGColor.hairline).frame(height: 1) }
    }

    private func figure(_ title: LocalizedStringKey, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(title).lgText(.caption, color: LGColor.inkMuted)
            Text(verbatim: value)
                .lgText(LGTextStyle(size: 17, weight: .bold, relativeTo: .headline))
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func momentCard(_ moment: WeekLookBack.Moment) -> some View {
        Button {
            guard let session = momentSession else { return }
            if moment.kind == .photo { viewing = session } else { editing = session }
        } label: {
            HStack(spacing: 12) {
                Group {
                    if moment.kind == .photo, let data = momentSession?.photo {
                        PhotoThumb(id: moment.sessionId, data: data, side: 56, radius: 12)
                    } else {
                        SessionPictureThumb(id: moment.sessionId, start: moment.start, durationSec: moment.seconds,
                                            progress: momentSession?.sunriseProgressAtEnd ?? 0, side: 56, radius: 12)
                    }
                }
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: look.momentWhen() ?? "").lgText(.caption, color: LGColor.inkMuted)
                    Text(verbatim: look.momentLine() ?? "")
                        .lgText(LGTextStyle(size: 15, weight: .semibold, relativeTo: .body))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lgCard(radius: 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(moment.kind == .photo ? Text("Opens the photo") : Text("Opens the session"))
    }

    /// "3,294 h · finish line Nov 2035" and a thin bar: navy for the total before the week, a glowing gold tip for
    /// what the week added.
    private var longGame: some View {
        let endOfWeek = max(0, total - thisWeekSoFar)
        let before = max(0, endOfWeek - look.hours)
        return VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("The long game").lgText(LGTextStyle(size: 13, weight: .regular, relativeTo: .footnote), color: LGColor.inkMuted)
                Spacer()
                Text("\(DurationFormat.grouped(Int(endOfWeek.rounded(.down)))) h · finish line \(finish)")
                    .lgText(LGTextStyle(size: 13, weight: .semibold, relativeTo: .footnote))
            }
            .accessibilityElement(children: .combine)
            GeometryReader { geo in
                let w = geo.size.width
                let a = w * min(1, before / Totals.goalHours)
                let b = max(5, w * min(1, look.hours / Totals.goalHours))
                ZStack(alignment: .leading) {
                    Capsule().fill(LGColor.chipBorder)
                    Capsule().fill(LGColor.ink).frame(width: a)
                    Capsule()
                        .fill(LinearGradient(colors: [LGColor.timerGold, LGColor.amber], startPoint: .leading, endPoint: .trailing))
                        .frame(width: b)
                        .shadow(color: LGColor.amber.opacity(0.6), radius: 3)
                        .offset(x: a)
                }
            }
            .frame(height: 6)
            .accessibilityHidden(true)
        }
    }
}
