import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

@main
struct LongGameWidgetsBundle: WidgetBundle {
    var body: some Widget {
        SunWidget()
        OverviewWidget()
        TimerLiveActivity()
        if #available(iOS 18.0, *) {
            SessionControl()
        }
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
    var hidden = true
    var body: some View {
        SunView(idle: false, face: state.pausedElapsed != nil ? .sleepy : state.dayComplete ? .happy : .focus,
                litRays: state.litRays,
                rayColor: LGColor.sunRaysBright)
            .accessibilityHidden(hidden)
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
                .accessibilityElement(children: .combine)
                .accessibilityValue(context.state.pausedElapsed == nil ? Text("Running") : Text("Paused"))
                Spacer()
                Button(intent: PauseResumeSessionIntent()) {
                    Image(systemName: context.state.pausedElapsed == nil ? "pause.fill" : "play.fill")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .background(.white.opacity(0.14), in: Circle())
                .accessibilityLabel(context.state.pausedElapsed == nil ? "Pause" : "Resume")
                Button(intent: FinishTimerIntent()) {
                    Image(systemName: "checkmark")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .background(.white.opacity(0.14), in: Circle())
                .accessibilityLabel("Finish")
            }
            .foregroundStyle(.white)
            .padding(16)
            // The night land along the bottom edge, still: Live Activities can't animate.
            .background(alignment: .bottom) {
                LandView(tone: .night, still: true)
                    .frame(height: 70)
                    .accessibilityHidden(true)
            }
            .activityBackgroundTint(LGColor.night)
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
                        Button(intent: PauseResumeSessionIntent()) {
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
                    .accessibilityLabel(Text("Session timer"))
                    .accessibilityValue(context.state.pausedElapsed == nil ? Text("Running") : Text("Paused"))
            } minimal: {
                ActivitySun(state: context.state, hidden: false).frame(width: 22, height: 22)
                    .accessibilityLabel(Text("Long Game session"))
                    .accessibilityValue(context.state.pausedElapsed == nil ? Text("Running") : Text("Paused"))
            }
        }
    }
}
