import SwiftUI

/// Welcome: the dawn scene (sky, smiling sun, dunes and sea), the wordmark and "by We Have Sun".
struct WelcomeView: View {
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    SceneHero(tone: .dawn, height: 500, skyHeight: 520, horizon: 0.8, landTop: 371,
                              sunSize: 160, sunTop: 318, hidden: true)
                    VStack(spacing: 8) {
                        Text("Long Game").lgText(.welcomeTitle)
                            .accessibilityAddTraits(.isHeader)
                        Text("by We Have Sun")
                            .lgText(LGTextStyle(size: 11, weight: .semibold, relativeTo: .caption, tracking: 1.76),
                                    color: LGColor.inkMuted)
                            .textCase(.uppercase)
                        Text("The longest game on the App Store. Played in real life.")
                            .lgText(.bodyLarge, color: LGColor.inkMuted)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 10)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .ignoresSafeArea(edges: .top)

            Button("Get started", action: onStart)
                .buttonStyle(.lg(.primary))
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
        .lgScreen()
    }
}

#Preview { WelcomeView {} }
#Preview("Welcome · largest Dynamic Type") { WelcomeView {}.environment(\.dynamicTypeSize, .accessibility5) }
