import SwiftUI
import SwiftData

/// First launch → Welcome + onboarding. No active craft after a replace →
/// onboarding without the welcome. Otherwise Home.
struct AppRoot: View {
    @Query private var crafts: [Craft]

    private var active: Craft? { crafts.first(where: \.isActive) }

    var body: some View {
        Group {
            if let active {
                HomeView(craft: active)
            } else {
                OnboardingFlow(showWelcome: crafts.isEmpty)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: active?.id)
    }
}
