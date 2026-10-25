import SwiftUI

struct StartYearView: View {
    @Bindable var model: OnboardingModel
    let onContinue: () -> Void

    private let earliest = 1940

    private var yearsAgoText: String {
        let n = model.currentYear - model.startYear
        switch n {
        case 0: return "This year"
        case 1: return "1 year ago"
        default: return "\(n) years ago"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            OnboardingHeader(step: 2)

            VStack(alignment: .leading, spacing: 8) {
                Text("When did you start?").lgText(.screenTitle)
                    .accessibilityAddTraits(.isHeader)
                Text("A rough guess is fine.").lgText(.body, color: LGColor.inkMuted)
            }

            HStack {
                stepButton("minus", label: "Earlier year", enabled: model.startYear > earliest) { model.startYear -= 1 }
                Spacer()
                VStack(spacing: 6) {
                    Text(String(model.startYear)).lgNumber(.yearNumber)
                    Text(yearsAgoText).lgText(.caption, color: LGColor.inkMuted)
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
            .padding(.horizontal, 20)
            .padding(.vertical, 36)
            .lgCard(radius: 24)

            Spacer()

            Button("Continue", action: onContinue).buttonStyle(.lg(.primary))
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .lgScreen()
        .navigationBarBackButtonHidden()
    }

    private func stepButton(_ icon: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(LGColor.ink)
                .frame(width: 52, height: 52)
                .background(LGColor.chipFill, in: Circle())
        }
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .accessibilityLabel(label)
    }
}
