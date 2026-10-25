import SwiftUI

struct WelcomeView: View {
    let onStart: () -> Void
    @State private var showNoAccount = false

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
                SunView(face: .happy, rayColor: LGColor.sunRaysBright)
                    .frame(width: 240, height: 240)
                    .position(x: geo.size.width / 2, y: sunY)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Long Game").lgText(.welcomeTitle, color: .white)
                        .accessibilityAddTraits(.isHeader)
                    Text("Mastery takes about 10,000 hours. Choose one craft and watch every hour count.")
                        .lgText(.bodyLarge, color: .white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 280, alignment: .leading)
                    Spacer()
                    Button("Get started", action: onStart).buttonStyle(.lg(.light))
                    Button("I already have an account") { showNoAccount = true }
                        .buttonStyle(.lg(.text))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 28)
                .padding(.top, 60)
                .padding(.bottom, 24)
            }
        }
        .preferredColorScheme(.dark)
        .alert("No saved account found", isPresented: $showNoAccount) {
            Button("Continue", action: onStart)
        } message: {
            Text("Sign in and iCloud restore are coming in a later update. You can start tracking now.")
        }
    }
}

#Preview { WelcomeView {} }
