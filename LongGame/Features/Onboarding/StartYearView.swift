import SwiftUI

struct StartYearView: View {
    @Bindable var model: OnboardingModel
    let onContinue: () -> Void

    private let earliest = 1940

    private var yearsAgoText: String {
        let n = model.currentYear - model.startYear
        switch n {
        case 0: return "This year"
        default: return Labels.yearsAgo(n)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingHeader(step: 2)

            Text("When did you start?").lgText(.setupTitle)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, 18)
            Text("A rough guess is fine.").lgText(.body, color: LGColor.inkMuted)
                .padding(.top, 8)

            // No card: the year sits straight on the peach wash, between two round buttons.
            HStack {
                stepButton("minus", label: "Earlier year", enabled: model.startYear > earliest) { model.startYear -= 1 }
                Spacer()
                VStack(spacing: 6) {
                    Text(String(model.startYear))
                        .lgNumber(LGTextStyle(size: 68, weight: .bold, relativeTo: .largeTitle, tracking: -2.7))
                    Text(yearsAgoText).lgText(.row, color: LGColor.inkMuted)
                }
                .accessibilityElement(children: .combine)
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: if model.startYear < model.currentYear { model.startYear += 1 }
                    case .decrement: if model.startYear > earliest { model.startYear -= 1 }
                    @unknown default: break
                    }
                }
                Spacer()
                stepButton("plus", label: "Later year", enabled: model.startYear < model.currentYear) { model.startYear += 1 }
            }
            .padding(.top, 80)

            Spacer(minLength: 16)

            Button("Continue", action: onContinue).buttonStyle(.lg(.primary))
            LGBrandLine().padding(.top, 12)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 10)
        .lgSetupScreen()
        .navigationBarBackButtonHidden()
    }

    private func stepButton(_ icon: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            LGStepCircle(systemName: icon, diameter: 56, dimmed: !enabled)
        }
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}
