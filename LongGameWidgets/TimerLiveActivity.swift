import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

@main
struct LongGameWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TimerLiveActivity()
    }
}

private func timerText(_ state: TimerActivityAttributes.ContentState) -> Text {
    let range = state.effectiveStart...state.effectiveStart.addingTimeInterval(TimerState.autoPauseAfter)
    if let paused = state.pausedElapsed {
        return Text(timerInterval: range, pauseTime: state.effectiveStart.addingTimeInterval(paused), countsDown: false)
    }
    return Text(timerInterval: range, countsDown: false)
}

private struct ActivitySun: View {
    let state: TimerActivityAttributes.ContentState
    var body: some View {
        SunView(face: state.pausedElapsed == nil ? .focus : .sleepy,
                litRays: state.litRays,
                rayColor: LGColor.sunRaysBright)
    }
}

struct TimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerActivityAttributes.self) { context in
            HStack(spacing: 14) {
                ActivitySun(state: context.state).frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.craftName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                    timerText(context.state)
                        .font(.system(size: 34, weight: .light).monospacedDigit())
                        .foregroundStyle(.white)
                }
                Spacer()
                Button(intent: ToggleTimerIntent()) {
                    Image(systemName: context.state.pausedElapsed == nil ? "pause.fill" : "play.fill")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .background(.white.opacity(0.14), in: Circle())
                Button(intent: FinishTimerIntent()) {
                    Image(systemName: "checkmark")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .background(.white.opacity(0.14), in: Circle())
            }
            .foregroundStyle(.white)
            .padding(16)
            .activityBackgroundTint(LGColor.ink)
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ActivitySun(state: context.state).frame(width: 44, height: 44)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 0) {
                        Text(context.attributes.craftName).font(.caption).foregroundStyle(.secondary)
                        timerText(context.state).font(.system(size: 28, weight: .light).monospacedDigit())
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 10) {
                        Button(intent: ToggleTimerIntent()) {
                            Label(context.state.pausedElapsed == nil ? "Pause" : "Resume",
                                  systemImage: context.state.pausedElapsed == nil ? "pause.fill" : "play.fill")
                        }
                        Button(intent: FinishTimerIntent()) { Label("Finish", systemImage: "checkmark") }
                    }
                    .buttonStyle(.bordered)
                    .tint(LGColor.sunBody)
                }
            } compactLeading: {
                ActivitySun(state: context.state).frame(width: 22, height: 22)
            } compactTrailing: {
                timerText(context.state)
                    .font(.system(size: 13, weight: .medium).monospacedDigit())
                    .frame(maxWidth: 52)
            } minimal: {
                ActivitySun(state: context.state).frame(width: 22, height: 22)
            }
        }
    }
}
