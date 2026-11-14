import SwiftUI

/// A scene picture for the setup screens (Welcome and the intro pages): sky, the sun, then the land and sea in
/// front of it. Measurements are the boards' design points (390 wide); the sky and land stretch to the width.
/// The sea is always in front of the sun and always opaque, and the sun sits still unless `idle` is on.
struct SceneHero: View {
    var tone: SceneTone
    /// The whole picture's height.
    var height: CGFloat
    /// The sky's height and where its horizon sits (as a fraction of that height).
    var skyHeight: CGFloat
    var horizon: CGFloat
    /// Where the land box starts; its shoreline is 46 pt below that.
    var landTop: CGFloat
    var sunSize: CGFloat
    var sunTop: CGFloat
    var face: SunFace = .happy
    var eyesOpen: Double = 0
    var moon = true
    /// Tapping the sun makes it giggle (the intro pages); Welcome keeps it still.
    var giggles = false
    /// What VoiceOver reads for the picture. Empty hides it.
    var label: LocalizedStringKey = ""
    var hidden = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.giggleSoundOn) private var soundOn
    @Environment(\.colorScheme) private var colorScheme

    /// The dark look (update 45): onboarding and the sheets' small scenes use the dawn sky over the night land.
    private var skyTone: SceneTone { colorScheme == .dark && tone == .day ? .dawn : tone }
    private var landTone: SceneTone { colorScheme == .dark || tone == .night ? .night : .day }
    @State private var giggle = GiggleController()

    private var shoreY: CGFloat { landTop + 46 }

    var body: some View {
        ZStack(alignment: .top) {
            SkyView(tone: skyTone, horizon: horizon, moon: moon)
                .frame(height: skyHeight)
                .frame(maxHeight: .infinity, alignment: .top)
                // In the dark look the dawn sky's top melts into the page, so there is no edge where a header or the
                // sheet's top meets it (the day sky is see-through, so the light look never has one).
                .overlay(alignment: .top) {
                    if colorScheme == .dark && tone == .day {
                        LinearGradient(colors: [LGColor.background, LGColor.background.opacity(0)], startPoint: .top, endPoint: .bottom)
                            .frame(height: skyHeight * 0.35)
                            .allowsHitTesting(false)
                    }
                }

            GeometryReader { geo in
                GigglingSun(run: giggle.run) { pose in
                    SunView(face: face, eyesOpen: pose.face == nil ? eyesOpen : 0, giggle: pose)
                }
                .frame(width: sunSize, height: sunSize)
                .position(x: geo.size.width / 2, y: sunTop + sunSize / 2)
            }

            // The land and sea come after the sun, so nothing of the sun shows below the shoreline.
            LandView(tone: landTone)
                .frame(height: 120)
                .frame(maxHeight: .infinity, alignment: .top)
                .offset(y: landTop)

            if giggles { tapTarget }
        }
        .frame(height: height)
        .clipped()
        .modifier(SceneAccessibility(label: label, hidden: hidden || (label == ""), giggles: giggles,
                                     tickle: { giggle.tap(soundOn: soundOn, reduceMotion: reduceMotion) }))
        .task(id: soundOn) { if giggles { await giggle.prepare(soundOn: soundOn) } }
    }

    /// The whole sun, and at least 44 pt, but never below the shoreline.
    private var tapTarget: some View {
        GeometryReader { geo in
            let side = max(sunSize, 44)
            let top = sunTop + sunSize / 2 - side / 2
            let bottom = min(sunTop + sunSize / 2 + side / 2, shoreY)
            Color.clear
                .contentShape(Rectangle())
                .frame(width: side, height: max(0, bottom - top))
                .position(x: geo.size.width / 2, y: top + max(0, bottom - top) / 2)
                .onTapGesture { giggle.tap(soundOn: soundOn, reduceMotion: reduceMotion) }
        }
    }
}

private struct SceneAccessibility: ViewModifier {
    let label: LocalizedStringKey
    let hidden: Bool
    let giggles: Bool
    let tickle: () -> Void

    func body(content: Content) -> some View {
        if hidden {
            content.accessibilityHidden(true)
        } else {
            content
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(label)
                .accessibilityAddTraits(.isImage)
                .accessibilityAction(named: Text("Tickle the sun")) { if giggles { tickle() } }
        }
    }
}

#Preview("Setup scenes") {
    ScrollView {
        VStack(spacing: 8) {
            SceneHero(tone: .dawn, height: 520, skyHeight: 520, horizon: 0.8, landTop: 371, sunSize: 160, sunTop: 318)
            SceneHero(tone: .day, height: 354, skyHeight: 340, horizon: 0.82, landTop: 234, sunSize: 150, sunTop: 66)
            SceneHero(tone: .dawn, height: 354, skyHeight: 340, horizon: 0.82, landTop: 234, sunSize: 150, sunTop: 204)
        }
    }
    .background(LGColor.background)
}
