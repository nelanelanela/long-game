# Audit: app vs `docs/SPEC.md` and `design/`

Source of truth: the spec. ✅ done · 🟡 partly done · ❌ missing.
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

## Onboarding

| Requirement | Status | Where | Note |
| --- | --- | --- | --- |
| Welcome: sunrise gradient, sun, Get started, no quote | ✅ | `WelcomeView` | |
| "I already have an account": Sign in with Apple + iCloud restore | 🟡 | `WelcomeView` | Still a stub alert. Needs your Apple Developer account and a real iCloud to build and test, see Decisions |
| Your craft: search, five groups, custom name 2–40 | ✅ | `CraftStepView`, `CraftCatalog` | |
| When did you start: stepper, default year − 3, 1940…now | ✅ | `StartYearView` | |
| Current year skips step 3 | ✅ | `StartYearView`, `YearlyHoursView` | Decided: no skip. Step 3 shows one slider for this year; set it to 0 if starting from scratch. Spec updated |
| Hours per week: one slider per year 0–40, live estimate, Start playing | ✅ | `YearlyHoursView` | Design file says max 30; spec says 40, code follows spec |

## Home

| Requirement | Status | Where | Note |
| --- | --- | --- | --- |
| No cards; sun over two wave lines; higher as total grows | ✅ | `SunriseScene` | |
| Total 64 pt, "of 10,000 hours · N%" | ✅ | `SunriseScene.CountingTotal` | Fixed: commas on every device, on Home, Timer, estimates and milestones |
| Stats row between hairlines: This week, Pace, Finish line | ✅ | `HomeView` | Fixed: shows "after 2056" when more than 30 years away |
| Last 2 sessions as plain rows | ✅ | `HomeView` | |
| Start session / Add past hours; "Back to session" or "Resume" | ✅ | `HomeView` | Your checklist says "Resume" while running; the spec (updated at your request) says "Back to session" |
| Header only History and + | ✅ | `HomeView`, `HistoryView` | Fixed: Settings moved to a gear at the top right of History |
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

## Decisions for you

1. **"I already have an account" on Welcome.** Sign in with Apple and iCloud restore are in the project (Settings has them), but Welcome still shows a placeholder alert. Wiring it needs your Apple Developer account and a device signed in to iCloud to test, and CloudKit only loads at launch, so "restore" means signing in, then restarting. Tell me when you want me to do it.
2. ~~Starting this year skips step 3?~~ Decided: no skip. Step 3 shows one slider for this year, and the spec now says so.
3. ~~Welcome after "Switch to a new game"?~~ Decided: show Welcome again. App and spec (Screen 8) updated.
4. **Settings entry.** The spec's Home header has only History and +, so Settings now lives behind a gear at the top right of History. If you would rather have it somewhere else, say so.

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
- Real notification delivery (daily, rhythm nudge, long session, milestone): scheduled in code and unit-tested, but not seen arriving.
- The 14 pt calendar squares are smaller than 44 pt by design. Each day is still a single tap target with a VoiceOver label.
- `design/About.dc.html` is still in the folder (the app has no About screen). Delete it if you do not want it.

## How to check the main flows in the Simulator

Run with `-demoData` for sample data.

- **Home:** sun rising over two waves, total with commas, hairline stats, two recent rows, one button. Header is History and +.
- **Settings:** History → gear at the top right.
- **Welcome back:** Settings → Debug only → set the days with the stepper (7–27 gives week sliders, 28+ gives one average slider) → "Show Welcome back on Home". It takes you back to Home with the sheet open.
- **Hour bounce:** Settings → Debug only → "Jump total to just under a whole hour" → Start session. About 20 seconds later the sun bounces and a ring of sparkles shimmers.
- **Milestone notification:** same jump, but choose a total just under a milestone first (for example edit estimates in Settings → Your estimates so the total is near 100, 500, 1,000…), allow notifications, start a session and lock the phone.
- **Reduce Motion:** Settings app → Accessibility → Motion → Reduce Motion, then save a session.
- **Largest text:** Settings app → Accessibility → Display & Text Size → Larger Text.
