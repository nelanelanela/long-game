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

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let elapsed = timer.elapsed(at: context.date)
            let paused = timer.isPaused(at: context.date)
            WatchTimerView(craftName: timer.craftName, elapsed: elapsed, paused: paused,
                           baseTotal: store.homeState(now: context.date)?.widget.total ?? 0,
                           onPauseOrResume: { store.pauseOrResume() }, onFinish: { store.finish() })
                .onChange(of: SunHour(elapsed: elapsed).litRays) { _, rays in
                    guard !paused else { return }
                    // Ray 0 again means a full hour just completed: a golden hour.
                    WKInterfaceDevice.current().play(rays == 0 ? .success : .click)
                }
        }
    }
}
