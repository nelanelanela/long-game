import SwiftUI
import SwiftData

/// Crafts that were replaced. Read-only.
struct ArchivedCraftsView: View {
    let crafts: [Craft]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    LGIconButton(systemName: "chevron.left", label: "Back") { dismiss() }
                        .padding(.leading, -10)
                    Spacer()
                }
                .frame(height: 44)
                Text("Archived crafts").lgText(.screenTitle).accessibilityAddTraits(.isHeader)

                if crafts.isEmpty {
                    VStack(spacing: 8) {
                        SunView(face: .sleepy).frame(width: 64, height: 64)
                        Text("Nothing here. Crafts you replace are kept here to look back on.")
                            .lgText(.row, color: LGColor.inkMuted).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity).padding(20).lgCard()
                } else {
                    VStack(spacing: 10) {
                        ForEach(crafts, id: \.persistentModelID) { craft in
                            NavigationLink { ArchivedCraftDetail(craft: craft) } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(craft.name).lgText(.rowStrong)
                                        Text("Started \(String(craft.startYear))").lgText(.caption, color: LGColor.inkMuted)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(LGColor.inkMuted)
                                }
                                .padding(18).lgCard()
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
        }
        .lgScreen()
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct ArchivedCraftDetail: View {
    let craft: Craft
    @Environment(\.dismiss) private var dismiss
    @Query private var sessions: [Session]
    @Query private var estimates: [YearEstimate]

    init(craft: Craft) {
        self.craft = craft
        let id = craft.id
        _sessions = Query(filter: #Predicate<Session> { $0.craftId == id }, sort: \Session.start, order: .reverse)
        _estimates = Query(filter: #Predicate<YearEstimate> { $0.craftId == id })
    }

    private var total: Double {
        let until = craft.archivedAt ?? Date()
        return ProgressSummary.make(estimates: estimates.map(\.rate), sessions: sessions.map(\.record),
                                    onboardingDate: craft.createdAt, weekStart: .monday, now: until).total
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    LGIconButton(systemName: "chevron.left", label: "Back") { dismiss() }
                        .padding(.leading, -10)
                    Spacer()
                }
                .frame(height: 44)
                Text(craft.name).lgText(.screenTitle).accessibilityAddTraits(.isHeader)

                VStack(spacing: 4) {
                    Text(Totals.wholeHours(total: total).formatted()).lgNumber(.bigNumber)
                    Text("hours · \(sessions.count) \(sessions.count == 1 ? "session" : "sessions")")
                        .lgText(.row, color: LGColor.inkMuted)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 24).lgCard(radius: 24)
                .accessibilityElement(children: .combine)

                if !sessions.isEmpty {
                    LGSectionLabel("Sessions")
                    VStack(spacing: 0) {
                        ForEach(Array(sessions.enumerated()), id: \.element.persistentModelID) { index, session in
                            HStack {
                                Text(RelativeDay.label(session.start, now: Date())).lgText(.row)
                                Spacer()
                                Text(DurationFormat.short(seconds: session.durationSec)).lgText(.row, color: LGColor.inkMuted)
                            }
                            .frame(minHeight: 48)
                            if index < sessions.count - 1 { Divider().overlay(LGColor.divider) }
                        }
                    }
                    .padding(.horizontal, 18).lgCard()
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .lgScreen()
        .toolbar(.hidden, for: .navigationBar)
    }
}
