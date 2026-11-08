import SwiftUI
import WatchKit

/// The watch app: Home (two pages, This week and The long game), the timer, the Finished screen, or, until the phone
/// has been set up, a note saying so.
struct WatchRoot: View {
    @Environment(WatchStore.self) private var store

    var body: some View {
        Group {
            if let finished = store.finished, let state = store.homeState() {
                WatchFinishedView(added: WatchModel.addedText(finished), caption: WatchModel.finishedCaption(state)) {
                    store.finished = nil
                }
            } else if let timer = store.timer {
                WatchTimerScreen(timer: timer)
            } else if store.received != nil {
                // The pages redraw each minute, so a new day or week shows up while the watch is awake.
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    if let state = store.homeState(now: context.date) {
                        TabView {
                            WatchHomePage(tab: .week, state: state, onStart: { store.start() })
                            WatchHomePage(tab: .longGame, state: state)
                        }
                        .tabViewStyle(.page)
                    }
                }
            } else {
                WatchSetupView()
            }
        }
        .background(Color.black)
    }
}

/// The running timer, ticking every second from the timestamps. A light tap on the wrist when a ray lights.
private struct WatchTimerScreen: View {
    @Environment(WatchStore.self) private var store
    let timer: TimerState
    @Environment(\.isLuminanceReduced) private var alwaysOn

    var body: some View {
        // Always On updates once a minute; otherwise every second.
        TimelineView(.periodic(from: .now, by: alwaysOn ? 60 : 1)) { context in
            let elapsed = timer.elapsed(at: context.date)
            let paused = timer.isPaused(at: context.date)
            let home = store.homeState(now: context.date)
            WatchTimerView(craftName: timer.craftName, elapsed: elapsed, paused: paused,
                           baseTotal: home?.widget.total ?? 0,
                           doneToday: home?.widget.todaySeconds ?? 0,
                           stretch: home.map { Stretch.stretch(weeklyHours: $0.widget.weekTarget) },
                           onPauseOrResume: { store.pauseOrResume() }, onFinish: { store.finish() })
                .onChange(of: SunHour(elapsed: elapsed).litRays) { _, rays in
                    guard !paused else { return }
                    // Ray 0 again means a full hour just completed: a golden hour.
                    WKInterfaceDevice.current().play(rays == 0 ? .success : .click)
                }
                .onChange(of: covered(elapsed, home)) { was, now in
                    // A longer haptic when the sun is fully up.
                    if now && !was { WKInterfaceDevice.current().play(.notification) }
                }
        }
    }

    private func covered(_ elapsed: TimeInterval, _ home: WatchHomeState?) -> Bool {
        guard let home else { return false }
        let stretch = Stretch.stretch(weeklyHours: home.widget.weekTarget)
        return home.widget.todaySeconds + elapsed >= stretch
    }
}
