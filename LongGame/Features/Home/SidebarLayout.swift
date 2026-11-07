import SwiftUI

/// The iPad's wide layout (shared with the Mac app): a 260 pt sidebar and, beside it, a title bar over the content.

struct SidebarView: View {
    let craftName: String
    let totalHours: Int
    let yearTitle: String
    @Binding var selection: SidebarSection

    static let width: CGFloat = 260

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(craftName).lgText(LGTextStyle(size: 26, weight: .bold, relativeTo: .title, tracking: -0.5))
                .lineLimit(1).minimumScaleFactor(0.6)
                .padding(.horizontal, 12).padding(.top, 8)
                .accessibilityAddTraits(.isHeader)
            Text("\(DurationFormat.grouped(totalHours)) of 10,000 h")
                .lgText(LGTextStyle(size: 13, weight: .regular, relativeTo: .footnote), color: LGColor.inkMuted)
                .padding(.horizontal, 12)
            group("Play", SidebarSection.play)
            group("History", SidebarSection.history)
            Spacer(minLength: 12)
            row(.settings)
        }
        .padding(.horizontal, 12).padding(.vertical, 14)
        .frame(width: Self.width)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(LGColor.sidebar.ignoresSafeArea())
    }

    private func group(_ title: LocalizedStringKey, _ items: [SidebarSection]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .lgText(LGTextStyle(size: 12, weight: .semibold, relativeTo: .caption), color: LGColor.gaugeLabel)
                .padding(.horizontal, 12).padding(.top, 16).padding(.bottom, 6)
                .accessibilityAddTraits(.isHeader)
            ForEach(items, id: \.self) { row($0) }
        }
    }

    private func row(_ section: SidebarSection) -> some View {
        let chosen = selection == section
        return Button { selection = section } label: {
            HStack(spacing: 8) {
                Image(systemName: Self.symbol(section))
                    .font(.system(size: 15, weight: .regular))
                    .frame(width: 22)
                    .accessibilityHidden(true)
                Text(section == .year ? LocalizedStringKey("Your \(yearTitle)") : Self.title(section))
                    .lgText(LGTextStyle(size: 15, weight: chosen ? .semibold : .regular, relativeTo: .subheadline))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(height: 40)
            .background(chosen ? LGColor.sidebarSelection : .clear, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .lgPointerHighlight()
        .accessibilityAddTraits(chosen ? .isSelected : [])
    }

    static func title(_ section: SidebarSection) -> LocalizedStringKey {
        switch section {
        case .today: "Today"
        case .week: "This week"
        case .longGame: "The long game"
        case .calendar: "Calendar"
        case .growth: "Growth"
        case .year: "Your year"
        case .settings: "Settings"
        }
    }

    private static func symbol(_ section: SidebarSection) -> String {
        switch section {
        case .today: "sun.max"
        case .week: "calendar.day.timeline.left"
        case .longGame: "mountain.2"
        case .calendar: "calendar"
        case .growth: "chart.line.uptrend.xyaxis"
        case .year: "sparkles"
        case .settings: "gearshape"
        }
    }
}

/// The view's title at 28 pt with the two capsule buttons on the right.
struct SidebarTitleBar: View {
    let title: LocalizedStringKey
    let startTitle: String
    let onAddHours: () -> Void
    let onStart: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(title).lgText(.ipadBarTitle)
                .lineLimit(1).minimumScaleFactor(0.6)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 12)
            Button("Add past hours", action: onAddHours).buttonStyle(BarCapsule(navy: false))
            Button(startTitle, action: onStart).buttonStyle(BarCapsule(navy: true))
        }
        .padding(.horizontal, 24)
        .frame(height: 64)
    }
}

private struct BarCapsule: ButtonStyle {
    let navy: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .lgText(LGTextStyle(size: 15, weight: .semibold, relativeTo: .subheadline), color: navy ? .white : LGColor.ink)
            .lineLimit(1)
            .padding(.horizontal, navy ? 18 : 16)
            .frame(minHeight: 40)
            .background(navy ? LGColor.ink : LGColor.sidebar, in: Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
            .contentShape(Capsule())
            .lgPointerLift()
    }
}

/// A white card with 16 pt corners, as in the card column.
struct IPadCard<Content: View>: View {
    var padding = EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18)
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lgCard(radius: 16)
    }
}

/// "12 h/wk · Your chosen pace": one cell of the numbers card.
struct IPadStat: View {
    let value: String
    let label: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value).lgText(LGTextStyle(size: 22, weight: .bold, relativeTo: .title2, tracking: -0.44))
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(label).lgText(LGTextStyle(size: 13, weight: .regular, relativeTo: .footnote), color: LGColor.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Your chosen pace · Finish line · By Nov 2027 · Rhythm.
struct IPadNumbersCard: View {
    let pace: String
    let finish: String
    let byValue: String
    let byLabel: String
    let rhythm: String

    var body: some View {
        IPadCard(padding: EdgeInsets(top: 18, leading: 18, bottom: 18, trailing: 18)) {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 16) {
                GridRow {
                    IPadStat(value: pace, label: "Your chosen pace")
                    IPadStat(value: finish, label: "Finish line")
                }
                GridRow {
                    IPadStat(value: byValue, label: LocalizedStringKey(byLabel))
                    IPadStat(value: rhythm, label: "Rhythm")
                }
            }
        }
    }
}

/// "Meet your future self" as a card row.
struct FutureSelfRowCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            IPadCard(padding: EdgeInsets(top: 14, leading: 18, bottom: 14, trailing: 18)) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Meet your future self").lgText(.rowStrong)
                        Text("Where 10,000 hours can take you").lgText(.caption, color: LGColor.inkMuted)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right").lgIcon(13, weight: .semibold)
                        .foregroundStyle(LGColor.inkMuted).accessibilityHidden(true)
                }
                .frame(minHeight: 44)
            }
        }
        .buttonStyle(.plain)
        .lgPointerHighlight()
        .accessibilityHint("Opens a short note about where your hours are heading")
    }
}

// MARK: Pointer

extension View {
    /// A soft highlight under the pointer on rows (a no-op without a pointer, and on the Mac).
    @ViewBuilder func lgPointerHighlight() -> some View {
        #if os(iOS)
        hoverEffect(.highlight)
        #else
        self
        #endif
    }

    /// The lift effect for capsule buttons.
    @ViewBuilder func lgPointerLift() -> some View {
        #if os(iOS)
        hoverEffect(.lift)
        #else
        self
        #endif
    }
}
