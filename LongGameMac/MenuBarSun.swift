import SwiftUI
import SwiftData
import AppKit

// The sun in the Mac menu bar: a small sun with today's time (or the running clock) beside it, and a 320 pt popover.
// Everything shown is worked out from the stored timestamps and saved sessions each time it is drawn.

/// What the menu bar item and its popover need, read from the same store as the window.
@MainActor
struct MenuBarData: DynamicProperty {
    @Query private var crafts: [Craft]
    @Query private var sessions: [Session]
    @Query private var estimates: [YearEstimate]
    @Query private var settingsRows: [AppSettings]
    @Query private var periods: [TargetPeriod]

    struct Figures {
        var craft: Craft
        var total: Double
        var plan: StretchPlan

        /// Today's time with the running session added (it counts towards the day it started).
        func stretch(timer: TimerState?, now: Date) -> StretchState {
            plan.state(running: StretchSource.runningSeconds(timer, craftID: craft.id, now: now))
        }
    }

    /// Nil until a game has been set up.
    func figures(now: Date) -> Figures? {
        guard let craft = crafts.first(where: \.isActive) else { return nil }
        let records = sessions.filter { $0.craftId == craft.id }.map(\.record)
        let weekStart = settingsRows.first?.weekStart ?? .localeDefault
        let summary = ProgressSummary.make(estimates: estimates.filter { $0.craftId == craft.id }.map(\.rate), sessions: records,
                                           onboardingDate: craft.createdAt, weekStart: weekStart, now: now)
        let plan = StretchSource.plan(sessions: records, settings: settingsRows.first, periods: periods, now: now)
        return Figures(craft: craft, total: summary.total, plan: plan)
    }
}

/// What the menu bar buttons do. The window may be closed, so it is opened first, and a command is sent once the
/// screens are there to hear it.
@MainActor
enum MacActions {
    static var mainWindowVisible: Bool { NSApp.windows.contains { $0.isVisible && $0.canBecomeMain } }

    static func openMain(_ open: OpenWindowAction) {
        open(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }

    static func openMain(_ open: OpenWindowAction, then action: @escaping @MainActor () -> Void) {
        let wasVisible = mainWindowVisible
        openMain(open)
        if wasVisible {
            action()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { action() }
        }
    }
}

// MARK: Label

/// The sun with the clock or today's time. The running clock is `Text(timerInterval:)`, which the system keeps
/// ticking from the timestamps; paused and idle times are plain text that changes when the stored data does.
struct MenuBarLabel: View {
    @Environment(TimerStore.self) private var timer
    private let data = MenuBarData()

    var body: some View {
        let now = Date()
        let figures = data.figures(now: now)
        let saved = figures?.plan.doneSaved ?? 0
        HStack(spacing: 4) {
            SunView(face: timer.isActive ? .focus : .happy)
                .frame(width: 16, height: 16)
            if figures != nil {
                clock(saved: saved, now: now).monospacedDigit()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(MenuBarText.accessibilityLabel(timer: timer.state, savedToday: saved, now: now))
    }

    @ViewBuilder
    private func clock(saved: TimeInterval, now: Date) -> some View {
        if let state = timer.state, !state.isPaused(at: now) {
            // Elapsed time is (now - startedAt - accumulated pause), so the clock counts up from that moment.
            let from = state.startedAt.addingTimeInterval(state.accumulatedPause)
            Text(timerInterval: from...from.addingTimeInterval(TimerState.autoPauseAfter), pauseTime: nil, countsDown: false, showsHours: false)
        } else {
            Text(MenuBarText.title(timer: timer.state, savedToday: saved, now: now))
        }
    }
}

// MARK: Popover

struct MenuBarPopover: View {
    @Environment(TimerStore.self) private var timer
    @Environment(CommandCenter.self) private var commands
    @Environment(\.openWindow) private var openWindow
    private let data = MenuBarData()

    var body: some View {
        TimelineView(.periodic(from: .now, by: MenuBarText.ticksEverySecond(timer: timer.state) ? 1 : 30)) { context in
            let now = context.date
            Group {
                if let figures = data.figures(now: now) {
                    content(figures, now: now)
                } else {
                    notSetUp
                }
            }
        }
        .frame(width: 320)
        .background(LGColor.background)
        .environment(\.colorScheme, .light)
    }

    @ViewBuilder
    private func content(_ f: MenuBarData.Figures, now: Date) -> some View {
        let stretch = f.stretch(timer: timer.state, now: now)
        VStack(alignment: .leading, spacing: 14) {
            header(f)
            if let state = timer.state {
                sessionCard(state, now: now)
                arc(stretch, title: MenuBarText.todayLine(stretch), big: false)
                HStack(spacing: 10) {
                    Button { timer.togglePause() } label: {
                        row(Text(MenuBarText.pauseTitle(timer: state, now: now)), shortcut: "Space")
                    }
                    .buttonStyle(.lg(.secondary))
                    .keyboardShortcut(.space, modifiers: [])
                    Button { MacActions.openMain(openWindow) { timer.finishRequested = true } } label: {
                        Text("Finish").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.lg(.primary))
                }
            } else {
                arc(stretch, title: MenuBarText.idleCaption(stretch), big: true)
                Button { MacActions.openMain(openWindow) { commands.send(.startOrFinish) } } label: {
                    row(Text("Start session"), shortcut: "⌘N")
                }
                .buttonStyle(.lg(.primary))
                .keyboardShortcut("n", modifiers: .command)
                Button { MacActions.openMain(openWindow) { commands.send(.addHours) } } label: {
                    link("Add past hours", shortcut: "⌘L")
                }
                .buttonStyle(.plain)
                .keyboardShortcut("l", modifiers: .command)
            }
            Divider().overlay(LGColor.divider)
            Button { MacActions.openMain(openWindow) } label: {
                link("Open Long Game", shortcut: "⌘O")
            }
            .buttonStyle(.plain)
            .keyboardShortcut("o", modifiers: .command)
        }
        .padding(16)
    }

    private var notSetUp: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose your game first").lgText(.rowStrong)
            Text("Open Long Game to pick the craft you want to play.").lgText(.caption, color: LGColor.inkMuted)
            Button { MacActions.openMain(openWindow) } label: { Text("Open Long Game").frame(maxWidth: .infinity) }
                .buttonStyle(.lg(.primary))
        }
        .padding(16)
    }

    private func header(_ f: MenuBarData.Figures) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(f.craft.name).lgText(.rowStrong).lineLimit(1)
            Spacer(minLength: 8)
            Text("\(DurationFormat.grouped(Int(f.total))) of 10,000 h").lgText(.caption, color: LGColor.inkMuted)
        }
        .accessibilityElement(children: .combine)
    }

    /// The navy card: the focus sun, "This session", the clock and the next ray.
    private func sessionCard(_ state: TimerState, now: Date) -> some View {
        HStack(spacing: 14) {
            SunView(face: .focus).frame(width: 64, height: 64).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("This session").lgText(.caption, color: .white.opacity(0.7))
                Text(DurationFormat.clock(seconds: state.elapsed(at: now)))
                    .lgText(LGTextStyle(size: 38, weight: .light, relativeTo: .largeTitle, tracking: -1.4), color: .white)
                    .monospacedDigit()
                Text(state.isPaused(at: now) ? "Paused" : MenuBarText.nextRay(timer: state, now: now))
                    .lgText(.caption, color: LGColor.mote)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LGColor.ink, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(MenuBarText.accessibilityLabel(timer: state, savedToday: 0, now: now))
    }

    /// Today's arc with the sun on it, and the words under it.
    private func arc(_ stretch: StretchState, title: String, big: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if big {
                Text("Today").lgText(.label, color: LGColor.inkMuted)
                Text(MenuBarText.bigTime(stretch)).lgText(.bigNumber)
                Text(title).lgText(.row, color: LGColor.inkMuted)
            }
            let g = ArcGeometry(centreX: 144, baseY: 62, radiusX: 118, radiusY: 52, sunSize: 30)
            ZStack(alignment: .topLeading) {
                StretchArcLayer(geometry: g, fraction: stretch.fraction)
                SunView(face: stretch.isCovered ? .happy : .focus)
                    .frame(width: g.sunSize, height: g.sunSize)
                    .offset(x: g.point(stretch.fraction).x - g.sunSize / 2, y: g.point(stretch.fraction).y - g.sunSize / 2)
                Rectangle().fill(LGColor.seaFill).frame(width: 288, height: 14).offset(y: 62)
            }
            .frame(width: 288, height: 76, alignment: .topLeading)
            .clipped()
            if !big {
                Text(title).lgText(.row, color: LGColor.inkMuted)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(StretchText.description(stretch))
    }

    private func row(_ title: Text, shortcut: String) -> some View {
        HStack {
            title
            Spacer(minLength: 8)
            Text(shortcut).opacity(0.65)
        }
        .frame(maxWidth: .infinity)
    }

    private func link(_ title: LocalizedStringKey, shortcut: String) -> some View {
        HStack {
            Text(title).lgText(.row)
            Spacer(minLength: 8)
            Text(shortcut).lgText(.caption, color: LGColor.inkMuted)
        }
        .frame(minHeight: 30)
        .contentShape(Rectangle())
    }
}

// MARK: Dock

/// "Show in Dock": on by default. Off uses the accessory policy, so only the menu bar sun remains.
@MainActor
enum MacDock {
    static func apply(show: Bool) {
        let policy: NSApplication.ActivationPolicy = show ? .regular : .accessory
        guard NSApp.activationPolicy() != policy else { return }
        NSApp.setActivationPolicy(policy)
        // The window stays in front after the Dock icon comes or goes.
        NSApp.activate(ignoringOtherApps: true)
    }
}

final class MacAppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(DockVisibility.isShown() ? .regular : .accessory)
    }

    /// Closing the window leaves the sun in the menu bar.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
