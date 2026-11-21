import SwiftUI

/// Step 3 for a game started this year (update 53, `design/redesign/YearlyHoursThisYear.dc.html`): one big stepper
/// in hours so far, in total, instead of hours a week. Saved as the year's `totalHours`.
struct SoFarThisYearView: View {
    @Bindable var model: OnboardingModel
    let onContinue: () -> Void

    private var unit: String {
        model.soFarTotal == 1 ? String(localized: "hour so far") : String(localized: "hours so far")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingHeader(step: 3).padding(.horizontal, 24)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SetupSceneView(state: model.scene(editing: .score))
                        .padding(.top, 6)
                    VStack(alignment: .leading, spacing: 0) {
                        SetupTimeStripView(lit: .beforeToday).padding(.top, 14)
                        Text("Before today").lgText(.setupTitle)
                            .accessibilityAddTraits(.isHeader)
                            .padding(.top, 14)
                        Text("You started this year. About how many hours have you played so far, in total?")
                            .lgText(.setupLine, color: LGColor.inkMuted)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 6)

                        HoursBigStepper(label: String(localized: "Hours so far"), value: $model.soFarTotal,
                                        spec: .soFarTotal, unit: unit,
                                        spoken: { String(localized: "\(DurationFormat.grouped(Int($0))) hours so far") })
                            .frame(maxWidth: .infinity)
                            .padding(.top, 36)

                        Text("A rough guess is fine. Only focused practice counts.")
                            .lgText(.note, color: LGColor.inkMuted)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 24)

                        // A white pill with a thin edge, 40 pt tall; its touch area is 44.
                        Button { model.soFarTotal = 0 } label: {
                            Text("I’m just starting · 0 h")
                                .lgText(LGTextStyle(size: 14, weight: .semibold, relativeTo: .subheadline))
                                .padding(.horizontal, 16)
                                .frame(minHeight: 40)
                                .background(LGColor.surface, in: Capsule())
                                .overlay { Capsule().strokeBorder(LGColor.setupStripQuiet, lineWidth: 1) }
                                .padding(.vertical, 2)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(model.soFarTotal == 0 ? .isSelected : [])
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                }
            }
            .scrollBounceBehavior(.basedOnSize)

            VStack(spacing: 0) {
                Button("Continue", action: onContinue).buttonStyle(.lg(.primary))
                LGBrandLine().padding(.top, 12)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
        .padding(.bottom, 10)
        .lgSetupScreen()
        .navigationBarBackButtonHidden()
        .onAppear { model.estimateKnown = true; model.soFarSeen = true }
    }
}

#Preview("Before today · started this year") {
    let m = OnboardingModel(); m.craftName = "Calligraphy"; m.startYear = m.currentYear; m.startYearKnown = true
    return NavigationStack { SoFarThisYearView(model: m) {} }
}

#Preview("Before today · started this year, dark") {
    let m = OnboardingModel(); m.craftName = "Calligraphy"; m.startYear = m.currentYear; m.startYearKnown = true
    return NavigationStack { SoFarThisYearView(model: m) {} }.preferredColorScheme(.dark)
}

#Preview("Before today · started this year, AX5") {
    let m = OnboardingModel(); m.craftName = "Calligraphy"; m.startYear = m.currentYear; m.startYearKnown = true
    return NavigationStack { SoFarThisYearView(model: m) {} }.dynamicTypeSize(.accessibility5)
}
