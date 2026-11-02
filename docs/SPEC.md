# Long Game — Product & Implementation Spec

Oct 25, 2026 · Natalia Terlecka
Living version: https://claude.ai/artifact/CKTw2qGoqQbPj1EVkxpftC

## Overview

Long Game is an iPhone app that tracks the hours a person puts into one craft on the way to 10,000 hours of mastery. It estimates past practice at onboarding, then grows that total with timed and retrospective sessions, and shows progress as a sunrise.

**Principles**

- **One craft only.** The app never holds two active crafts; adding one means replacing the current one.
- **Quality hours.** Copy always says to count focused practice only.
- **Calm and simple.** Plain warm-white screens, white cards, navy text; the smiling sun is the only decoration.
- **Game voice.** Long Game is "the longest game on the App Store — about 10,000 hours long, and played in real life." Copy uses light game language: your craft is your game, past hours are your starting score, practising is playing, the forecast date is the finish line, a full hour of rays is a golden hour bonus. Keep it warm and light, never cheesy: no lives, coins or leaderboards in the product.
- **Free.** No price, no ads, no subscription; every feature, including iCloud sync, is included. The only purchase is an optional tip jar, and tips unlock nothing. The app is local-first: it works offline and sync is optional.

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
| Session | id, craftId, start, end, durationSec, source (timer / manual / catchUp), note?, createdAt, editedAt? | Manual sessions store start = chosen day at 12:00 local, end = start + duration. |
| Settings | weekStart (Mon/Sun, default from locale), reminderTime?, reminderDays, syncEnabled, milestonesSeen[], lastTipAt?, tipCount, lastTipOfferAt?, weeklyTargetHours, targetSetAt, targetEndsAt, lastHomeTab | Single row. |
| TargetPeriod | hoursPerWeek, start, end | One row per year of pace (history of weekly targets). |

**Derived values**

- **Baseline hours** = sum over full past years of hoursPerWeek × 52, plus the onboarding year's hoursPerWeek × weeks elapsed up to the onboarding date. Frozen at onboarding unless the user edits estimates.
- **Logged hours** = sum of Session.durationSec ÷ 3600 for sessions after the onboarding date.
- **Total** = baseline + logged. **Progress** = total ÷ 10,000, capped at 100% (the app keeps counting past it).
- **This week** = logged hours since the start of the current week (Settings.weekStart).
- **Pace** = average weekly logged hours over the last 12 weeks; during the first 12 weeks, blend with the latest YearEstimate (weight = weeks of data ÷ 12).

All sessions belong to the active craft; the timer and add-hours flows never ask which craft.

## Screens

Phone screens: Welcome, three intro pages and four setup steps (the last is Your pace for the year); Home with two tabs (This week, The long game), History (Calendar, Growth), Timer and Add past hours; three sheets (One craft, Welcome back, Meet your future self); the catch-up steps; and the tip jar with its thank-you sheet. Plus the Live Activity, widgets and the Apple Watch app. The user always returns to Home.

### 0 · Welcome (`design/Welcome.dc.html`)

- Shown on first launch only, or after Replace my craft.
- **Get started** opens the intro pages (0a–0c). **I already have an account** runs Sign in with Apple and restores from iCloud; if nothing is found, it says so and continues to onboarding.

### 0a–0c · How the game works (`design/Intro1.dc.html`, `Intro2.dc.html`, `Intro3.dc.html`)

Three swipeable pages between Welcome and "What's your game?", to explain the game and motivate people of any age. Each page: back chevron, **Skip** (goes to step 1), an illustration with the sun and the same animated opaque sea as Home (the sea always covers the lower part of the sun), a title, a short paragraph, page dots and one button.

| Page | Illustration | Title | Text | Button |
| --- | --- | --- | --- | --- |
| 0a | Sun high above the sea, a dashed gold line above it labelled "Finish line · 10,000 hours" | One game, 10,000 hours | Around 10,000 hours of focused practice is where people tend to reach mastery in their craft: musicians, makers, surgeons, writers. That's your finish line. It's the longest game on the App Store, and it's played in real life. | Next |
| 0b | Sun just rising out of the sea, chip "Your starting score · 3,208 h" | You don't start at level one | Tell us roughly how much you've practised so far. Those hours become your starting score, whether you began last year or decades ago. It's never too late to play. | Next |
| 0c | Sun with 8 of 12 rays lit, navy chip "+1 h today" | Play it every day | Start the sun timer when you practise, or add hours afterwards. Every hour lifts your sun a little higher, and Long Game shows you when you'll cross the finish line. | Choose your game |

Shown only during first onboarding (not after Switch to a new game, which goes straight to step 1 after Welcome).

### 1 · Your craft (`design/Main.dc.html`)

- Search field filters the suggestion list as you type; any typed text is accepted as a custom craft (2–40 characters).
- Suggestions in five groups: Music; Visual arts & making; Performing arts; Words & mind; Professions (full lists in the design file). Tapping one fills the field and selects it; only one can be selected.
- **Continue** is disabled until a craft name exists.

### 2 · When did you start? (`design/StartYear.dc.html`)

- Year stepper, default = current year − 3, range 1940 to current year. Shows "N years ago".
- Choosing the current year still goes to step 3, which then shows a single slider for this year (default 5 h/week). The user can set it to 0 if they are starting from scratch. Baseline comes from this year's estimate only.

### 3 · Hours per week, each year (`design/YearlyHours.dc.html`)

- One slider row per year from start year to now, 0–40 h/week, step 1, default 5.
- Running "Estimated so far" total updates live using the baseline formula.
- **Continue** opens step 3b (Your pace for the year).

### 3b · Your pace for the year (`design/WeeklyTarget.dc.html`)

A weekly target for the next 12 months, counted from the day it's set (not the calendar year). The idea: a long walk is made one day's stretch at a time, so for a year the 10,000 hours step back and each week's target becomes the only distance to cover.

- Last onboarding step (step dots now show 4 steps). Also opened from the target row on the **This week** tab, to change it at any time.
- Title "Your pace for the year". Text: "A thousand-mile walk is made one day's stretch at a time. Set the 10,000 hours aside for a moment and choose how many hours a week you'll play for the next 12 months. Each week, that's the only distance to cover."
- Big number with a slider, 1–40 h a week, step 0.5 (shown without decimals when whole). Default = current pace rounded (or the latest YearEstimate during onboarding). Under the slider: "Your recent pace: N".
- Card: **Until** (set date + 12 months), **About** (target ÷ 7 as "1 h 43 m a day"), **In a year** ("+624 h · finish ~2036", using the target as the forecast rate for the next 12 months).
- Button **Start playing** (onboarding) saves the craft, estimates and target and opens Home on the This week tab. When editing, the button reads **Save** and the 12 months restart from today.
- Data: `Settings.weeklyTargetHours`, `targetSetAt`, `targetEndsAt` (= set date + 12 months). Earlier targets are kept in a small `TargetPeriod` list (hours, start, end) so past weeks are judged against the target that applied then.
- When the 12 months end: from 14 days before, the This week tab's target row says "Your year of pace ends on 2 Nov. Choose the next one." On the first open after the end date, the screen opens as a sheet ("A new year of pace") with the old value pre-filled. Until a new one is set, the old target carries on.
- Effect on the forecast: for the 12 months of the target, the mid scenario uses the target instead of the current pace when the user is within 25% of it (so an unrealistic target doesn't distort the finish line); otherwise the normal pace. The low/high band is unchanged.

### 4 · Home (`design/HomeWeek.dc.html`, `design/Home.dc.html`)

No cards on Home: everything sits directly on the warm-white background. A segmented control under the header switches between two tabs: **This week** (4a) and **The long game** (4b). The app opens on the tab used last; after onboarding, on This week.

- Header: craft name; History (calendar icon) and + buttons. Then the segmented control.

**The sun as a gauge (both tabs)**

- The hero shows the sun rising out of the sea with a **vertical scale** on the left: a thin line with ticks and labels, and a navy pill on the line at the sun's height showing the current value, joined to the sun by a dashed gold line.
- The sun's centre height maps linearly to the value: at 0 the sun sits on the horizon (centre just above the waterline, lower half hidden by the sea); at 100% its centre reaches the top tick. Above 100% it stays at the top and opens its eyes (celebrate face, no peeking).
- **This week:** scale 0 → weekly target, ticks at 0, half and the target ("0 h · 6 h · 12 h"). Value = hours logged this week (Settings.weekStart). The pill shows e.g. "6.5 h".
- **The long game:** scale 0 → 10,000 h, ticks at 0, 2.5k, 5k, 7.5k, 10k. Value = total hours. The pill shows e.g. "3,294 h".
- When switching tabs, the sun glides to its new height (0.6 s ease-in-out) and the scale labels cross-fade.

**4a · This week**

- Big number: hours this week with one decimal ("6.5 h") and "of 12 h this week · 54%".
- A row of 7 small day bars between hairlines (Mon–Sun, or Sun–Sat), coloured like the calendar levels; rest days in the light blue, future days in light grey; today's letter in bold.
- Target row: "5.5 h to go · 3 days left" (or "Target reached · +1.5 h" in gold once passed) and underneath "Your pace for the year: 12 h a week, until 2 Nov 2027", with a chevron. Opens 3b.

**4b · The long game**

- Big number: the total (rounded down) and "of 10,000 hours · N%".
- Stats row between hairlines: Pace (h/wk), **By Nov 2027** ("+624 h", what the weekly target adds by the end of the 12 months), Finish line.
- **Meet your future self** row (opens sheet 13).

**Shared hero details**
- The smiling sun rising out of the sea, full width, with a soft warm glow behind it. The sea is an opaque shape whose top edge is the navy wave line, filled with an opaque colour (#D3DEF4) that fades into the background colour over its bottom 34 pt, so the lower part of the sun is fully hidden behind the water. Inside it: a pale blue second wave line and small gold glints. No glow or transparency in the water, so nothing of the sun shows below the waterline. The sun's height follows the gauge rules above.
- The hero is gently animated (all of it off with Reduce Motion):

| Element | Motion | Timing |
| --- | --- | --- |
| Navy wave + sea fill | Drift right together by one wavelength, seamless loop | 3.2 s, linear |
| Pale wave | Drifts left by one wavelength | 5 s, linear |
| Water glints | Three short gold dashes under the sun fade in and stretch, staggered | 2.6 s each, offsets 0 / 0.9 / 1.7 s |
| Sun | Breathes: up 3 pt, scale 103% | 4 s, ease-in-out |
| Rays | Turn slowly | One turn per 90 s |
| Glow | Pulses with the breath | 4 s |
| Eyes | Every 7 s the sun opens both eyes for a short peek, then closes them | Open for about 0.35 s |

- **Water must cover the sun (build rule).** Layer order, back to front: glow → sun → sea fill → pale wave → navy wave line → glints. The sea fill is one closed `Shape` whose top edge is exactly the navy wave path (same phase, moved by the same offset), filled with a fully opaque colour. Also clip the sun view to the area above the wave path (e.g. `.mask` with the inverted sea shape), so nothing of the sun can show between crests at any animation phase, scale or Dynamic Type size. The fade at the bottom of the sea goes on top of the sea, never as transparency in the sea itself.
- Stop the animation when Home is not visible, and keep it cheap (one TimelineView or a few repeating SwiftUI animations).
- Recent sessions are no longer on Home; they live in History (the day detail) and on the This week day bars (tap a bar to open that day).
- Bottom: one primary button **Start session**, with **Add past hours** as a text button under it. If a session is running, Start session becomes "Back to session · mm:ss" while the timer is running, or "Resume · mm:ss" if it is paused.

### 5 · History — Calendar (`design/Calendar.dc.html`)

- Segmented control Calendar | Growth.
- Grid of the last 53 weeks, one square per day, most recent week on the right, scrolled to the end; swipe to go back.
- Colours by daily logged hours: 0 = blue (rest); < 1 h, 1–2 h, 2–3 h, 3 h+ = yellow → deep orange. Days before onboarding use the same blue.
- Tapping a day shows its total and sessions in the card below; sessions can be edited or deleted there.
- Stats: **Rhythm**, **Steady for**, **Active days** in the window. There are no streaks anywhere in the app: nothing ever "breaks".
  - **Rhythm** = the user's typical practice days per week: the median number of days with any logged time per calendar week (Monday start) over the last 8 complete weeks plus the current week. Shown as "N days/wk".
  - **Steady for** = how many consecutive weeks, counting back from the current week, had at least (Rhythm − 1) practice days. Shown as "N weeks" ("1 week"). If Rhythm is 0, show "–".

### 6 · History — Growth (`design/Growth.dc.html`)

- Chart of cumulative hours over time: solid navy line for the past, dashed orange forecast to 10,000 h, soft orange band for the likely range, a small sun at the forecast finish point. The dashed 10,000 h line is labelled "Finish line · 10,000 h" at its left end. No legend.
- Headline: forecast month + year; "Likely between YYYY and YYYY".
- **What if I practise more?** slider, 0–10 extra h/week; the forecast, band and text update live ("About 1.4 years sooner, around May 2035"). Not saved.

### 7 · Add past hours (`design/LogPast.dc.html`)

- Fields: Day (date picker, today back to start of the craft, no future), Hours (0–12), Minutes (0, 5 … 55), Note (optional, 280 characters).
- Big preview "H:MM" updates live. Button label "Add N hours". Disabled at 0:00.
- Validation: a day's total (all sessions) cannot exceed 24 h; show an inline message if it would.

### 8 · One craft at a time — sheet (`design/OneCraft.dc.html`)

- Opened from + on Home. Explains the one-craft rule with the smiling sun.
- **Keep playing** closes the sheet.
- **Switch to a new game** asks for confirmation ("Your N hours of Piano will be archived. This can't be undone."), archives the current craft and shows Welcome again, then the three setup steps. Archived crafts are listed read-only in Settings.

### 9 · Welcome back — catch-up after a break (`design/CatchUpAsk.dc.html`, `CatchUpWeeks.dc.html`, `CatchUpAverage.dc.html`)

When the app opens after a gap of 7 days or more with no session, it asks once whether the user practised, then helps add those hours as estimates spread across the calendar.

**When it appears**

- On app launch or return to foreground, after onboarding, when no timer is running.
- Gap = the day after the last day with any session (or the onboarding date, if there are none) up to yesterday. Shown only when the gap is 7 days or more.
- At most once every 7 days: store `lastCatchUpPromptAt` in Settings. Any outcome counts as asked — adding hours, "No, I took a break", or dismissing the sheet.

**Screen 10 · Welcome back (sheet)**

- Open-eyed happy sun, "Welcome back!", and "Your last session was on <weekday, date> — that's N weeks ago. Did you practise since then?" (N = whole weeks in the gap).
- **Yes, let me add it** opens screen 11 or 12. **No, I took a break** closes the sheet; the days stay as rest days.

**Screen 11 · Under 4 weeks (gap of 7–27 days): a slider per week**

- Split the gap into 7-day blocks counting back from yesterday; leftover days (fewer than 7) join the oldest block. Example: a 22-day gap = 3–10 Oct (8 days), 11–17 Oct, 18–24 Oct.
- One row per block: date range, slider 0–40 h (step 1, default = current pace rounded), and "N days · about H h MM m a day".
- Running total "Adding N h" and the button "Add N hours" (disabled at 0).

**Screen 12 · 4 weeks or more (gap of 28+ days): one average**

- "N weeks have passed. Since <date>. On average, how many hours a week did you practise?"
- One large slider 0–40 h/week (default = current pace rounded), with Period (dates · days), Per day in calendar, and Adding (= average × gap days ÷ 7).

**How the hours are stored**

- Each block's hours (or the average) are divided evenly across its days: one Session per day with source `catchUp`, start = that day at 12:00, duration = hours per day, rounded to the minute (put any rounding remainder on the last day so the total matches exactly).
- Catch-up days use the normal calendar colours; the day detail labels them "Added after a break" and they can be edited or deleted like any session.
- Catch-up sessions count towards the total, pace, forecast and Rhythm like any other session.
- Adding hours updates Home with the count-up animation and a happy sun.

### 13 · Meet your future self — sheet (`design/FutureSelf.dc.html`)

- Opened from the Home row. Also shown once, automatically, the first time Home appears after onboarding.
- Tall sheet. Top: the sun fully risen above the animated sea on a warm gradient; on open the sun rises into place (1.6 s ease-out).
- Title "Meet your future self". Text:
  - "Long Game is a projection of you into the future. Every hour you add brings that person a little closer."
  - "Dreaming of turning your passion into a career? 10,000 hours is where that starts to become realistic, whenever you begin. In a well-known study of musicians, what set the professionals apart wasn’t talent but the hours they had put in. And you’re not starting from zero: every hour you’ve already practised counts."
- A progress track from Today (current total) to the forecast finish date (mid scenario, "~Mon YYYY · 10,000 h"), with the sun at the end.
- Small note: "Hours aren't a guarantee, but they're the part you control."
- One button: **Keep playing** closes the sheet.

### 14 · Support Long Game — tip jar (`design/TipJar.dc.html`)

An optional way to support the app. Tips never unlock features, remove limits or change the experience.

**Where it lives**

- **Settings:** the first row of Settings is "Support Long Game" with the small sun icon. It pushes this screen. After a tip, the row's subtitle becomes "Thank you for your support".
- **One gentle offer:** after a milestone celebration on Home (100, 500, 1,000 h …), the celebration shows a text button "Support Long Game" under its main button. It appears at most once every 90 days, only after at least 14 days of use, and not within 12 months of a tip. It is never shown during or right after a timer session, and never as a pop-up of its own.

**Screen**

- Back to Settings. Breathing happy sun. Title "Keep the sun shining".
- Text: "Long Game is free, with no ads and no subscription, and it will stay that way. If it helps you play, you can leave a tip to support it. Tips don't unlock anything: every feature is free for everyone."
- A flat white card with four rows. Each row has an icon (the sun with more rays for bigger tips), a name, a short line and a price button:

| Product ID | Name | Line | Price (EUR reference) | Icon |
| --- | --- | --- | --- | --- |
| com.wehavesun.LongGame.tip.ray | A ray of sunshine | A small thank-you | €0.99 | Sun with 1 ray |
| com.wehavesun.LongGame.tip.morning | A sunny morning | Like buying a coffee | €2.99 | Sun with 4 rays |
| com.wehavesun.LongGame.tip.goldenhour | A golden hour | A big thank-you | €4.99 | Sun with 8 rays |
| com.wehavesun.LongGame.tip.sunrise | A whole sunrise | For the biggest fans | €9.99 | Full sun with a face |

- Footnote: "One-time payments through the App Store. Prices are shown in your currency."
- Prices always come from StoreKit (`Product.displayPrice`), never hard-coded. While products load, show the rows with a small spinner in place of the price. If the store can't be reached, show "Tips aren't available right now" instead of the card.
- Tapping a price starts the purchase. The button shows a spinner and the other buttons are disabled until it finishes. If the purchase is cancelled, nothing happens. If it's pending (Ask to Buy), show "Waiting for approval" under the card.

**15 · Thank you — sheet (`design/TipThanks.dc.html`)**

- Shown after a verified tip. The sun hops with open eyes and a big smile while little golden and pink dots burst around it (1.2 s hop, 2.4 s burst; still with Reduce Motion). Success haptic.
- "Thank you!" and "You just made the sun shine a little brighter. Your tip helps keep Long Game free for everyone." Button **Back to my game** closes the sheet and returns to Settings.

**Build notes**

- StoreKit 2, four **consumable** in-app purchases (Apple requires in-app purchase for tips inside the app). Load with `Product.products(for:)`, buy with `product.purchase()`, verify the transaction, then call `finish()`. Listen to `Transaction.updates` from app launch, so purchases that finish later (Ask to Buy, interrupted payments) still get thanked and finished.
- Store only `lastTipAt` and `tipCount` in Settings (local and synced). Never show amounts anywhere else.
- Include a StoreKit configuration file (`LongGame.storekit`) with the four products, so tips can be tested in the Simulator without App Store Connect.
- No analytics or third-party SDKs.

## Timer (`design/Timer.dc.html`)

The timer is timestamp-based, survives the app being closed, and turns each session into a small sunrise where the sun grows a ray every 5 minutes.

### Behaviour

- **States:** Idle → Running ⇄ Paused → Finishing → Saved, or Discarded. Only one session can exist at a time.
- **Storage:** save startedAt, pausedAt?, and accumulated pause time. Elapsed = now − startedAt − paused time. Never count in memory alone.
- **Background:** start a Live Activity (Lock Screen + Dynamic Island, design in `design/LiveActivity.dc.html`). Pause/Resume and Finish work from it with App Intents, without opening the app.

### Live Activity (`design/LiveActivity.dc.html`)

| Presentation | Content |
| --- | --- |
| Lock Screen, running | Navy card (#16244A at 92%). Left: focus-face sun, 56 pt, with this hour's lit rays (unlit rays at 22% opacity). Middle: "Piano" (13 pt, 70% white), session clock counting up (34 pt light, tabular), then "3,294.7 h · next ray in 2:42" (12 pt). Right: Pause (white 16% circle) and Finish (white circle, navy check), both 44 pt. Under it, a row of 12 thin segments, gold for lit rays. |
| Lock Screen, paused | Sleepy-face sun with dimmed rays, title "Piano · Paused", clock at 60% white and frozen, "3,294.7 h · paused". Buttons: Resume (gold #FFE08A circle, navy play) and Finish. |
| Dynamic Island, compact | Leading: small sun with lit rays (no face). Trailing: session clock in gold #FFE08A. |
| Dynamic Island, minimal | Just the small sun with lit rays. |
| Dynamic Island, expanded | Leading: focus sun, 60 pt. Centre: "Piano · this session" and the clock (38 pt light). Trailing: Pause and Finish. Bottom: "3,294.7 of 10,000 h" in gold, "Next ray in 2:42" on the right. |

- The clock uses `Text(timerInterval:)` / `.timer` style so it ticks without updates. Push an update only when a ray lights (every 5 min), on pause/resume, and on finish.
- Overall total shown with one decimal is the value at the last update plus the running time (computed in the view from the start date).
- Tapping the card or the island opens the Timer. Finish from the Live Activity saves the session with its real duration and ends the activity; the finish sheet's note can be added later from the session's day.
- Ends automatically 12 h after start (matching the auto-pause rule) and is removed when the session is saved or discarded.
- Reduce Motion: no animation in the activity; it already has none beyond the ticking clock.
- **Minimise** (chevron) returns to Home; Home shows "Back to session · mm:ss" (or "Resume · mm:ss" if paused).
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
| Each whole hour of the overall total | When the overall total (big gold number) crosses a whole hour (e.g. 3,294.9 → 3,295.0), the sun does a small happy bounce (scale 100 → 114 → 96 → 104 → 100%) and a ring of gold sparkles around it shimmers once. Light haptic. This is separate from the session's golden hour and celebrates the small wins. | 0.6 s spring; shimmer 0.8 s |
| Every 5 min | One more of the 12 rays lights, clockwise from the top; the next ray to light glows softly. Light haptic. | Ray grows 0 → full length, 600 ms spring |
| Every ~9 s | The focusing sun peeks one eye open, then closes it again (a wink checking on you). | 0.5 s |
| Over each hour | The sky slowly warms from navy to violet to rose, like dawn coming. | Tied to minutes in the hour |
| Golden hour (each full hour) | All 12 rays lit: the sun hops, opens both eyes with a big smile, rays burst outward and spin 30°, a ring of light pulses out, a gold bead drops into an hour row under the clock. Rays then reset for the next hour. Success haptic. | 1.2 s |
| Pause | Sun sinks 24 pt, rays dim to 40%, face turns sleepy (droopy eyes, small "z"), breathing slows to 8 s, sky desaturates. | 500 ms ease-out |
| Resume | Sun springs back up, rays brighten. | Spring, 400 ms |
| Finish → Save | Sun jumps with a big smile; mini suns and petals burst around it; Home's total counts up from old to new value. | Burst 1.2 s; count-up 1.2 s |

Layout under the sun, top to bottom: the overall total in large gold numbers with one decimal ("3,294.7") and "of 10,000 hours · N%", counting up live as the session runs; a short divider; "This session" with the session clock; then the caption "Next ray in m:ss".

**Reduced Motion:** no breathing, motes, spin, burst or hour bounce (the sparkle ring fades instead); rays light with a fade; the sky stays fixed. VoiceOver reads "N of 12 rays lit, M minutes into this hour" once per ray.

Build notes: drive everything from elapsed time in a TimelineView (do not use timers for state). The sun is one SwiftUI view with face states: happy, focus, wink, sleepy, celebrate. The design's Timer screen shows the running state animated (CSS keyframes there are a reference for timings).

## Forecast algorithm

The mastery date comes from simulating three pace scenarios month by month from today until the total reaches 10,000 h (stop at 30 years out).

**Inputs**

- *r* = forecast pace, h/week: the lifetime average (total hours ÷ weeks since 1 January of the first estimate year), blended with the recent 12-week logged pace. Recent logging gets weight 0.5 × (weeks of data ÷ 12), so up to half. This is separate from the Home "Pace" stat.
- *s* = yearly trend: slope of a least-squares line through the weekly average of each year (YearEstimates for past years, logged data for the current year), in h/week per year. Clamp to [−2, +2]. The forecast only uses a rising trend (negative is treated as 0), and the Growth card still shows the real value.
- *e* = extra hours from the What-if slider (0 when not used).

**Scenarios** (weekly rate at *t* years from now)

| Scenario | Weekly rate | Cap | Used for |
| --- | --- | --- | --- |
| Mid | r + e + 0.5 × s × t | 1.5 × r + e | Headline date, Home "Finish line", dashed line |
| High | r + e + s × t | 2 × r + e | Early edge of the band |
| Low | 0.75 × r + e | — | Late edge of the band |

Rates never go below 0. Each month adds rate × 52 ÷ 12 hours; interpolate within the crossing month for the date.

**Display rules**

- Headline = Mid date as "Month YYYY"; band label = High year to Low year.
- If a scenario does not reach 10,000 h within 30 years, show "after YYYY". If even the High scenario misses, the line under the headline reads "Not within 30 years at your average pace"; the dashed line still rises at the forecast pace.
- Fewer than 2 weeks of logged data: show "Forecast improves as you log more" under the headline.
- What-if text = difference between the Mid date with and without *e*, in months (under 12) or years to one decimal.
- Recompute when a session is saved, edited or deleted, and when estimates change.

## Accounts, sync and notifications

No account is needed to use the app; signing in only adds iCloud backup and multi-device sync.

**Accounts and sync**

- Sign in with Apple from Welcome ("I already have an account") or Settings.
- CloudKit private database mirrors all entities. Conflicts: last edit wins per session; sessions are never merged.
- A running timer is device-local; the saved session syncs.
- Settings opens from the gear in History. Its first row is "Support Long Game" (the tip jar, screen 14). It also offers Export (CSV of sessions) and Delete all data.

**Notifications** (all off by default; asked after the first saved session)

| Type | Trigger | Example copy |
| --- | --- | --- |
| Daily reminder | User-chosen time and days | "Time for a little piano? The sun is waiting." |
| Rhythm nudge | 7 pm on a weekday the user usually practises (practised on it in at least 3 of the last 4 weeks) with no session yet. At most twice a week. | "Tuesdays usually get a little piano. The sun is up whenever you are." |
| Long session | 4 h running | "Still practising?" |
| Milestone | Total crosses a milestone | "1,000 hours of piano. Sunrise is coming." |

**Milestones:** 100, 500, 1,000, 2,500, 5,000, 7,500 and 10,000 h. Each shows a one-time celebration on Home (the sun's celebrate state with a short burst). At 10,000 h the sun fully rises: a full-screen moment, and the app keeps counting.

## Widgets (`design/Widgets.dc.html`)

WidgetKit, reading the same data through a shared App Group. No animation (not allowed in widgets); the sun is drawn at its current height with the opaque sea in front.

| Widget | Content |
| --- | --- |
| Small, This week (default) | Sun rising over the sea at this week's height (0 → target). "6.5 h" and "of 12 h this week". At the target the sun reaches the top and opens its eyes. |
| Small, The long game | Same scene at the long-game height (0 → 10,000). "3,294 h" and "of 10,000 · 33%". Chosen in Edit Widget (App Intent configuration: This week / The long game). |
| Medium | Left: the this-week sun scene. Right: craft name and "Today 1 h 30 m"; a gold bar "This week 6.5 / 12 h"; a navy bar "The long game 3,294 / 10,000 h". |
| Lock Screen, circular | A ring that fills with this week's hours against the target, the sun icon inside. |
| Lock Screen, rectangular | "☀ 6.5 of 12 h this week", a bar, and "3,294 h · 33% of the long game". |
| Lock Screen, inline | "☀ 6.5 of 12 h". |

- Tapping opens Home on the matching tab (deep link).
- Timeline: reload when a session is saved, edited or deleted, at midnight, and at the start of each week. While a timer runs, widgets show the saved total; the Live Activity shows the live time.

## Apple Watch app (`design/Watch.dc.html`)

A small companion app, dark and simple, same sun.

- **Two swipeable pages:** This week and The long game. Each has the sun rising over a dark sea with a small scale line and a gold tick at the sun's height, the big number and a short line ("of 12 h · 3 days left", "33% · finish ~2036"). The This week page has a gold **Start** button.
- **Timer:** focus sun with this hour's lit rays, the session clock, "3,294.7 h · next ray 2:42", **Pause** and **Finish**. A light tap on the wrist (haptic) when a ray lights. Pausing shows the sleepy sun and Resume.
- **Finished:** happy sun, "+42 m", "7.2 of 12 h this week", **Done**.
- **Complications:** circular (ring fills with this week's hours, sun inside), rectangular (sun, "6.5 / 12 h this week", bar), corner/inline ("6.5h").
- **Sync:** one session at a time across devices. A session started on the watch shows on the phone (and its Live Activity) and vice versa, using WatchConnectivity for the live session and the shared CloudKit store for saved data. If the phone is unreachable, the watch keeps the session and sends it when it can.
- No onboarding on the watch: if the phone app isn't set up, the watch says "Set up Long Game on your iPhone first."

## iPhone Duo (foldable) (`design/Duo.dc.html`)

iPhone Duo (iOS 27) has a 5.4-inch outer display (portrait, shorter than other iPhones) and a 7.6-inch inner display that is wider than tall when open, with the same aspect ratio. iOS 27 adds Split View (two apps side by side, resizable), multiple windows of one app, a vertical Dynamic Island on the side, and navigation that moves to the side when open. Sizes below are approximate; Apple hasn't published point sizes yet.

**Layout rule:** never check the device model. Choose the layout from the window's size (size classes plus the actual width and height), so the same code works closed, open, in Split View at any width, and on future devices.

| Window | Layout |
| --- | --- |
| Compact width (iPhone, Duo closed ≈ 405 × 567 pt, Split View) | The normal phone layout. When the height is under 700 pt (Duo closed), use the short variant: hero 210 pt tall with a smaller sun (120 pt), number and "of 12 h · 54%" on one line, target line under it, day bars hidden, Start session and Add past hours side by side. |
| Regular width and wider than tall (Duo open ≈ 802 × 573 pt) | Two panes. Left (about half): header, tabs and a tall sun gauge (sun 150 pt, scale keeps clear of the side Dynamic Island). Right: big number, day bars, target row, a stats row (long-game total, pace, finish line), then the buttons. On the long-game tab the right pane shows the total, stats and Meet your future self. |
| Timer, wide | Sun (220 pt) on the left, clock (88 pt), total and next ray, Pause and Finish on the right. |
| Sheets (One craft, Welcome back, future self, tip jar) | Centred cards no wider than 520 pt when the window is wide. |
| History, wide | Calendar and Growth side by side instead of tabs. |

**Behaviour**

- Support all orientations and window sizes; adopt the iOS 27 resizable-window / Split View APIs, and keep `UIRequiresFullScreen` off.
- Folding, unfolding or resizing keeps all state (current tab, scroll position, a running timer, an open sheet) and animates to the new layout. Use scene-based state restoration.
- Respect safe areas on every edge, including the vertical Dynamic Island when open.
- One running session for the whole app: if the user opens a second window, both show the same timer.
- Widgets appear in the open Home Screen's Today View, so the small and medium widgets must look right at the larger widget sizes there.
- Test in the Xcode Simulator with the iPhone Duo device as soon as Xcode offers it (Apple says device support is coming); until then, test with resizable windows on iPad Simulator and the iPhone SE (short screen).

## Visual system

Simple, flat and calm: warm-white background, flat white cards only where content needs grouping, navy text, one smiling sun. One primary action per screen; secondary actions are text buttons. No decorative icons next to labels.

**Tokens**

| Token | Value | Use |
| --- | --- | --- |
| background | #FAF8F4 | All light screens |
| surface | #FFFFFF, radius 20–24, no shadow (flat) | Cards (sheets keep a soft top shadow) |
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
- Deleting the only sessions of a day turns it back to rest in the calendar and updates Rhythm and Steady for.
- Passing 10,000 h: progress shows 100%, the sun stays fully risen, totals keep growing.
- Start year far back (e.g. 1980): onboarding list scrolls; offer "Set all to" one value at the top.

**Out of scope for v1**

- Multiple active crafts, teams or social features.
- iPad layout, Android.
- Practice goals, tags or quality ratings per session.

**Open questions**

- [ ] Final check that the name Long Game is available on the App Store.
