import SwiftUI
import SwiftData

/// No active craft (first launch, or after "Switch to a new game") → Welcome + onboarding; the intro pages only
/// the first time. Otherwise Home, on the tab used last.
struct AppRoot: View {
    @Query private var crafts: [Craft]
    @Query private var settingsRows: [AppSettings]

    private var active: Craft? { crafts.first(where: \.isActive) }

    var body: some View {
        Group {
            if let active {
                NavigationStack { HomeView(craft: active, initialTab: settingsRows.first?.lastHomeTab ?? .week) }
            } else {
                OnboardingFlow(showIntro: crafts.isEmpty)
            }
        }
        .syncsWidgets()
    }
}
