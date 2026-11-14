import SwiftUI
import SwiftData

extension AppAppearance {
    var colorScheme: ColorScheme? {
        prefersDark.map { $0 ? .dark : .light }
    }

    var title: LocalizedStringKey {
        switch self {
        case .automatic: "Automatic"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

extension EnvironmentValues {
    /// The app's own look (light or dark), kept apart from `colorScheme` because a few screens force a dark status
    /// bar (the Timer, the photo viewer): their sheets go back to the app's look with `lgAppLook()`.
    @Entry var lgNightLook: Bool = false
}

extension View {
    /// The app's look again under a screen that forced its own (the Finish sheet over the Timer, the note sheet over
    /// the photo viewer).
    func lgAppLook() -> some View { modifier(AppLookModifier()) }
}

private struct AppLookModifier: ViewModifier {
    @Environment(\.lgNightLook) private var night
    func body(content: Content) -> some View {
        content.environment(\.colorScheme, night ? .dark : .light)
    }
}

/// Applies Settings › Look at the root, so sheets and full-screen covers follow, and tells the screens below which
/// look is showing.
struct AppearanceRoot<Content: View>: View {
    @Query private var settingsRows: [AppSettings]
    @ViewBuilder var content: Content

    var body: some View {
        LookReader { content }
            .preferredColorScheme(chosen)
    }

    private var chosen: ColorScheme? {
        #if DEBUG
        if let forced = UITestLaunch.appearance { return forced.colorScheme }
        #endif
        return settingsRows.first?.appearance.colorScheme
    }
}

private struct LookReader<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    @ViewBuilder var content: Content
    var body: some View { content.environment(\.lgNightLook, scheme == .dark) }
}
