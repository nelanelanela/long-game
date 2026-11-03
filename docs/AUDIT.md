# Audit: app vs `docs/SPEC.md` and `design/`

Source of truth: the spec. ✅ done · 🟡 partly done · ❌ missing.
Updated after update prompt 09 (your pace for the year, Home tabs, widgets, Apple Watch). Every row shows its final status, with what changed in the Note column.
Updated after the fixes: every row below shows its final status, with what changed in the Note column. Decisions for you, the things I could not do and how to check each flow are at the bottom.

## Data and maths

| Requirement | Status | Where | Note |
| --- | --- | --- | --- |
| Four entities Craft, YearEstimate, Session (timer/manual/catchUp), Settings | ✅ | `Models/Models.swift` | Settings is `AppSettings`. `syncEnabled` exists but the toggle only wrote UserDefaults |
| Totals always derived, never stored | ✅ | `Logic/Summary.swift`, `Logic/Basics.swift` | |
| Baseline, logged, total | ✅ | `Logic/Basics.swift` | |
| Progress capped at 100%, keeps counting | ✅ | `Totals.progress/percent` | |
| This week, Pace (12 weeks, blended with latest estimate) | ✅ | `WeekMath`, `Pace` | |
| One active craft; archived crafts read-only | ✅ | `AppRoot`, `OneCraftSheet`, `ArchivedCraftsView` | |
| "Logged hours" only from after onboarding | ✅ | `SessionFormView` | Fixed: the add-hours calendar now starts on the onboarding day, so nothing is counted twice |
| Settings: `weeklyTargetHours`, `targetSetAt`, `targetEndsAt`, `lastHomeTab`; `TargetPeriod` history (hours, start, end) | ✅ | `Models/Models.swift`, `TargetSaving` | Also `targetPromptShownAt`, so the new-year sheet opens once. A new target moves the old one into `TargetPeriod`; past weeks use the target of their last day (`TargetHistory`) |
| The 12 months run from the day the target is set | ✅ | `WeeklyTarget.endDate` | Counted from the start of that day, so it ends at midnight 12 months later |
| Forecast uses the target for those 12 months only when the recent pace is within 25% of it | ✅ | `WeeklyTarget.forecastWindow`, `ForecastEngine.monthlyRate` | Mid line only; the low/high band is unchanged. The Growth tab and its what-if use it too |
| The SwiftData database stays where it always was | ✅ | `CloudSync.configuration` | Fixed in Part 4: once the app had an App Group, SwiftData's default moved the database into the group's folder, which would have left saved data behind. It is pinned to the app's own folder and `StoreLocationTests` guards it |

## Onboarding

| Requirement | Status | Where | Note |
| --- | --- | --- | --- |
| Welcome: sunrise gradient, sun, Get started, no quote | ✅ | `WelcomeView` | |
| "I already have an account": Sign in with Apple + iCloud restore | 🟡 | `WelcomeView` | Still a stub alert. Needs your Apple Developer account and a real iCloud to build and test, see Decisions |
| Your craft: search, five groups, custom name 2–40 | ✅ | `CraftStepView`, `CraftCatalog` | |
| When did you start: stepper, default year − 3, 1940…now | ✅ | `StartYearView` | |
| Current year skips step 3 | ✅ | `StartYearView`, `YearlyHoursView` | Decided: no skip. Step 3 shows one slider for this year; set it to 0 if starting from scratch. Spec updated |
| Hours per week: one slider per year 0–40, live estimate, Continue | ✅ | `YearlyHoursView` | Design file says max 30; spec says 40, code follows spec. The button now says Continue |
| Step dots show 4 steps | ✅ | `LGStepBar`, `OnboardingHeader` | |
| Step 4 "Your pace for the year": big number, slider 1–40 by 0.5, recent pace, Until / About / In a year, Start playing | ✅ | `WeeklyTargetView`, `OnboardingFlow` | Start playing saves the craft, estimates and target and opens Home on This week |
| Edit from Home: Save restarts the 12 months today | ✅ | `WeeklyTargetView`, `TargetSaving` | |
| Reminder 14 days before the end; "A new year of pace" sheet once, old value filled in | ✅ | `TargetCycle`, `TargetRow`, `HomeView` | After the end date the reminder stays in the target row until a new target is set. A game with no target yet gets the same sheet once, titled "Your pace for the year" |

## Home

| Requirement | Status | Where | Note |
| --- | --- | --- | --- |
| No cards; segmented control This week \| The long game under the header; remembers the last tab | ✅ | `HomeView`, `LGSegmentedControl`, `AppRoot` | After onboarding it opens on This week |
| Sun as a gauge: vertical scale, navy pill at the sun's height, dashed gold line | ✅ | `GaugeHero`, `GaugeGeometry` | Scale labels use #68718C instead of the design's #8A93AB (2.9:1) to reach 4.5:1 |
| Sun's centre linear from the horizon to the top tick; above 100% it stays up with open eyes | ✅ | `GaugeGeometry.centreY`, `HomeGauge.reachedTop` | Matches the design's heights (6.5 of 12 h at 146 pt, 3,294 h at 175 pt) |
| This week scale 0 → target (ticks 0, half, target); long game 0 → 10,000 (every 2,500) | ✅ | `HomeGauge` | With no target yet, this week's scale uses the recent pace rounded |
| Tab switch: sun glides 0.6 s, labels cross-fade | ✅ | `GaugeHero` (animatable), `HomeView.selectTab` | Checked frame by frame. With Reduce Motion the sun jumps and only the labels fade |
| This week: "6.5 h", "of 12 h this week · 54%", 7 day bars, target row | ✅ | `CountingWeek`, `DayBarsRow`, `TargetRow` | The percentage is never 100% before the target is met |
| Day bar tap opens that day in History | ✅ | `DayBarsRow`, `HistoryView(day:)`, `CalendarTab` | Days still to come are not buttons |
| Target row: "5.5 h to go · 3 days left" / "Target reached · +1.5 h", "Your pace for the year…", opens the target screen | ✅ | `TargetRow`, `WeekTarget` | |
| The long game: total, "of 10,000 hours · N%", Pace / By Nov 2027 / Finish line, Meet your future self row | ✅ | `CountingTotal`, `HomeView` | "By …" is the target times the share of the year left; "–" with no target. The row has no sun icon, as in the design |
| Recent rows removed from Home | ✅ | `HomeView` | Sessions live in History and on the day bars |
| Opaque sea always covers the lower sun; animation and Reduce Motion kept | ✅ | `SunriseCanvas`, `SeaFill`, `AboveWater` | Pixel tests at 8 heights, 3 widths and every wave phase |
| Start session / Add past hours; "Back to session" or "Resume" | ✅ | `HomeView` | Your checklist says "Resume" while running; the spec says "Back to session" |
| Header only History and + | ✅ | `HomeView`, `HistoryView` | Settings is a gear at the top right of History |
| No info icon, About, Line of the day | ✅ | | `design/About.dc.html` is still in the folder (not in the app) |

## History

| Requirement | Status | Where | Note |
| --- | --- | --- | --- |
| Calendar: 53 weeks, blue rest, four levels, tap a day, edit/delete | ✅ | `CalendarTab`, `Practice.swift` | |
| Rhythm, Steady for, Active days; no streaks; no icon by Rhythm | ✅ | `CalendarTab`, `Practice.swift` | `README.md` and `CLAUDE.md` said "streaks": reworded |
| Growth: past, dashed forecast, band, sun, "Finish line · 10,000 h", no legend, no weekly card | ✅ | `GrowthTab` | |
| Forecast per "Forecast algorithm" (30 y limit, blended pace) | ✅ | `Logic/Forecast.swift` | |
| "after YYYY" for a scenario that misses 30 years | ✅ | `ForecastText.range` | Fixed: "Likely between 2034 and after 2056" |
| "Not within 30 years" text | ✅ | `ForecastText.range` | |
| What-if slider live, not saved | ✅ | `GrowthTab` | |

## Timer

| Requirement | Status | Where | Note |
| --- | --- | --- | --- |
| Timestamp-based, survives closing | ✅ | `TimerState`, `TimerStore` | |
| Live Activity + Dynamic Island with Pause/Resume and Finish | ✅ | `LongGameWidgets` | Fixed: lock-screen buttons now have VoiceOver labels (Pause/Resume, Finish). Not testable in the Simulator |
| Finish sheet: duration ±5 min, note, Save, Discard | ✅ | `FinishSheet` | |
| 4 h notification, 12 h auto-pause | ✅ | `Notifications`, `TimerState` | |
| Total in gold with one decimal, counting up | ✅ | `TimerView` | |
| "This session" + clock + caption "Next ray in m:ss" only | ✅ | `TimerView`, `SunHour.caption` | |
| Animation table rows | ✅ | `TimerView`, `SunView`, `TimerSky` | Breathing, halo, motes, turning, rays, wink, sky, golden hour, pause, resume, finish all present |
| Hour bounce + sparkle ring | ✅ | `TimerMoments`, `TimerView` | |
| No quote | ✅ | | |
| Reduce Motion | ✅ | `TimerView`, `HomeView` | Fixed: the "Saved" burst and jump, and the Home count-up, now respect Reduce Motion |
| Text contrast ≥ 4.5:1 on the timer sky | ✅ | `TimerSky`, `TimerView` | Fixed: the sky now ends in plum (#7B4378, as dark as the design's #6E3D74) and secondary text is 80% white: 4.9:1 or better everywhere |
| VoiceOver "N of 12 rays lit, M minutes…" with correct plural | ✅ | `TimerView`, `TimerLogic` | Fixed: "1 minute into this hour" |

## Other flows

| Requirement | Status | Where | Note |
| --- | --- | --- | --- |
| Add past hours: day, hours 0–12, minutes by 5, note 280, "Add N hours", no future, ≤ 24 h a day | ✅ | `SessionFormView` | Date picker lower bound fixed (see above) |
| One craft sheet and confirmation and archiving | ✅ | `OneCraftSheet` | Spec Screen 0 says Welcome shows "after Replace my craft"; Screen 8 says it opens step 1. Decided: Welcome shows again; code and spec updated |
| Welcome back: 7-day rule, once per 7 days, week sliders, average slider, even split, "Added after a break" | ✅ | `CatchUp.swift`, `CatchUpSheet` | |
| Welcome back copy | ✅ | `CatchUpSheet` | Fixed: copy says "practise" in all three places; the sun has open eyes |

## Accounts, sync, notifications, settings

| Requirement | Status | Where | Note |
| --- | --- | --- | --- |
| Works with no account | ✅ | | |
| Sign in with Apple, CloudKit private DB | 🟡 | `CloudSync.swift`, `SettingsView` | Built and in the project; the toggle now also saves `Settings.syncEnabled`. Cannot be tested here (needs your iCloud account and a real device) |
| Export CSV, Delete all data | ✅ | `SettingsView` | |
| YearEstimates editable; archived crafts listed | ✅ | `EstimatesEditorView`, `ArchivedCraftsView` | |
| Settings reachable | ✅ | `HistoryView` | Now via the gear in History |
| Notifications off by default, asked after first saved session | ✅ | `HomeView`, `Notifications` | |
| Daily reminder | ✅ | `NotificationPlanner` | |
| Rhythm nudge (no streak notification) | ✅ | `ReminderPlanner` | |
| Long session | ✅ | `Notifications` | |
| Milestone notification | ✅ | `Milestones.nextCrossing`, `Notifications`, `HomeView` | Added: while a session runs, a notification is planned for the moment its hours carry the total over the next milestone; pausing or finishing cancels it |
| Milestones 100…10,000, each once | ✅ | `Milestones`, `HomeView` | |

## Look and copy

| Requirement | Status | Where | Note |
| --- | --- | --- | --- |
| Flat cards, no shadows | ✅ | `LGCardModifier` | |
| Tokens and sizes from Visual system | ✅ | `Colors`, `Typography` | |
| SF Pro only; no serif/Newsreader | ✅ | | |
| Every string in the String Catalog | ✅ | `Localizable.xcstrings`, `project.yml` | Fixed: 83 missing strings added, 3 stale ones removed; `SWIFT_EMIT_LOC_STRINGS` turned on so Xcode keeps it in step |
| Pluralised number+word labels | ✅ | `Labels.swift` | The rays VoiceOver line is now pluralised too |
| Dynamic Type up to XXXL | ✅ | | Checked at the largest accessibility size on Home, History and Settings. Text wraps and numbers scale down; the stats tiles got a little extra side padding |
| VoiceOver labels on icon buttons and charts | ✅ | | Lock-screen buttons labelled |
| Reduce Motion everywhere | ✅ | | See Timer |
| Minimum 44 pt touch target | 🟡 | `CalendarTab` | The 14 pt calendar squares are smaller by design; the day still opens from a tap |

## Widgets

| Requirement | Status | Where | Note |
| --- | --- | --- | --- |
| Small: sun over the sea at the right height, "6.5 h / of 12 h this week"; App Intent choice This week / The long game | ✅ | `SunWidget`, `SmallSunWidgetView`, `ChooseViewIntent` | Checked on a Simulator Home Screen (it showed "3 h", then "4 h" after saving an hour). The Edit Widget choice itself was not tapped |
| Medium: this-week scene, two bars (gold, navy), "Today 1 h 30 m" | ✅ | `OverviewWidget`, `MediumSunWidgetView` | Drawn and compared with the design; the long-game bar opens the long game tab |
| Lock Screen circular, rectangular, inline | ✅ | `CircularSunWidgetView`, `RectangularSunWidgetView`, `InlineSunWidgetView` | Drawn in tests; not seen on a real Lock Screen. They follow the Lock Screen tint |
| Opaque sea covers the sun at every height | ✅ | `WidgetPictureTests` | Both sizes, three widths |
| Shared App Group data | ✅ | `WidgetSnapshot`, `WidgetBridge` | The app mirrors only what is stored (no totals); the widgets compute with the same Logic |
| Deep link into Home on the matching tab | ✅ | `WidgetLink`, `HomeView.onOpenURL`, `project.yml` | `longgame://home/week` and `longgame://home/longGame`; checked in the Simulator |
| Reload when a session is saved, at midnight, at the start of each week | ✅ | `WidgetBridge.publish`, `WidgetModel.timelineDates` | |

## Apple Watch

| Requirement | Status | Where | Note |
| --- | --- | --- | --- |
| Two swipeable pages (This week with Start, The long game): sun, scale, big number | ✅ | `WatchHomePage`, `WatchScene`, `WatchRoot` | Drawn and compared with the design; not run on a watch (no watchOS Simulator is installed) |
| Timer: focus sun with lit rays, clock, total and next ray, Pause/Resume, Finish | ✅ | `WatchTimerView`, `WatchRoot` | "3,294.7 h · next ray 2:42" matches the design |
| Haptic when a ray lights | 🟡 | `WatchRoot` (`WKInterfaceDevice`) | Plays while the app is on screen. The watch stops the app when the wrist drops, so no tap in the background |
| Finished screen | ✅ | `WatchFinishedView` | Under a minute nothing is saved |
| Complications: circular, rectangular, corner, inline | ✅ | `LongGameWatchWidgets` | Built; not seen on a watch face |
| One session at a time across phone and watch | ✅ | `TimerUpdate`, `TimerStore.applyRemote`, `WatchStore`, `WatchBridge` | The newest change wins; the watch's Start becomes the phone's "Back to session" and its Live Activity |
| Saved sessions | ✅ | `FinishedSession`, `WatchBridge.save`, `PendingSessions` | See Decisions: sent over WatchConnectivity, saved once on the phone (same id) |
| Phone out of reach: watch keeps the session and sends it later | ✅ | `WatchConnection.send`, `PendingSessions` | Queued by the system; it still counts on the watch until the phone has it |
| "Set up Long Game on your iPhone first." | ✅ | `WatchSetupView` | |

## Edge cases

| Requirement | Status | Where |
| --- | --- | --- |
| Time-zone/clock change during a timer | ✅ | `TimerState` (absolute timestamps) |
| Session crossing midnight counts on its start day | ✅ | `Practice.dailySeconds` |
| Editing estimates later, no repeat celebrations | ✅ | `EstimatesEditorView` |
| Deleting a day's only session turns it back to rest | ✅ | `PracticeDaysTests` |
| Passing 10,000 h | ✅ | `Totals`, `SunriseScene` |
| Far-back start year: "Set all to" | ✅ | `YearlyHoursView` |

## Tests

| Requirement | Status | Where |
| --- | --- | --- |
| Baseline, pace, forecast | ✅ | `LogicTests` |
| Rhythm, Steady for | ✅ | `RhythmTests` |
| Catch-up gap, week blocks, even split, once-a-week rule | ✅ | `CatchUpTests` |
| 24 h day limit | ✅ | `SummaryTests.dayLimit` |
| Pluralisation | ✅ | `LabelTests` |
| Milestone notification timing, "after YYYY" text, comma grouping | ✅ | `AuditTests` |
| 12-month window, TargetPeriod history, end-of-year reminder and sheet, forecast rule, week row text | ✅ | `WeeklyTargetTests` |
| Gauge mapping, ticks, day bars, year outlook; sea covers the sun at every height | ✅ | `HomeGaugeTests`, `SunriseTests` |
| Widget numbers, timeline dates, deep links, shared snapshot, widget pictures | ✅ | `WidgetTests` |
| Phone-watch messages, newest timer wins, pending sessions, saving once, watch screens and sea | ✅ | `WatchTests` |
| The database stays in the app's folder | ✅ | `StoreLocationTests` |

## Decisions for you

1. **"I already have an account" on Welcome.** Sign in with Apple and iCloud restore are in the project (Settings has them), but Welcome still shows a placeholder alert. Wiring it needs your Apple Developer account and a device signed in to iCloud to test, and CloudKit only loads at launch, so "restore" means signing in, then restarting. Tell me when you want me to do it.
2. ~~Starting this year skips step 3?~~ Decided: no skip. Step 3 shows one slider for this year, and the spec now says so.
3. ~~Welcome after "Switch to a new game"?~~ Decided: show Welcome again. App and spec (Screen 8) updated.
4. **Settings entry.** The spec's Home header has only History and +, so Settings now lives behind a gear at the top right of History. If you would rather have it somewhere else, say so.

5. **Pace and the 25% rule.** I compared the target with the Home **Pace** stat (the recent pace, blended with your estimate early on). Tell me if you meant the forecast pace.
6. **"In a year" on the target screen** shows what a target *would* do (finish date with 12 months on that rate), even when your pace is too far from it for Home's forecast to use it. A bold target can therefore show an earlier finish there than on Home.
7. **Watch data: WatchConnectivity, not a CloudKit database on the watch.** The spec says the watch uses "the shared CloudKit store". That would need its own iCloud setup on the watch and sync switched on, so instead the phone stays the one store: it sends the watch its stored data, and a session finished on the watch travels to the phone (queued, saved once). iCloud sync of the phone's database is untouched. Say if you want the CloudKit route later.
8. **Apple Developer account, once you build to real devices.** The App Group `group.com.wehavesun.LongGame` is in the app, the widgets and both watch targets. The watch app is `com.wehavesun.LongGame.watchkitapp` and its complications `…watchkitapp.Widgets`. I did not touch your account: with automatic signing Xcode should offer to register these when you build to a device.
9. **Two sessions in one folder.** A second Claude session (iPhone Duo) edited this folder at the same time, so some changes are mixed (see the commit messages). Using separate worktrees avoids it.

## Where the spec and a design file disagree (the spec won)

| Where | Design says | Spec says | App does |
| --- | --- | --- | --- |
| Hours per week, each year | Slider 0–30 | 0–40 | 0–40 |
| Welcome back | "Did you keep playing since then?" | "Did you practise since then?" | Spec |
| Add past hours | Typed numbers for hours and minutes | Hours 0–12, minutes in 5s | Pickers, per spec |
| Calendar Rhythm | Median of the last 8 weeks, current week counted for Steady for | 8 complete weeks plus the current week | Spec. An unfinished current week never ends a run |
| Timer sky | Ends at #6E3D74 | Navy to violet to rose | Ends in plum for contrast (4.5:1) |
| Home button while a timer runs | n/a | "Back to session" (your checklist says "Resume") | Spec |

Also: the spec's Forecast section says the Growth card "still shows the real value" of the yearly trend, but Screen 6 removes the weekly-rate card, so nothing on screen shows it any more.

## Not done or not testable here

- Live Activity and Dynamic Island: built, but the Simulator cannot show them; check on a device.
- iCloud sync, Sign in with Apple and iCloud restore: need your Apple Developer account and a real device.
- The Apple Watch app and complications: no watchOS Simulator is installed here (downloading one is several GB), so they are compiled for the watch simulator SDK and checked through shared code, tests and drawn pictures, but never run. Pairing, WatchConnectivity delivery, haptics and the watch face need a real watch or the watchOS Simulator.
- Lock Screen and medium widgets on a real device, and the Edit Widget choice.
- Real notification delivery (daily, rhythm nudge, long session, milestone): scheduled in code and unit-tested, but not seen arriving.
- The 14 pt calendar squares are smaller than 44 pt by design. Each day is still a single tap target with a VoiceOver label.
- `design/About.dc.html` is still in the folder (the app has no About screen). Delete it if you do not want it.

## How to check the main flows in the Simulator

Run with `-demoData` for sample data.

- **Home:** two tabs. This week: the sun at this week's height on the scale, day bars (tap one), the target row. The long game: total, three stats, Meet your future self.
- **Your pace for the year:** the target row on This week (or step 4 of onboarding). Settings → Debug only → "Year of pace ends in 10 days" / "ended yesterday" shows the reminder and the new-year sheet.
- **Widgets:** long-press the Home Screen → Edit → Add Widget → Long Game. Save a session and the widget redraws.
- **Apple Watch:** open `LongGame.xcodeproj`, run the LongGame scheme on an iPhone paired with a watch (or the watchOS Simulator), then the LongGameWatch scheme target on the watch.
- **Settings:** History → gear at the top right.
- **Welcome back:** Settings → Debug only → set the days with the stepper (7–27 gives week sliders, 28+ gives one average slider) → "Show Welcome back on Home". It takes you back to Home with the sheet open.
- **Hour bounce:** Settings → Debug only → "Jump total to just under a whole hour" → Start session. About 20 seconds later the sun bounces and a ring of sparkles shimmers.
- **Milestone notification:** same jump, but choose a total just under a milestone first (for example edit estimates in Settings → Your estimates so the total is near 100, 500, 1,000…), allow notifications, start a session and lock the phone.
- **Reduce Motion:** Settings app → Accessibility → Motion → Reduce Motion, then save a session.
- **Largest text:** Settings app → Accessibility → Display & Text Size → Larger Text.
