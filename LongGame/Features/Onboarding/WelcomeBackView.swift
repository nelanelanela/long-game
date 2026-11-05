import SwiftUI

/// Shown instead of Welcome when the person's iCloud already holds a game.
struct WelcomeBackView: View {
    let game: FoundGame
    let onContinue: () -> Void
    let onStartNew: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ICloudIllustration().padding(.top, 24)
            VStack(alignment: .leading, spacing: 10) {
                Text("Welcome back").lgText(.screenTitle).accessibilityAddTraits(.isHeader)
                Text("We found your game in iCloud.").lgText(.body, color: LGColor.inkMuted)
                Text(game.summary)
                    .lgText(.rowStrong)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.white, in: Capsule())
                    .padding(.top, 6)
            }
            .padding(.top, 12)
            Spacer()
            Button("Continue my game", action: onContinue).buttonStyle(.lg(.primary))
            Button("Start a new game", action: onStartNew).buttonStyle(.lg(.text))
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .lgScreen()
    }
}

#Preview("Welcome back") {
    WelcomeBackView(game: FoundGame(craftName: "Piano", hours: 3294), onContinue: {}, onStartNew: {})
}
