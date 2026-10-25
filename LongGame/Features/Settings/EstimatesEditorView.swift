import SwiftUI
import SwiftData

/// Edit the hours per week for each year. Totals, forecast and milestones follow automatically.
struct EstimatesEditorView: View {
    let craft: Craft

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var estimates: [YearEstimate]
    @Query private var sessions: [Session]
    @Query private var settingsRows: [AppSettings]

    init(craft: Craft) {
        self.craft = craft
        let id = craft.id
        _estimates = Query(filter: #Predicate<YearEstimate> { $0.craftId == id }, sort: \YearEstimate.year)
        _sessions = Query(filter: #Predicate<Session> { $0.craftId == id })
    }

    private var total: Double {
        ProgressSummary.make(estimates: estimates.map(\.rate), sessions: sessions.map(\.record),
                             onboardingDate: craft.createdAt, weekStart: .monday, now: Date()).total
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                LGIconButton(systemName: "chevron.left", label: "Back") { dismiss() }
                    .padding(.leading, -10)
                Spacer()
            }
            .frame(height: 44)

            VStack(alignment: .leading, spacing: 8) {
                Text("Your estimates").lgText(.screenTitle).accessibilityAddTraits(.isHeader)
                Text("Hours per week for each year. Only focused practice.").lgText(.body, color: LGColor.inkMuted)
            }

            if estimates.count > 8 {
                HStack {
                    Text("Set all to").lgText(.row, color: LGColor.inkMuted)
                    Spacer()
                    Menu {
                        ForEach([0, 2, 5, 10, 15, 20], id: \.self) { value in
                            Button("\(value) h per week") { estimates.forEach { $0.hoursPerWeek = value } }
                        }
                    } label: {
                        Text("Choose…").lgText(.rowStrong).padding(.horizontal, 14).frame(minHeight: 44)
                    }
                }
            }

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(estimates, id: \.persistentModelID) { estimate in
                        HStack(spacing: 12) {
                            Text(String(estimate.year)).lgText(.rowStrong).monospacedDigit().frame(width: 48, alignment: .leading)
                            Slider(value: Binding(get: { Double(estimate.hoursPerWeek) }, set: { estimate.hoursPerWeek = Int($0) }),
                                   in: 0...40, step: 1)
                                .tint(LGColor.ink)
                                .accessibilityLabel("\(estimate.year), hours per week")
                            Text("\(estimate.hoursPerWeek) h").lgText(.row, color: LGColor.inkMuted).monospacedDigit()
                                .frame(width: 48, alignment: .trailing)
                        }
                        .frame(minHeight: 52)
                        if estimate.persistentModelID != estimates.last?.persistentModelID { Divider().overlay(LGColor.divider) }
                    }
                }
                .padding(.horizontal, 18)
            }
            .lgCard()

            HStack(alignment: .firstTextBaseline) {
                Text("Total with your sessions").lgText(.row, color: LGColor.inkMuted)
                Spacer()
                Text("\(Totals.wholeHours(total: total).formatted()) h")
                    .lgNumber(LGTextStyle(size: 26, weight: .bold, relativeTo: .title, tracking: -0.5))
            }
            .accessibilityElement(children: .combine)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .lgScreen()
        .toolbar(.hidden, for: .navigationBar)
        .onDisappear {
            // Editing estimates never replays old celebrations.
            if let settings = settingsRows.first {
                let crossed = Milestones.newlyCrossed(total: total, seen: settings.milestonesSeen)
                settings.milestonesSeen.append(contentsOf: crossed)
            }
            try? context.save()
        }
    }
}
