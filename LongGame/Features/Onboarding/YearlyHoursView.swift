import SwiftUI
import SwiftData

struct YearlyHoursView: View {
    @Bindable var model: OnboardingModel
    let onContinue: () -> Void

    /// The year the user changed last: highlighted, and the source of "Use N h for the years after".
    @State private var changedYear: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            OnboardingHeader(step: 3)

            VStack(alignment: .leading, spacing: 8) {
                Text("Hours per week, each year").lgText(.screenTitle)
                    .accessibilityAddTraits(.isHeader)
                Text("This is your starting score. Only focused practice counts.").lgText(.body, color: LGColor.inkMuted)
            }

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

            ScrollView {
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
                .padding(.horizontal, 18)
            }
            .lgCard()

            if let year = changedYear, YearHoursFill.hasLaterYears(after: year, years: model.years) {
                let hours = model.hoursFor(year)
                Button("Use \(hours) h for the years after \(String(year))") {
                    model.hours = YearHoursFill.applying(hours, after: year, to: model.hours, years: model.years)
                }
                .buttonStyle(.lg(.text))
            }

            HStack(alignment: .firstTextBaseline) {
                Text("Estimated so far").lgText(.row, color: LGColor.inkMuted)
                Spacer()
                Text("\(DurationFormat.grouped(Totals.wholeHours(total: model.estimatedSoFar()))) h")
                    .lgNumber(LGTextStyle(size: 26, weight: .bold, relativeTo: .title, tracking: -0.5))
            }
            .accessibilityElement(children: .combine)

            Button("Continue", action: onContinue)
                .buttonStyle(.lg(.primary))
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .lgScreen()
        .navigationBarBackButtonHidden()
        .onAppear { model.estimateKnown = true }
    }
}
