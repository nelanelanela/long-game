# Long Game — Product & Implementation Spec

Oct 25, 2026 · Natalia Terlecka
Living version: https://claude.ai/artifact/CKTw2qGoqQbPj1EVkxpftC

## Overview

Long Game is an iPhone app that tracks the hours a person puts into one craft on the way to 10,000 hours of mastery. It estimates past practice at onboarding, then grows that total with timed and retrospective sessions, and shows progress as a sunrise.

**Principles**

- **One craft only.** The app never holds two active crafts; adding one means replacing the current one.
- **Quality hours.** Copy always says to count focused practice only.
- **Calm and simple.** Plain warm-white screens, white cards, navy text; the smiling sun is the only decoration.
- **Free.** No price, no ads, no subscription; every feature, including iCloud sync, is included. The app is local-first: it works offline and sync is optional.

**Platform and stack (recommended)**

| Area | Choice |
| --- | --- |
| Target | iPhone, iOS 17+ (Liquid Glass styling where the OS provides it) |
| UI | SwiftUI |
| Storage | SwiftData, on device |
| Sync | CloudKit private database, opt-in |
| Sign in | Sign in with Apple (only needed for sync and restore) |
| Timer surfaces | ActivityKit Live Activity + Dynamic Island |
| Charts | Swift Charts for the Growth view; calendar grid drawn in SwiftUI |
| Animation | SwiftUI animations + Canvas/TimelineView for the timer sun |

The design file is the Long Game canvas (see `design/`). Mock-ups use Inter; the build uses SF Pro.

## Data model

Four stored entities; every total on screen is derived from them, never stored.

| Entity | Fields | Notes |
| --- | --- | --- |
| Craft | id, name, category, startYear, createdAt, archivedAt? | Exactly one with archivedAt = nil. Archived crafts keep their data, read-only. |
| YearEstimate | craftId, year, hoursPerWeek (0–40, step 1) | One row per year from startYear to the onboarding year. Editable later in Settings. |
| Session | id, craftId, start, end, durationSec, source (timer / manual), note?, createdAt, editedAt? | Manual sessions store start = chosen day at 12:00 local, end = start + duration. |
| Settings | weekStart (Mon/Sun, default from locale), reminderTime?, reminderDays, syncEnabled, milestonesSeen[] | Single row. |

**Derived values**

- **Baseline hours** = sum over full past years of hoursPerWeek × 52, plus the onboarding year's hoursPerWeek × weeks elapsed up to the onboarding date. Frozen at onboarding unless the user edits estimates.
- **Logged hours** = sum of Session.durationSec ÷ 3600 for sessions after the onboarding date.
- **Total** = baseline + logged. **Progress** = total ÷ 10,000, capped at 100% (the app keeps counting past it).
- **This week** = logged hours since the start of the current week (Settings.weekStart).
- **Pace** = average weekly logged hours over the last 12 weeks; during the first 12 weeks, blend with the latest YearEstimate (weight = weeks of data ÷ 12).

All sessions belong to the active craft; the timer and add-hours flows never ask which craft.

## Screens

Ten screens: four onboarding, four in the main app, two sheets. The user always returns to Home.

### 0 · Welcome (`design/Welcome.dc.html`)

- Shown on first launch only, or after Replace my craft.
- **Get started** opens onboarding. **I already have an account** runs Sign in with Apple and restores from iCloud; if nothing is found, it says so and continues to onboarding.

### 1 · Your craft (`design/Main.dc.html`)

- Search field filters the suggestion list as you type; any typed text is accepted as a custom craft (2–40 characters).
- Suggestions in five groups: Music; Visual arts & making; Performing arts; Words & mind; Professions (full lists in the design file). Tapping one fills the field and selects it; only one can be selected.
- **Continue** is disabled until a craft name exists.

### 2 · When did you start? (`design/StartYear.dc.html`)

- Year stepper, default = current year − 3, range 1940 to current year. Shows "N years ago".
- Choosing the current year skips step 3 and sets baseline from this year's estimate only.

### 3 · Hours per week, each year (`design/YearlyHours.dc.html`)

- One slider row per year from start year to now, 0–40 h/week, step 1, default 5.
- Running "Estimated so far" total updates live using the baseline formula.
- **Start tracking** saves Craft + YearEstimates and opens Home.

### 4 · Home / Progress (`design/Home.dc.html`)

- Header: craft name; History (calendar icon) and + buttons.
- Sunrise card: the smiling sun over the sea; below it the total (rounded down to whole hours) and "of 10,000 hours · N%".
- Stats row: This week, Pace (h/wk), Mastery (forecast year from the mid scenario, see Forecast).
- Recent: last 5 sessions (relative day, duration); tap opens the edit sheet.
- Bottom: **Add past hours** and **Start session**. If a session is running, Start session becomes "Resume · mm:ss".

### 5 · History — Calendar (`design/Calendar.dc.html`)

- Segmented control Calendar | Growth.
- Grid of the last 53 weeks, one square per day, most recent week on the right, scrolled to the end; swipe to go back.
- Colours by daily logged hours: 0 = blue (rest); < 1 h, 1–2 h, 2–3 h, 3 h+ = yellow → deep orange. Days before onboarding use the same blue.
- Tapping a day shows its total and sessions in the card below; sessions can be edited or deleted there.
- Stats: **Streak** = consecutive days up to today (or yesterday, if today has nothing yet) with any logged time; **Longest** streak; **Active days** in the window.

### 6 · History — Growth (`design/Growth.dc.html`)

- Chart of cumulative hours over time: solid navy line for the past, dashed orange forecast to 10,000 h, soft orange band for the likely range, a small sun at the forecast mastery point.
- Headline: forecast month + year; "Likely between YYYY and YYYY".
- Weekly rate by year: bar per year (estimates for past years, logged data for the current year), with the yearly trend in h/wk.
- **What if I practise more?** slider, 0–10 extra h/week; the forecast, band and text update live ("About 1.4 years sooner, around May 2035"). Not saved.

### 7 · Add past hours (`design/LogPast.dc.html`)

- Fields: Day (date picker, today back to start of the craft, no future), Hours (0–12), Minutes (0, 5 … 55), Note (optional, 280 characters).
- Big preview "H:MM" updates live. Button label "Add N hours". Disabled at 0:00.
- Validation: a day's total (all sessions) cannot exceed 24 h; show an inline message if it would.

### 8 · One craft at a time — sheet (`design/OneCraft.dc.html`)

- Opened from + on Home. Explains the one-craft rule with the smiling sun.
- **Keep my focus** closes the sheet.
- **Replace my craft** asks for confirmation ("Your N hours of Piano will be archived. This can't be undone."), archives the current craft and opens step 1. Archived crafts are listed read-only in Settings.

## Timer (`design/Timer.dc.html`)

The timer is timestamp-based, survives the app being closed, and turns each session into a small sunrise where the sun grows a ray every 5 minutes.

### Behaviour

- **States:** Idle → Running ⇄ Paused → Finishing → Saved, or Discarded. Only one session can exist at a time.
- **Storage:** save startedAt, pausedAt?, and accumulated pause time. Elapsed = now − startedAt − paused time. Never count in memory alone.
- **Background:** start a Live Activity (lock screen + Dynamic Island) showing the craft, elapsed time and the sun with its lit rays; Pause/Resume and Finish work from it.
- **Minimise** (chevron) returns to Home; Home shows "Resume · mm:ss".
- **Finish** opens a sheet: duration (editable ± 5 min, cannot exceed real elapsed time), optional note, **Save** and **Discard**. Sessions under 1 minute offer Discard only.
- **Long sessions:** after 4 h running, send a gentle notification ("Still practising?"); at 12 h auto-pause.
- **Haptics:** light tick when a ray lights; success haptic on each golden hour and on save.

### Animation: the sun's hour

The sun keeps the user company and doubles as a clock you can read at a glance.

| Moment | What happens | Timing |
| --- | --- | --- |
| Running (always) | Sun breathes: rises 4 pt and scales to 104.5%, then settles. Doubles as a calm breathing cue. | 4 s loop, ease-in-out |
| Running (always) | Warm halo behind the sun pulses with the breath. Tiny golden motes drift up from the sun and fade. | Halo 4 s; a mote every 1–2 s, 5 s rise |
| Running (always) | Rays slowly turn. | One turn per 120 s |
| Every 5 min | One more of the 12 rays lights, clockwise from the top; the next ray to light glows softly. Light haptic. | Ray grows 0 → full length, 600 ms spring |
| Every ~9 s | The focusing sun peeks one eye open, then closes it again (a wink checking on you). | 0.5 s |
| Over each hour | The sky slowly warms from navy to violet to rose, like dawn coming. | Tied to minutes in the hour |
| Golden hour (each full hour) | All 12 rays lit: the sun hops, opens both eyes with a big smile, rays burst outward and spin 30°, a ring of light pulses out, a gold bead drops into an hour row under the clock. Rays then reset for the next hour. Success haptic. | 1.2 s |
| Pause | Sun sinks 24 pt, rays dim to 40%, face turns sleepy (droopy eyes, small "z"), breathing slows to 8 s, sky desaturates. | 500 ms ease-out |
| Resume | Sun springs back up, rays brighten. | Spring, 400 ms |
| Finish → Save | Sun jumps with a big smile; mini suns and petals burst around it; Home's total counts up from old to new value. | Burst 1.2 s; count-up 1.2 s |

Caption under the clock: "Next ray in m:ss · golden hour in mm:ss".

**Reduced Motion:** no breathing, motes, spin or burst; rays light with a fade; the sky stays fixed. VoiceOver reads "N of 12 rays lit, M minutes into this hour" once per ray.

Build notes: drive everything from elapsed time in a TimelineView (do not use timers for state). The sun is one SwiftUI view with face states: happy, focus, wink, sleepy, celebrate. The design's Timer screen shows the running state animated (CSS keyframes there are a reference for timings).

## Forecast algorithm

The mastery date comes from simulating three pace scenarios month by month from today until the total reaches 10,000 h (stop at 15 years out).

**Inputs**

- *r* = current pace, h/week (see Data model).
- *s* = yearly trend: slope of a least-squares line through the weekly average of each year (YearEstimates for past years, logged data for the current year), in h/week per year. Clamp to [−2, +2].
- *e* = extra hours from the What-if slider (0 when not used).

**Scenarios** (weekly rate at *t* years from now)

| Scenario | Weekly rate | Cap | Used for |
| --- | --- | --- | --- |
| Mid | r + e + 0.5 × s × t | 1.5 × r + e | Headline date, Home "Mastery", dashed line |
| High | r + e + s × t | 2 × r + e | Early edge of the band |
| Low | 0.75 × r + e | — | Late edge of the band |

Rates never go below 0. Each month adds rate × 52 ÷ 12 hours; interpolate within the crossing month for the date.

**Display rules**

- Headline = Mid date as "Month YYYY"; band label = High year to Low year.
- If a scenario does not reach 10,000 h within 15 years, show "after YYYY".
- Fewer than 2 weeks of logged data: show "Forecast improves as you log more" under the headline.
- What-if text = difference between the Mid date with and without *e*, in months (under 12) or years to one decimal.
- Recompute when a session is saved, edited or deleted, and when estimates change.

## Accounts, sync and notifications

No account is needed to use the app; signing in only adds iCloud backup and multi-device sync.

**Accounts and sync**

- Sign in with Apple from Welcome ("I already have an account") or Settings.
- CloudKit private database mirrors all entities. Conflicts: last edit wins per session; sessions are never merged.
- A running timer is device-local; the saved session syncs.
- Settings offers Export (CSV of sessions) and Delete all data.

**Notifications** (all off by default; asked after the first saved session)

| Type | Trigger | Example copy |
| --- | --- | --- |
| Daily reminder | User-chosen time and days | "Time for a little piano? The sun is waiting." |
| Streak at risk | 8 pm on a day with no session, streak ≥ 3 | "Keep your 6-day streak glowing." |
| Long session | 4 h running | "Still practising?" |
| Milestone | Total crosses a milestone | "1,000 hours of piano. Sunrise is coming." |

**Milestones:** 100, 500, 1,000, 2,500, 5,000, 7,500 and 10,000 h. Each shows a one-time celebration on Home (the sun's celebrate state with a short burst). At 10,000 h the sun fully rises: a full-screen moment, and the app keeps counting.

## Visual system

Simple and calm: warm-white background, white cards, navy text, one smiling sun.

**Tokens**

| Token | Value | Use |
| --- | --- | --- |
| background | #FAF8F4 | All light screens |
| surface | #FFFFFF, radius 20–24, shadow 0 1 2 / 4% + 0 6 20 / 5% navy | Cards, sheets |
| ink | #16244A | Text, primary buttons, timer background |
| ink-muted | #5E6782 | Secondary text |
| divider | #F0ECE5 | Lines inside cards |
| chip-border | #E4DFD6 | Unselected tags, inactive progress bars |
| sun | #FFC93C body, #FFB627 rays, #F7A1B5 cheeks | Mascot |
| rest | #D3DCF2 | Calendar rest days |
| practice scale | #FFE48C, #FFC53D, #FF9A3C, #EE6420 | Calendar levels, forecast |
| sunrise sky | #16244A → #2C3466 → #8C5A8E → #E98FA3 → #F7B46A | Welcome only |

**Type:** SF Pro. Titles 32 bold (−2% tracking), big numbers 52–88, body 15–17, labels 13. No letter-spaced capitals.

**Controls:** buttons 56 pt tall, radius 16 (primary navy, secondary white); tags 40 pt pills; minimum touch target 44 pt.

**Sun mascot states**

| State | Face | Where |
| --- | --- | --- |
| Happy | Closed smiling eyes, smile, pink cheeks | Welcome, onboarding corner, Home, sheets |
| Focus | Closed relaxed eyes, small smile | Timer running |
| Wink | One eye open | Timer, every ~9 s |
| Sleepy | Droopy eyes, small "z" | Timer paused, empty states |
| Celebrate | Open eyes, big smile, rays burst | Finish, golden hour, milestones |

Build the sun as one vector view (circle, 12 rays, face layers) so every state animates between the others; export the same drawing for the app icon. Exact geometry (200×200 viewBox): body circle r 56 at (100,100); 12 rays every 30° from r 66 to r 92 (long) / r 82 (short), alternating, stroke 9, round caps; cheeks r 7 at (72,113) and (128,113); happy eyes `M76 98 q8 -9 16 0` and `M108 98 q8 -9 16 0`; smile `M88 114 q12 11 24 0`; stroke 4.5 navy, round caps. See any design file for the SVG.

## Accessibility, edge cases and scope

**Accessibility**

- Dynamic Type up to XXXL; big numbers scale down before wrapping.
- VoiceOver labels on every icon button and chart (the Growth chart reads its headline and range; calendar days read "Thursday 22 October, 2 hours").
- Calendar levels also differ in lightness, not only hue; rest days are labelled.
- Reduce Motion honoured everywhere (see Timer).
- Text contrast at least 4.5:1 on all backgrounds.

**Edge cases**

- Time-zone or clock change during a timer: elapsed uses absolute timestamps, so it stays correct.
- Session crossing midnight: counted on the day it started.
- Editing YearEstimates later recalculates baseline, total, forecast and milestones (no repeat celebrations).
- Deleting the only sessions of a day turns it back to rest in the calendar and may break the streak.
- Passing 10,000 h: progress shows 100%, the sun stays fully risen, totals keep growing.
- Start year far back (e.g. 1980): onboarding list scrolls; offer "Set all to" one value at the top.

**Out of scope for v1**

- Multiple active crafts, teams or social features.
- Apple Watch app, iPad layout, Android.
- Home Screen widgets (planned for v1.1: progress sun + today's minutes).
- Practice goals, tags or quality ratings per session.

**Open questions**

- [ ] Final check that the name Long Game is available on the App Store.
