import SwiftUI
import SwiftData

struct YearlyHoursView: View {
    @Bindable var model: OnboardingModel
    @Environment(\.modelContext) private var context

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            OnboardingHeader(step: 3)

            VStack(alignment: .leading, spacing: 8) {
                Text("Hours per week, each year").lgText(.screenTitle)
                    .accessibilityAddTraits(.isHeader)
                Text("More or less. Only focused practice.").lgText(.body, color: LGColor.inkMuted)
            }

            if model.years.count > 8 {
                HStack {
                    Text("Set all to").lgText(.row, color: LGColor.inkMuted)
                    Spacer()
                    Menu {
                        ForEach([0, 2, 5, 10, 15, 20], id: \.self) { value in
                            Button("\(value) h per week") { model.years.forEach { model.hours[$0] = value } }
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
                        HStack(spacing: 12) {
                            Text(String(year)).lgText(.rowStrong).monospacedDigit()
                                .frame(width: 48, alignment: .leading)
                            Slider(value: Binding(get: { Double(model.hoursFor(year)) },
                                                  set: { model.hours[year] = Int($0) }),
                                   in: 0...40, step: 1)
                                .tint(LGColor.ink)
                                .accessibilityLabel("\(year), hours per week")
                            Text("\(model.hoursFor(year)) h").lgText(.row, color: LGColor.inkMuted).monospacedDigit()
                                .frame(width: 48, alignment: .trailing)
                        }
                        .frame(minHeight: 52)
                        if year != model.years.last { Divider().overlay(LGColor.divider) }
                    }
                }
                .padding(.horizontal, 18)
            }
            .lgCard()

            HStack(alignment: .firstTextBaseline) {
                Text("Estimated so far").lgText(.row, color: LGColor.inkMuted)
                Spacer()
                Text("\(Totals.wholeHours(total: model.estimatedSoFar()).formatted()) h")
                    .lgNumber(LGTextStyle(size: 26, weight: .bold, relativeTo: .title, tracking: -0.5))
            }
            .accessibilityElement(children: .combine)

            Button("Start tracking") { model.save(in: context) }
                .buttonStyle(.lg(.primary))
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .lgScreen()
        .navigationBarBackButtonHidden()
    }
}
