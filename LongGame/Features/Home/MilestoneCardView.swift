import SwiftUI

/// The milestone card to share (update 42, `design/redesign/MilestoneCard.dc.html`): a 360 × 640 pt layout rendered
/// at 3x (1080 × 1920) like the year card. The dawn sky with the moon to the right, the still sea, the sun with the
/// celebrate face; the craft, the big number, the milestone line, the day it was reached; the year card's footer.
/// No animation of any kind, and always in the light look (the look of share cards is chosen when sharing).
struct MilestoneCardView: View {
    struct Content: Equatable {
        var hours: Int
        var craftName: String
        var reached: Date
        var startYear: Int
    }

    let content: Content

    var body: some View {
        ZStack(alignment: .top) {
            LGColor.paper
            SkyView(tone: .dawn, horizon: 0.86, moon: true, moonAt: CGPoint(x: 0.8, y: 0.3))
                .frame(width: 360, height: 420)
            SunView(idle: false, face: .celebrate)
                .frame(width: 130, height: 130)
                .offset(y: 214)
            LandView(tone: .day, still: true)
                .frame(width: 360, height: 120)
                .offset(y: 315)
            VStack(spacing: 8) {
                Text("A milestone in the long game")
                    .textCase(.uppercase)
                    .font(.system(size: 11, weight: .semibold)).tracking(1.76)
                    .foregroundStyle(LGColor.milestoneGold)
                Text(verbatim: content.craftName)
                    .font(.system(size: 30, weight: .bold)).tracking(-0.6)
                    .foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 46)
            VStack(spacing: 0) {
                Text(verbatim: MilestoneCardText.number(content.hours))
                    .font(.system(size: 56, weight: .bold)).tracking(-2.2)
                    .monospacedDigit()
                    .foregroundStyle(LGColor.navy)
                    .lineLimit(1).minimumScaleFactor(0.6)
                Text(verbatim: Milestones.message(hours: content.hours, craft: content.craftName))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(LGColor.navy)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
                Text(verbatim: MilestoneCardText.reached(on: content.reached, startYear: content.startYear))
                    .font(.system(size: 13))
                    .foregroundStyle(LGColor.inkMuted)
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    SunView(idle: false, face: .happy).frame(width: 18, height: 18)
                    Text("Long Game · the longest game, played in real life")
                }
                .font(.system(size: 11)).foregroundStyle(LGColor.inkMuted)
            }
            .padding(.horizontal, 24)
            .padding(.top, 446)
            .padding(.bottom, 20)
        }
        .frame(width: 360, height: 640)
        .clipped()
        .environment(\.colorScheme, .light)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: MilestoneCardText.spoken(hours: content.hours, craft: content.craftName,
                                                                     on: content.reached)))
        .accessibilityAddTraits(.isImage)
    }
}

/// "Share this moment" on the celebration: translucent white, 50 pt, a thin navy outline, with the share icon.
/// The card is made when the celebration opens; the button waits (dimmed) until it's ready.
struct ShareMomentButton: View {
    let content: MilestoneCardView.Content
    @State private var url: URL?

    var body: some View {
        Group {
            if let url {
                ShareLink(item: url, preview: SharePreview(Text(verbatim: MilestoneCardText.spoken(
                    hours: content.hours, craft: content.craftName, on: content.reached)))) { label }
            } else {
                label.opacity(0.5)
            }
        }
        .buttonStyle(.plain)
        .task(id: content) {
            url = YearCardRender.png(MilestoneCardView(content: content),
                                     name: MilestoneCardText.fileName(hours: content.hours, craft: content.craftName))
        }
    }

    private var label: some View {
        Label("Share this moment", systemImage: "square.and.arrow.up")
            .lgText(.button, color: LGColor.ink)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 50)
            .background(LGColor.shareMomentFill, in: Capsule())
            .overlay(Capsule().strokeBorder(LGColor.ink.opacity(0.12), lineWidth: 1))
            .contentShape(Capsule())
    }
}

#Preview("Milestone card") {
    MilestoneCardView(content: .init(hours: 1_000, craftName: "Piano", reached: Date(), startYear: 2019))
}
