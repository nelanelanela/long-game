import AppIntents
import SwiftUI
import WidgetKit

// The sun on the Home Screen and Lock Screen. Both widgets read the shared App Group data the app writes, work out
// the numbers with the same Logic as the app, and draw the sun at its current height. They reload when the app saves,
// at midnight and when a new week starts.

// MARK: Choosing the view (small widget)

enum WidgetTab: String, AppEnum {
    case week, longGame

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "View"
    static let caseDisplayRepresentations: [WidgetTab: DisplayRepresentation] = [
        .week: "This week",
        .longGame: "The long game",
    ]

    var homeTab: HomeTab { self == .week ? .week : .longGame }
}

struct ChooseViewIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Choose the view"
    static let description = IntentDescription("Show this week's hours or the long game.")

    @Parameter(title: "Show", default: .week)
    var tab: WidgetTab
}

// MARK: Timeline

struct SunEntry: TimelineEntry {
    let date: Date
    /// Nil until the app has been set up and has shared its data.
    let state: WidgetState?
    var tab: HomeTab = .week
}

/// One timeline for both widgets: an entry now, then one at every midnight until the week turns.
private func sunTimeline(tab: HomeTab, now: Date = Date()) -> Timeline<SunEntry> {
    guard let snapshot = WidgetSnapshot.load() else {
        return Timeline(entries: [SunEntry(date: now, state: nil, tab: tab)], policy: .after(now.addingTimeInterval(3_600)))
    }
    let weekStart = WeekStart(rawValue: snapshot.weekStart) ?? .monday
    let dates = WidgetModel.timelineDates(from: now, weekStart: weekStart)
    let entries = dates.map { SunEntry(date: $0, state: WidgetModel.make(snapshot, at: $0), tab: tab) }
    return Timeline(entries: entries, policy: .atEnd)
}

struct SunProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SunEntry {
        SunEntry(date: .now, state: .sample)
    }

    func snapshot(for configuration: ChooseViewIntent, in context: Context) async -> SunEntry {
        guard !context.isPreview, let entry = sunTimeline(tab: configuration.tab.homeTab).entries.first else {
            return SunEntry(date: .now, state: .sample, tab: configuration.tab.homeTab)
        }
        return entry
    }

    func timeline(for configuration: ChooseViewIntent, in context: Context) async -> Timeline<SunEntry> {
        sunTimeline(tab: configuration.tab.homeTab)
    }
}

struct OverviewProvider: TimelineProvider {
    func placeholder(in context: Context) -> SunEntry {
        SunEntry(date: .now, state: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (SunEntry) -> Void) {
        completion(context.isPreview ? SunEntry(date: .now, state: .sample) : (sunTimeline(tab: .week).entries.first ?? SunEntry(date: .now, state: .sample)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SunEntry>) -> Void) {
        completion(sunTimeline(tab: .week))
    }
}

// MARK: Widgets

private let whiteCard = Color.white

/// Small: the sun over the sea, for this week or the long game (Edit Widget).
struct SunWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "LongGameSun", intent: ChooseViewIntent.self, provider: SunProvider()) { entry in
            Group {
                if let state = entry.state {
                    SmallSunWidgetView(state: state, tab: entry.tab)
                        .widgetURL(WidgetLink.url(for: entry.tab))
                } else {
                    SetupWidgetView().widgetURL(WidgetLink.url(for: .week))
                }
            }
            .containerBackground(whiteCard, for: .widget)
        }
        .configurationDisplayName("The sun")
        .description("The sun rises with this week's hours, or with the long game.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

/// Medium and Lock Screen: this week's sun with the long game beside it, and the Lock Screen ring, bar and line.
struct OverviewWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LongGameOverview", provider: OverviewProvider()) { entry in
            OverviewWidgetContent(entry: entry)
        }
        .configurationDisplayName("This week and the long game")
        .description("This week against your weekly target, and the long game against 10,000 hours.")
        .supportedFamilies([.systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
        .contentMarginsDisabled()
    }
}

private struct OverviewWidgetContent: View {
    let entry: SunEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if let state = entry.state {
                switch family {
                case .accessoryCircular: CircularSunWidgetView(state: state)
                case .accessoryRectangular: RectangularSunWidgetView(state: state)
                case .accessoryInline: InlineSunWidgetView(state: state)
                default: MediumSunWidgetView(state: state)
                }
            } else {
                switch family {
                case .accessoryCircular, .accessoryRectangular, .accessoryInline:
                    Text("Set up Long Game")
                default:
                    SetupWidgetView()
                }
            }
        }
        .widgetURL(WidgetLink.url(for: .week))
        .containerBackground(for: .widget) {
            switch family {
            case .systemMedium: whiteCard
            default: Color.clear
            }
        }
    }
}
