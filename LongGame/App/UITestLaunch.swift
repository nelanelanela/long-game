import SwiftUI
import SwiftData

#if DEBUG
/// Debug-only launch switches for the accessibility UI tests (update 47). None of this is in a release build.
///
/// - `-demoData`: the sample Piano game (`DemoData`).
/// - `-demoData.heavy`: eight years of sessions and 300 photos, for profiling (seeded once, see `DemoData.seedHeavy`).
/// - `-uitest.freshInstall`: everything deleted, so the app opens on onboarding.
/// - `-uitest.flat`: the flat tabs (the pre-iOS 26 look); `-uitest.increaseContrast`: Increase Contrast.
/// - `-uitest.disableAnimations`: no opening sunrise, UIKit animations off.
/// - `-uitest.skipOpening`: no opening sunrise, animations on (performance tests).
/// - `-uitest.screen <name>`: Home opens this screen or sheet (see `HomeView.applyUITestRoute`).
/// - `-uitest.newGame`: a game set up three days ago, for History's first week.
/// - `-uitest.today empty|progress|covered`: today's sample sessions, for Home · Today's three states.
/// - `-uitest.appearance light|dark`: Settings › Look for this run.
/// - `-uitest.reduceMotion`, `-uitest.reduceTransparency`, `-uitest.differentiateWithoutColor`: the app sees these
///   accessibility settings as on. They set SwiftUI's own values at the root, which every view already reads.
enum UITestLaunch {
    private static var args: [String] { ProcessInfo.processInfo.arguments }

    private static func value(_ key: String) -> String? {
        guard let i = args.firstIndex(of: key), args.indices.contains(i + 1) else { return nil }
        return args[i + 1]
    }

    static var freshInstall: Bool { args.contains("-uitest.freshInstall") }
    static var disableAnimations: Bool { args.contains("-uitest.disableAnimations") }
    /// `-uitest.skipOpening`: no opening sunrise, but every other animation as usual (the performance tests measure
    /// them).
    static var skipOpening: Bool { args.contains("-uitest.skipOpening") }
    static var screen: String? { value("-uitest.screen") }
    static var today: String? { value("-uitest.today") }
    /// `-uitest.photos`: two photo sessions years apart (Then and now), whatever the screen.
    static var photos: Bool { args.contains("-uitest.photos") }
    /// `-uitest.newGame`: with `-demoData`, a game set up three days ago (History's first week).
    static var newGame: Bool { args.contains("-uitest.newGame") }
    static var appearance: AppAppearance? { value("-uitest.appearance").flatMap(AppAppearance.init(rawValue:)) }
    static var reduceMotion: Bool { args.contains("-uitest.reduceMotion") }
    static var reduceTransparency: Bool { args.contains("-uitest.reduceTransparency") }
    static var differentiateWithoutColor: Bool { args.contains("-uitest.differentiateWithoutColor") }
    /// `-uitest.flat`: the flat, pre-iOS 26 look of the tabs and buttons on a newer system (no iOS 17/18 Simulator).
    static var flat: Bool { args.contains("-uitest.flat") }
    static var increaseContrast: Bool { args.contains("-uitest.increaseContrast") }

    /// Called once at launch, before the first screen.
    @MainActor
    static func prepare(_ context: ModelContext) {
        #if canImport(UIKit)
        if disableAnimations { UIView.setAnimationsEnabled(false) }
        #endif
        // The timer lives on disk between launches: one test's paused session must not open the next test's screen.
        // (It also comes back through the synced ActiveSession record, so that goes too.)
        if screen != nil || freshInstall {
            for row in (try? context.fetch(FetchDescriptor<ActiveSession>())) ?? [] { context.delete(row) }
            try? context.save()
            TimerStore.shared.clear()
        }
        guard freshInstall else { return }
        for craft in (try? context.fetch(FetchDescriptor<Craft>())) ?? [] { context.delete(craft) }
        for e in (try? context.fetch(FetchDescriptor<YearEstimate>())) ?? [] { context.delete(e) }
        for s in (try? context.fetch(FetchDescriptor<Session>())) ?? [] { context.delete(s) }
        for t in (try? context.fetch(FetchDescriptor<TargetPeriod>())) ?? [] { context.delete(t) }
        for s in (try? context.fetch(FetchDescriptor<AppSettings>())) ?? [] { context.delete(s) }
        try? context.save()
        TimerPersistence.save(nil)
    }
}

/// The switched-on accessibility settings and the appearance for a test run, set at the root.
struct UITestEnvironment: ViewModifier {
    func body(content: Content) -> some View {
        content.modifier(Overrides())
    }

    private struct Overrides: ViewModifier {
        @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
        @Environment(\.accessibilityReduceTransparency) private var systemReduceTransparency
        @Environment(\.accessibilityDifferentiateWithoutColor) private var systemDifferentiate
        @Environment(\.colorSchemeContrast) private var systemContrast

        func body(content: Content) -> some View {
            content
                .environment(\._accessibilityReduceMotion, systemReduceMotion || UITestLaunch.reduceMotion)
                .environment(\._accessibilityReduceTransparency, systemReduceTransparency || UITestLaunch.reduceTransparency)
                .environment(\._accessibilityDifferentiateWithoutColor, systemDifferentiate || UITestLaunch.differentiateWithoutColor)
                .environment(\.lgFlat, UITestLaunch.flat)
                .environment(\._colorSchemeContrast, UITestLaunch.increaseContrast ? .increased : systemContrast)
        }
    }
}
#endif

extension View {
    /// Debug builds: the UI tests' accessibility switches. Release builds: nothing.
    @ViewBuilder func lgUITestEnvironment() -> some View {
        #if DEBUG
        modifier(UITestEnvironment())
        #else
        self
        #endif
    }
}
