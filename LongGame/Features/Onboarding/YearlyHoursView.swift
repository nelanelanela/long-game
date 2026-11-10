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

            Text("Hours a week, each year").lgText(.setupTitle)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, 18)

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

                    HStack(alignment: .firstTextBaseline) {
                        Text("Your starting score").lgText(.row, color: LGColor.inkMuted)
                        Spacer()
                        Text("\(DurationFormat.grouped(Totals.wholeHours(total: model.estimatedSoFar()))) h")
                            .lgNumber(LGTextStyle(size: 28, weight: .bold, relativeTo: .title, tracking: -0.56))
                    }
                    .accessibilityElement(children: .combine)
                    .padding(.top, 8)
                }
                .padding(.top, 16)
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
