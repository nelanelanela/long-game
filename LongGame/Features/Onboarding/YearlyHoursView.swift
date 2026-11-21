import SwiftUI
import SwiftData

struct YearlyHoursView: View {
    @Bindable var model: OnboardingModel
    let onContinue: () -> Void

    /// The year the user changed last: highlighted, and the source of "Use N h for the years after".
    @State private var changedYear: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingHeader(step: 3)
            SetupSceneView(state: model.scene(editing: .score))
                .padding(.horizontal, -24)
            SetupTimeStripView(lit: .beforeToday)
                .padding(.horizontal, -24)
                .padding(.top, 10)

            Text("Before today").lgText(.setupTitle)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, 14)
            Text("Roughly, hours a week in each year.").lgText(.body, color: LGColor.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)

            // The card is only as tall as its rows; with many years the whole page scrolls, the button stays put.
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if model.years.count > 8 {
                        HStack {
                            Text("Set all to").lgText(.row, color: LGColor.inkMuted)
                            Spacer()
                            Menu {
                                ForEach(Array(1...20), id: \.self) { value in
                                    Button(Labels.hoursPerWeek(value)) { model.years.forEach { model.hours[$0] = value } }
                                }
                            } label: {
                                Text("Choose…").lgText(.rowStrong)
                                    .padding(.horizontal, 14).frame(minHeight: 44)
                            }
                        }
                    }

                    VStack(spacing: 0) {
                        ForEach(model.years, id: \.self) { year in
                            HoursStepperRow(label: String(year),
                                            subLabel: year == model.currentYear ? String(localized: "So far this year") : nil,
                                            value: Binding(get: { Double(model.hoursFor(year)) },
                                                           set: { model.hours[year] = Int($0.rounded()); changedYear = year }),
                                            isHighlighted: changedYear == year)
                                .frame(minHeight: 52)
                            if year != model.years.last { Divider().overlay(LGColor.divider) }
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 2)
                    .lgCard(radius: 22)

                    if let year = changedYear, YearHoursFill.hasLaterYears(after: year, years: model.years) {
                        let hours = model.hoursFor(year)
                        Button {
                            model.hours = YearHoursFill.applying(hours, after: year, to: model.hours, years: model.years)
                        } label: {
                            Text("Use \(hours) h for the years after \(String(year))")
                                .lgText(LGTextStyle(size: 14, weight: .semibold, relativeTo: .subheadline))
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 6)
                    }
                }
                .padding(.top, 12)
                // Room for the card's soft shadow, which a scroll view would otherwise cut off at its sides.
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .scrollBounceBehavior(.basedOnSize)
            .padding(.horizontal, -24)

            Button("Continue", action: onContinue)
                .buttonStyle(.lg(.primary))
                .padding(.top, 8)
            LGBrandLine().padding(.top, 12)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 10)
        .lgSetupScreen()
        .navigationBarBackButtonHidden()
        .onAppear { model.estimateKnown = true }
    }
}

#Preview("Before today · one year") {
    let m = OnboardingModel(); m.craftName = "Calligraphy"; m.startYear = m.currentYear - 1; m.startYearKnown = true
    return NavigationStack { YearlyHoursView(model: m) {} }
}

#Preview("Before today · seven years") {
    let m = OnboardingModel(); m.craftName = "Calligraphy"; m.startYear = m.currentYear - 6; m.startYearKnown = true
    return NavigationStack { YearlyHoursView(model: m) {} }
}

#Preview("Before today · twenty years, dark") {
    let m = OnboardingModel(); m.craftName = "Calligraphy"; m.startYear = m.currentYear - 19; m.startYearKnown = true
    return NavigationStack { YearlyHoursView(model: m) {} }.preferredColorScheme(.dark)
}

#Preview("Before today · AX5") {
    let m = OnboardingModel(); m.craftName = "Calligraphy"; m.startYear = m.currentYear - 6; m.startYearKnown = true
    return NavigationStack { YearlyHoursView(model: m) {} }.dynamicTypeSize(.accessibility5)
}
