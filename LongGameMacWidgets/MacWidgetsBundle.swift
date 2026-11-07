import SwiftUI
import WidgetKit

/// The widgets on the Mac desktop and in Notification Center: the same two as the iPhone's Home Screen (the sun, and
/// this week with the long game), without the Lock Screen shapes. They read the same App Group data the app writes.
@main
struct LongGameMacWidgetsBundle: WidgetBundle {
    var body: some Widget {
        SunWidget()
        OverviewWidget()
    }
}
