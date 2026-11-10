import SwiftUI

/// Shown instead of Welcome when the person's iCloud already holds a game.
struct WelcomeBackView: View {
    let game: FoundGame
    let onContinue: () -> Void
    let onStartNew: () -> Void

    var body: some View {
        // The same picture as Welcome, by day: the sun is already up, eyes open.
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    SceneHero(tone: .day, height: 500, skyHeight: 520, horizon: 0.8, landTop: 371,
                              sunSize: 160, sunTop: 250, eyesOpen: 1, hidden: true)
                    VStack(spacing: 0) {
                        Text("Welcome back")
                            .lgText(LGTextStyle(size: 36, weight: .bold, relativeTo: .largeTitle, tracking: -1.08))
                            .accessibilityAddTraits(.isHeader)
                        LGBrandLine(text: "Long Game · by We Have Sun").padding(.top, 8)
                        Text("We found your game in iCloud.").lgText(.body, color: LGColor.inkMuted)
                            .multilineTextAlignment(.center)
                            .padding(.top, 18)
                        Text(game.summary)
                            .lgText(LGTextStyle(size: 18, weight: .semibold, relativeTo: .body))
                            .multilineTextAlignment(.center)
                            .padding(.top, 6)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .ignoresSafeArea(edges: .top)

            Button("Continue my game", action: onContinue).buttonStyle(.lg(.primary))
                .padding(.horizontal, 24)
            Button("Start a new game", action: onStartNew).buttonStyle(.lg(.text))
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
        }
        .lgScreen()
    }
}

#Preview("Welcome back") {
    WelcomeBackView(game: FoundGame(craftName: "Piano", hours: 3294), onContinue: {}, onStartNew: {})
}
