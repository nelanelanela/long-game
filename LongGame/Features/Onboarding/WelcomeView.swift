import SwiftUI

struct WelcomeView: View {
    let onStart: () -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(gradient: LGColor.welcomeSky, startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                let sunY = geo.size.height * 0.71
                Circle()
                    .fill(RadialGradient(colors: [Color(hex: 0xFFD678, opacity: 0.55), Color(hex: 0xFFD678, opacity: 0)],
                                         center: .center, startRadius: 0, endRadius: 100))
                    .frame(width: 300, height: 300)
                    .position(x: geo.size.width / 2, y: sunY)
                    .accessibilityHidden(true)
                SunView(idle: false, face: .happy, rayColor: LGColor.sunRaysBright)
                    .frame(width: 240, height: 240)
                    .position(x: geo.size.width / 2, y: sunY)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Long Game").lgText(.welcomeTitle, color: .white)
                        .accessibilityAddTraits(.isHeader)
                    Text("The longest game on the App Store. Played in real life.")
                        .lgText(.bodyLarge, color: .white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 280, alignment: .leading)
                    Spacer()
                    Button("Get started", action: onStart).buttonStyle(.lg(.light))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 28)
                .padding(.top, 60)
                .padding(.bottom, 24)
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview { WelcomeView {} }
