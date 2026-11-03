import SwiftUI
import WidgetKit

// The complications: this week's hours on the watch face. They read the data the watch app keeps in the shared folder
// (the phone's data plus sessions still on their way to it) and work out the numbers with the app's own Logic code.

@main
struct LongGameWatchWidgetsBundle: WidgetBundle {
    var body: some Widget {
        SunComplication()
    }
}

struct ComplicationEntry: TimelineEntry {
    let date: Date
    /// Nil until the phone has been set up.
    let state: WidgetState?
}

struct ComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> ComplicationEntry {
        ComplicationEntry(date: .now, state: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (ComplicationEntry) -> Void) {
        completion(context.isPreview ? ComplicationEntry(date: .now, state: .sample) : timeline().entries[0])
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ComplicationEntry>) -> Void) {
        completion(timeline())
    }

    /// An entry now, then one at every midnight until the week turns; the watch app reloads it when data changes.
    private func timeline(now: Date = Date()) -> Timeline<ComplicationEntry> {
        guard let snapshot = WidgetSnapshot.load() else {
            return Timeline(entries: [ComplicationEntry(date: now, state: nil)], policy: .after(now.addingTimeInterval(3_600)))
        }
        let weekStart = WeekStart(rawValue: snapshot.weekStart) ?? .monday
        let entries = WidgetModel.timelineDates(from: now, weekStart: weekStart)
            .map { ComplicationEntry(date: $0, state: WidgetModel.make(snapshot, at: $0)) }
        return Timeline(entries: entries, policy: .atEnd)
    }
}

struct SunComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LongGameWatchSun", provider: ComplicationProvider()) { entry in
            ComplicationContent(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("This week")
        .description("This week's hours against your weekly target.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryCorner, .accessoryInline])
    }
}

private struct ComplicationContent: View {
    let entry: ComplicationEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let state = entry.state {
            switch family {
            case .accessoryRectangular:
                WatchRectangularView(state: state)
            case .accessoryCorner:
                WatchHoursText(state: state)
                    .foregroundStyle(LGColor.sunBody)
                    .widgetCurvesContent()
                    .widgetLabel {
                        ProgressView(value: state.week.fraction).tint(LGColor.sunBody)
                    }
            case .accessoryInline:
                Label { WatchHoursText(state: state) } icon: { Image(systemName: "sun.max.fill") }
            default:
                WatchCircularView(state: state)
            }
        } else {
            Image(systemName: "sun.max")
        }
    }
}
