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
| Timer surfaces | ActivityKit Live Activity + Dynamic Island |
| Charts | Swift Charts for the Growth view; calendar grid drawn in SwiftUI |
| Animation | SwiftUI animations + Canvas/TimelineView for the timer sun |

The design file is the Long Game canvas (see `design/`). Mock-ups use Inter; the build uses SF Pro.

## Data model

Four stored entities; every total on screen is derived from them, never stored.

| Entity | Fields | Notes |
| --- | --- | --- |
| Craft | id, name, category, startYear, createdAt, archivedAt? | Exactly one with archivedAt = nil. Archived crafts keep their data, read-only. |
| YearEstimate | craftId, year, hoursPerWeek (0–168, step 1) | One row per year from startYear to the onboarding year. Editable later in Settings. |
| Session | id, craftId, start, end, durationSec, source (timer / manual / catchUp), note?, photo? (image data, external storage), createdAt, editedAt? | Manual sessions store start = chosen day at 12:00 local, end = start + duration. note and photo are optional (section 16). |
| Settings | weekStart (Mon/Sun, default from locale), reminderTime?, reminderDays, syncEnabled, milestonesSeen[], lastTipAt?, tipCount, lastTipOfferAt?, scrubHintSeen, weeklyTargetHours, targetSetAt, targetEndsAt, lastHomeTab (the tab Home opens on next: Today, except right after onboarding) | Single row. |
| TargetPeriod | hoursPerWeek, start, end | One row per year of pace (history of weekly targets). |

**Derived values**

- **Baseline hours** = sum over full past years of hoursPerWeek × 52, plus the onboarding year's hoursPerWeek × weeks elapsed up to the onboarding date. Frozen at onboarding unless the user edits estimates.
- **Logged hours** = sum of Session.durationSec ÷ 3600 for sessions after the onboarding date.
- **Total** = baseline + logged. **Progress** = total ÷ 10,000, capped at 100% (the app keeps counting past it).
- **This week** = logged hours since the start of the current week (Settings.weekStart).
- **Pace** = average weekly logged hours over the last 12 weeks; during the first 12 weeks, blend with the latest YearEstimate (weight = weeks of data ÷ 12).

All sessions belong to the active craft; the timer and add-hours flows never ask which craft.

## Screens

Phone screens: a launch screen with a short opening sunrise; Welcome (and Welcome back when iCloud already holds a game), three intro pages and six setup steps (Keep your game safe, then A gentle nudge; the last is left out when notification permission is already decided); Home with three tabs (Today, This week, The long game), History (Calendar, Growth), Your year, Timer, the Finish sheet and Add past hours; three sheets (One craft, Welcome back after a break, Meet your future self); the catch-up steps; and the tip jar with its thank-you sheet. Plus the Live Activity, widgets and the Apple Watch app. The user always returns to Home. Design files for the main flow are in `design/` with the same names as the canvas boards; the larger "details" boards explain each feature.

### 0 · Welcome (`design/Welcome.dc.html`)

- Shown on first launch only, or after Replace my craft.
- Copy: big title **Long Game**, one line "The longest game on the App Store. Played in real life." and **Get started**, which opens the intro pages (0a–0c). There is no sign-in button.
- **Welcome back** (`design/WelcomeBack.dc.html`): on first launch, if the user's iCloud already holds a Long Game (checked quietly in the background, at most 3 s), Welcome shows instead: "Welcome back", "We found your game in iCloud." and the craft with its total ("Piano · 3,294 hours"), with **Continue my game** (restores and opens Home) and **Start a new game** (normal onboarding; the iCloud game is archived, not deleted).

### 0a–0c · How the game works (`design/Intro1.dc.html`, `Intro2.dc.html`, `Intro3.dc.html`)

Three swipeable pages between Welcome and "What's your game?", to explain the game and motivate people of any age. Each page: back chevron, **Skip** (goes to step 1), an illustration with the sun and the same animated opaque sea as Home (the sea always covers the lower part of the sun), a title, one short line, page dots and one button.

| Page | Illustration | Title | Text | Button |
| --- | --- | --- | --- | --- |
| 0a | Sun high above the sea, a dashed gold line above it labelled "Finish line · 10,000 h" | One game, 10,000 hours | Roughly where mastery begins. That's your finish line. | Next |
| 0b | Sun just rising out of the sea, chip "Your starting score · 3,208 h" | You don't start at zero | The hours you've already practised are your starting score. | Next |
| 0c | Sun with its rays, navy chip "+1 h today" | Play every day | Start the timer when you practise. Every hour lifts your sun. | Choose your game |

Shown only during first onboarding (not after Switch to a new game, which goes straight to step 1 after Welcome).

### 1 · Your game (`design/Main.dc.html`)

- Title "What's your game?", no subtitle. A search field "Search or type your own", then the suggestions as tappable chips under small group labels.

- Search field filters the suggestion list as you type; any typed text is accepted as a custom craft (2–40 characters).
- Suggestion chips in five groups: Music; Visual arts & making; Performing arts; Words & mind; Professions (the list scrolls). Tapping one selects it (navy chip) and fills the field; only one can be selected.
- **Continue** is disabled until a craft name exists.

### 2 · When did you start? (`design/StartYear.dc.html`)

- Title "When did you start?", line "A rough guess is fine." A big stepper (56 pt − and + either side of the year, 64 pt), default = current year − 3, range 1940 to current year, "N years ago" under it.
- Choosing the current year still goes to step 3, which then shows a single stepper row for this year (default 5 h/week). The user can set it to 0 if they are starting from scratch. Baseline comes from this year's estimate only.

### 3 · Hours a week, each year (`design/YearlyHours.dc.html`)

- Title "Hours a week, each year", no subtitle.

- One stepper row per year from start year to now (year · − · "N h" · +), 0–168 h/week (no limit below the 168 hours in a week), step 1, default 5. The year being changed is highlighted (#FFF3D6 behind its value).
- After the user changes a year that has later years, a text button appears under the card: "Use N h for the years after YYYY"; it copies that value to every later year (one tap, undoable by changing them back).
- Under the card, "Your starting score" with the live total (baseline formula).
- **Continue** opens step 3b (Your weekly pace).

### 3b · Your weekly pace (`design/WeeklyTarget.dc.html`)

A weekly target for the next 12 months, counted from the day it's set (not the calendar year). The idea: a long walk is made one day's stretch at a time, so for a year the 10,000 hours step back and each week's target becomes the only distance to cover.

- Onboarding step 4 of 6 (step dots show 6 steps on steps 1–6; 5 when A gentle nudge is left out). Also opened from the target row on the **This week** tab, to change it at any time (then titled "Your pace for the year", button **Save**).
- Title "Your weekly pace". One line: "For the next 12 months, the only distance to cover."
- Big stepper: a 56 pt − button, the big number with "hours a week", a 56 pt + button; 1–168 h a week (no limit below the 168 hours in a week), step 0.5 (shown without decimals when whole). Default = current pace rounded (or the latest YearEstimate during onboarding). No quick-pick chips under it.
- One quiet line under the chips instead of a card: "About 1 h 43 m a day · until Nov 2027" (target ÷ 7, and the set date + 12 months). The "In a year" forecast moves to the Growth chart.
- **Continue** opens step 3c.

### 3c · Keep your game safe (`design/ICloud.dc.html`)

- Step 5 of 6. Illustration: the sun over the sea with a small white circle holding a blue iCloud symbol. Title "Keep your game safe".
- One card: iCloud icon, **Save to iCloud**, line "On all your Apple devices, and back if you get a new iPhone.", and a switch, **on** by default.
- Under the card, 13 pt muted: "Private to your Apple Account. Only you can see it. No sign-in needed."
- If the device has no iCloud account (`CKContainer.accountStatus` ≠ available), the switch is off and disabled and the line reads "Sign in to iCloud in the Settings app to keep a copy."
- **Continue** opens step 3d (A gentle nudge). When that step is left out (notifications already allowed or turned off, for example after "Switch to a new game"), this is the last step and the button reads **Start playing**: it saves everything (and the iCloud choice) and opens Home on The long game (once).
- The weekly pace (step 3b) is saved with everything else when onboarding finishes. When editing from Home, the button reads **Save** and the 12 months restart from today.
- Data: `Settings.weeklyTargetHours`, `targetSetAt`, `targetEndsAt` (= set date + 12 months). Earlier targets are kept in a small `TargetPeriod` list (hours, start, end) so past weeks are judged against the target that applied then.
- When the 12 months end: from 14 days before, the This week tab's target row says "Your year of pace ends on 2 Nov. Choose the next one." On the first open after the end date, the screen opens as a sheet ("A new year of pace") with the old value pre-filled. Until a new one is set, the old target carries on.
- Effect on the forecast: the finish-line forecast everywhere uses this chosen pace (see Forecast algorithm), so changing it moves the finish line straight away.

### 3d · A gentle nudge (`design/redesign/Notifications.dc.html`)

The one place the app asks for notifications, so nothing interrupts the first session.

- Step 6 of 6. Shown only while iOS has never asked (status "not determined"); otherwise step 3c finishes onboarding.
- Illustration: the day sky, the sun with the wink face, the land and sea, and a bell (amber) in a small white bubble beside the sun (decorative, hidden from VoiceOver).
- Title "A gentle nudge". Line: "Long Game can send you a few quiet notifications. Never ads, never streaks."
- A white card with two rows, each an icon on a peach tile, a 15 pt semibold title and a 13 pt muted line; VoiceOver reads each row as one element:
  - **Milestones** — "“1,000 hours of piano. Sunrise is coming.”" (with the user's craft)
  - **A long-session check** — "“Still practising?” after 4 hours, so a forgotten timer doesn’t count."
- Under the card, 13 pt muted: "Your session on the Lock Screen shows either way. Change your mind any time in Settings."
- **Allow notifications** (primary) only shows iOS's own prompt. It never turns on the daily reminder, which stays off until the person turns it on in Settings. Then onboarding finishes (everything saved, Home opens on The long game once).
- **Not now** (text button) finishes onboarding without asking iOS.
- Either way `notifications.asked` is set. "by We Have Sun" under the buttons.
- The milestone notification itself reads the same: "1,000 hours of piano. Sunrise is coming." (at 10,000: "10,000 hours of piano. The sun has fully risen."). The celebration on Home keeps its short line ("A thousand hours.").

### 4 · Home (`design/TodayStretch.dc.html`, `design/HomeWeek.dc.html`, `design/Home.dc.html`)

No cards on Home: everything sits directly on the warm-white background. A segmented control under the header switches between three tabs: **Today** (4c), **This week** (4a) and **The long game** (4b). Each tab shows one sun, one big number and one quiet line, so no screen carries too many numbers. Home opens on **Today** every time the app starts; only right after onboarding does it open on **The long game**, once, so the first thing you see is the whole game. Choosing another tab is not remembered for next time.

- Header: craft name; History (calendar icon) and Settings (gear) buttons. There is no + button. On a phone the header and the segmented control stay on top as a **transparent bar** while the page scrolls under it: no background, no material, no divider and (iOS 26) no scroll edge effect. The tab's sky runs up behind it to the top of the screen as one continuous sky: the day sky and its glow on Today and This week, the dawn sky on the empty day and The long game. Home draws no warm wash on a phone; below the hero the background is plain. The craft name has nothing behind it: navy on the day sky, white on the dawn sky (the empty day and The long game). iOS 26: History and Settings are glass circles in one glass container, and the tabs' glass track has a very light warm tint (the track colour at about 35%) on the day sky. iOS 17–25: plain icons, and the tabs' track is the track colour at 85% over a thin material. Once the page has scrolled past the hero, the craft name fades out over the next 24 pt (the controls stay) and comes back on the way up; with Reduce Transparency it never fades and the track is solid. iPad, the Duo open and Mac keep their own header.

**The sun as a gauge (This week and The long game)**

- The hero shows the sun rising out of the sea with a **vertical scale** on the left: a thin line with ticks and labels, and a navy pill on the line at the sun's height showing the current value, joined to the sun by a dashed gold line.
- The sun's centre height maps linearly to the value: at 0 the sun sits on the horizon (centre just above the waterline, lower half hidden by the sea); at 100% its centre reaches the top tick. Above 100% it stays at the top and opens its eyes (celebrate face, no peeking).
- **This week:** scale 0 → weekly target, ticks at 0, half and the target ("0 h · 6 h · 12 h"). Value = hours logged this week (Settings.weekStart). The pill shows e.g. "6.5 h".
- **The long game:** scale 0 → 10,000 h, ticks at 0, 2.5k, 5k, 7.5k, 10k. Value = total hours. The pill shows e.g. "3,294 h".
- When switching tabs, the sun glides to its new place (0.6 s ease-in-out) and the scale labels cross-fade. Between Today and the other tabs the sun glides from its spot on the arc to its spot on the scale.

**4a · This week**

- Big number: hours this week with one decimal ("6.5 h") and "of 12 h this week · 54%".
- A row of 7 small day bars between hairlines (Mon–Sun, or Sun–Sat), coloured like the calendar levels; rest days in the light blue, future days in light grey; today's letter in bold.
- Target row: "5.5 h to go · 3 days left" (or "Target reached · +1.5 h" in gold once passed) and underneath "Your pace for the year: 12 h a week, until 2 Nov 2027", with a chevron. Opens 3b.

**4c · Today: today's stretch**

Your weekly target, turned into today's distance. "A thousand-mile walk is made one day's stretch at a time": this tab shows just today's stretch.

- **The picture:** instead of a vertical scale, a wide dotted arc rises from the sea on the left and comes down on the right to a small pale-blue moon on the horizon. Reaching the moon is today's stretch done: one more step towards the future the user is playing for. The part of the arc the sun has travelled is a solid gold line. The sun (same sun, same animation, about 120 pt) sits on the arc at `done ÷ stretch` (0 = on the horizon on the left, 1 = at the moon). No ticks or labels: the arc is the scale. Same sea, same water rule as the other tabs (at 0 the sun's lower half is hidden by the sea). The words "rest", "resting place" and "goal" are not used for the stretch: the copy talks about reaching the moon.
- **Big number:** today's time ("1 h 05", or "40 m" under an hour). **Under it:** "of today's 1 h 45". **One quiet line** (14 pt, #8A93AB), in plain words (the dotted arc and the moon stay in the picture): "40 m to go". When covered: "Done for today" (exactly at the stretch, or less than a minute over), or "25 m extra today" once a minute or more over (the whole minutes beyond the stretch, written like "25 m" or "1 h 10").
- **Stretch covered** (done ≥ stretch): the sun sits at the moon with the wink face for a moment, then happy; the whole arc is gold. Number = today's time, under it "today's 1 h 45 · covered", line "Anything more is a bonus."
- **Today's sessions:** under the quiet line, a small header "Today's sessions" (13 pt semibold, #8A93AB) and one row per session that started today, oldest first, between hairlines: a 40 pt photo thumbnail (or a small clock icon on #F1EDE6 when there's no photo), the time range "07:40 – 08:20" (14 pt semibold) with the note under it (13 pt, one line, ellipsis; "No note" in light grey when empty), and the duration on the right ("40 m", 15 pt semibold). A running timer shows as the first row "Now · 12 m" with a small pulsing dot. Tapping a row opens that session to edit (same sheet as in History). No rows today: the section is hidden. If there are more rows than fit, the area under the hero scrolls; Start session and Add past hours stay fixed at the bottom.
- **No target yet** (shouldn't happen after onboarding): show the This week tab instead.
- **Never a penalty:** a missed stretch isn't shown or remembered anywhere. Tomorrow simply has its own stretch.
- VoiceOver: the picture is one element, e.g. "Today's stretch: 1 hour 5 minutes of 1 hour 45. 40 minutes to go."

**How the stretch is worked out** (all in `Logic/`, nothing stored):

- **Stretch for today** = weekly pace ÷ 7, rounded to the nearest 5 minutes (7 h a week → 1 h a day; 12 h → 1 h 45; 3 h → 25 m). It is the same every day of the week: no guessing which days the user will play, no rest days or free days, and nothing carried over from other days.
- **Done today** = all sessions that start today (timer, manual and catch-up), plus the running timer's elapsed time live.
- A day starts at local midnight. A session that crosses midnight counts towards the day it started (same as the calendar).

**4b · The long game**

- Big number: the total (rounded down) and "of 10,000 hours · N%".
- Stats row between hairlines: Pace (h/wk), **By Nov 2027** ("+624 h", what the weekly target adds by the end of the 12 months), Finish line.
- **Meet your future self** row (opens sheet 13).
- From 1 December to 15 January only, a **Your 2026** row under it opens the year card (section 17). No notification or pop-up.

**Shared hero details**
- The smiling sun rising out of the sea, full width, with a soft warm glow behind it. The sea is an opaque shape whose top edge is the navy wave line, filled with an opaque colour (#D3DEF4) that fades into the background colour over its bottom 34 pt, so the lower part of the sun is fully hidden behind the water. Inside it: a pale blue second wave line. No gold glints or reflections on the water (they read as the sun showing through). No glow or transparency in the water, so nothing of the sun shows below the waterline. The sun's height follows the gauge rules above.
- The hero is gently animated (all of it off with Reduce Motion):

| Element | Motion | Timing |
| --- | --- | --- |
| Navy wave + sea fill | Drift right together by one wavelength, seamless loop | 3.2 s, linear |
| Pale wave | Drifts left by one wavelength | 5 s, linear |
| Sun | Breathes: up 3 pt, scale 103% | 4 s, ease-in-out |
| Rays | Turn slowly | One turn per 90 s |
| Glow | Pulses with the breath | 4 s |
| Eyes | Every 7 s the sun opens both eyes for a short peek, then closes them | Open for about 0.35 s |

- **Water must cover the sun (build rule).** Layer order, back to front: glow → sun → sea fill → pale wave → navy wave line. Nothing gold is drawn on or in the water. The sea fill is one closed `Shape` whose top edge is exactly the navy wave path (same phase, moved by the same offset), filled with a fully opaque colour. Also clip the sun view to the area above the wave path (e.g. `.mask` with the inverted sea shape), so nothing of the sun can show between crests at any animation phase, scale or Dynamic Type size. The fade at the bottom of the sea goes on top of the sea, never as transparency in the sea itself.
- Stop the animation when Home is not visible, and keep it cheap (one TimelineView or a few repeating SwiftUI animations).
- Recent sessions are no longer on Home; they live in History (the day detail) and on the This week day bars (tap a bar to open that day).
- Bottom: one primary button **Start session**, with **Add past hours** as a text button under it. If a session is running, Start session becomes "Back to session · mm:ss" while the timer is running, or "Resume · mm:ss" if it is paused.

### 5 · History — Calendar (`design/Calendar.dc.html`)

- Segmented control Calendar | Growth.
- Grid of the last 53 weeks, one square per day, most recent week on the right, scrolled to the end; swipe to go back.
- Colours **and shapes** by daily logged hours (section 20): 0 = small blue dot (rest); < 1 h = thin bar, 1–2 h = taller bar, 2–3 h = rounded square, 3 h+ = full circle, coloured yellow → deep orange. Days before onboarding use the same blue dot.
- Tapping a day shows its total and sessions in the card below; sessions can be edited or deleted there. Each session row shows its photo (56 pt thumbnail) and note if it has them, otherwise "No note" in light grey (section 16).
- A day with at least one photo gets a tiny white dot (4 pt) in the centre of its square. The legend keeps Rest and Less → More (drawn with the shapes), and adds a second line: a square with the dot and "White dot: a day with a photo" (only once the user has at least one photo).
- Stats: **Rhythm**, **Steady for**, **Active days** in the window. There are no streaks anywhere in the app: nothing ever "breaks".
  - **Rhythm** = the user's typical practice days per week: the median number of days with any logged time per calendar week (Monday start) over the last 8 complete weeks plus the current week. Shown as "N days/wk".
  - **Steady for** = how many consecutive weeks, counting back from the current week, had at least (Rhythm − 1) practice days. Shown as "N weeks" ("1 week"). If Rhythm is 0, show "–".

### 6 · History — Growth (`design/Growth.dc.html`)

- Chart of cumulative hours over time: solid navy line for the past; from Today, a **dashed orange line at your chosen pace** up to 10,000 h with a small sun at its finish point, and a **dotted grey line (#9AA1B5) at your actual pace**. No band, and **no text on or next to the lines** (they can sit close together). The dashed 10,000 h line is labelled "Finish line · 10,000 h" at its left end.
- **Key under the chart** (above a hairline, 12 pt; 13 pt and placed between the headline and the chart in the full-screen version): two rows, each with a short sample of its line (26 pt wide), the name and the numbers on the right:
  - dashed orange — **Your chosen pace** (semibold, #C2531A) — "12 h a week · Nov 2035";
  - dotted grey — **Your actual pace** (semibold, #5E6782) — "9.5 h a week · 2039".
  - The key is one VoiceOver element: "Your chosen pace, 12 hours a week, finishes around November 2035. Your actual pace, 9.5 hours a week, finishes around 2039."
- Headline: "At your chosen pace, you'll finish around" / the chosen-pace month + year / "At your actual pace: around YYYY" (or "At your actual pace: after YYYY" beyond 30 years). When the actual pace is equal or faster, the last line reads "You're already playing at this pace".
- **What if I practise more?** slider, 0–10 extra h/week on top of the chosen pace; the orange line, its sun and the text update live ("About 1.4 years sooner, around May 2035"); without a change it reads "On top of your chosen pace of 12 h a week." Not saved.
- The chart card has a small expand button (36 pt circle, top right); tapping it or the chart opens the full-screen chart (section 19).
- At the bottom: a quiet **Your 2026** row (small sun, "A card of your year, to keep or share", chevron) that opens the year card (section 17). It is there all year.

### 7 · Add past hours (`design/LogPast.dc.html`)

- Fields: Day (date picker, today back to 1 January of the start year, no future; days before the onboarding date are allowed and add on top of the estimates, with a quiet note under the card: "Before you began. These hours add to your starting score, on top of your estimates."), Hours (0–12), Minutes (0, 5 … 55), Note (optional, 280 characters).
- Big preview "H:MM" updates live. Button label "Add N hours". Disabled at 0:00.
- Validation: a day's total (all sessions) cannot exceed 24 h; show an inline message if it would.

### 8 · One craft at a time — sheet (`design/OneCraft.dc.html`)

- Opened from **Switch to a new game** in Settings (the practice group, under Archived crafts). There is no + on Home. Explains the one-craft rule with the smiling sun.
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

**Screen 11 · Under 4 weeks (gap of 7–27 days): a stepper per week**

- Split the gap into 7-day blocks counting back from yesterday; leftover days (fewer than 7) join the oldest block. Example: a 22-day gap = 3–10 Oct (8 days), 11–17 Oct, 18–24 Oct.
- One stepper row per block: date range with "N days · about H h MM m a day" under it, then − · "N h" · + (0–168 h, step 1, default = current pace rounded).
- Running total "Adding N h" and the button "Add N hours" (disabled at 0).

**Screen 12 · 4 weeks or more (gap of 28+ days): one average**

- "N weeks have passed. Since <date>. On average, how many hours a week did you practise?"
- One big stepper 0–168 h/week, step 1 (default = current pace rounded), with quick picks 0, 5, 10, with Period (dates · days), Per day in calendar, and Adding (= average × gap days ÷ 7).

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
- A progress track from Today (current total) to the forecast finish date (at the chosen pace, "~Mon YYYY · 10,000 h"), with the sun at the end.
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

### 16 · A note and a photo, if you like (`design/NotePhoto.dc.html`)

One photo of what you made and a short line about it, attached to a session. Completely optional and low key: most days people just tap Save.

- **Finish sheet:** between the session time and Save, one row: a 64 pt dashed square with a camera icon (photo) and a soft field "A note, if you like" with the hint "What you made, what needs work". Nothing is focused or opened automatically: no keyboard, no camera. Save and Discard look and behave exactly the same with or without them.
- **Photo:** tapping the square offers **Take photo** and **Choose from library** (PhotosPicker, which needs no permission). With a photo, the square shows the thumbnail with a small navy ✕ to remove it. One photo per session.
- **Note:** plain text, up to 500 characters, multi-line, grows to 4 lines then scrolls.
- **Later:** tapping a session row in the History day card opens the same two fields (plus duration and delete, as today). This is also how a session finished from the Live Activity or the Watch gets a note or photo.
- **History:** the white photo dot in the calendar, the photo and note in each session row (section 5).
- **Photo, full screen:** tapping a thumbnail opens a dark full-screen viewer: close ✕, the date and "Evening · 1 h 15" at the top, the photo fitted, the note under it, and a strip of recent photo thumbnails at the bottom. Swiping left/right moves to the previous/next photo across all days (newest last). ··· offers Change photo, Edit note and Remove photo (with confirmation). Pinch to zoom.
- **Never asked again:** no reminders, prompts, badges, counts or empty states about notes or photos anywhere. No ratings, tags or questions.
- **Storage:** the photo is saved as JPEG (longest side 2048 px, quality 0.8), with location and other metadata removed, in `Session.photo` using SwiftData external storage. Thumbnails are made on the fly and cached in memory. It syncs through CloudKit only when sync is on, and is deleted with its session.
- **Privacy:** the camera needs `NSCameraUsageDescription`: "Take a photo of what you made, if you like." Asked only when Take photo is first tapped.
- **Accessibility:** the photo square is a button "Add a photo" / "Photo, double-tap to change". Thumbnails read "Photo from Thursday 22 October, evening session". The viewer supports VoiceOver swipes between photos and Dynamic Type for the note.

### 17 · Your year — a shareable card (`design/YearCard.dc.html`)

Once a year, the long game in one picture, to keep or share. No competition: nothing about other people, no ranking.

- **Where:** the "Your 2026" row at the bottom of History → Growth (all year, as the year so far) and, 1 December – 15 January only, under the stats on The long game tab. From 1 to 15 January the card shows the year that just ended. When more than one year has data, the title on the screen is a menu to pick the year.
- **Screen "Your year":** back chevron and the title; a segmented control **Sunrise | Evening | Photos**; the card preview scaled to fit; one row **Show hours** (switch, on by default; subtitle "Off shows days and percent instead"); a primary **Share** button. Photos only appears when the year has at least 6 sessions with a photo.
- **Story card (Sunrise and Evening), 9:16:**
  - Top: "MY 2026 IN THE LONG GAME" (12 pt, letter-spaced, gold #A0712E; #FFE08A on Evening) and the craft name (30 pt bold).
  - The happy sun (still, no animation) rising out of the sea, with its lower part fully hidden by the opaque sea, same rules as Home. Sunrise: sky #FFF6E6 → #FFE9C7, sea #D3DEF4 with the navy wave line. Evening: the Timer navy gradient, sea #2B3A73 with a pale wave line #9FB0E0. Nothing gold on the water.
  - Big number: hours played this year ("+624 h", 54 pt bold), "played this year".
  - The year's calendar as a strip of 53 weeks × 7 days, with the calendar's shapes and colours (rest is a small dot: #C5D0EC on Sunrise, #3D4D93 on Evening), with month labels Jan · Apr · Jul · Oct · Dec. Future days are left out.
  - Three stats: **Rhythm** ("5 days/wk"), **Most played** (month name), and the total ("3,294 h", "of 10,000").
  - Footer: small sun and "Long Game · the longest game, played in real life". No link or QR code.
- **Photos card, 1:1:** "MY 2026 · PIANO", "+624 h" and a small sun, then a 3 × 2 grid of photos from the year's most recent sessions with photos, then "241 days of practice · 3,294 of 10,000 h" and "Long Game". Long-press a tile in the preview to swap it for another of the year's photos.
- **Show hours off:** the big number becomes days of practice ("241 days", "of practice this year") and the total becomes the percentage ("33%", "of the way"). Notes are never on any card.
- **Numbers** (all derived in `Logic/`):
  - Hours this year = logged sessions (timer, manual, catch-up) that start in that calendar year. The onboarding estimate is not included. If onboarding was during that year, the subtitle reads "played since 12 March".
  - Days of practice = days in the year with any logged time.
  - Rhythm = the median number of practice days per week over the year's complete weeks (week start from Settings).
  - Most played month = the month with the most hours; on a tie, the later month.
  - Total = the overall total (baseline + logged) at the end of the year, or now for the current year.
  - With fewer than 4 weeks of data in the year, the rows that open the card are hidden.
- **Sharing:** render the card with `ImageRenderer` at 1080 × 1920 (stories) or 1080 × 1080 (photos), at scale 1 from a 360-pt-wide layout × 3, and share it as a PNG through `ShareLink` (the system share sheet: Instagram Stories, Messages, Save Image, …). The image always uses light or dark exactly as chosen, regardless of the system appearance, and fixed text sizes (not Dynamic Type) so it always fits.
- **Accessibility:** the preview is one element with a spoken summary ("Your 2026 in the long game: 624 hours played, practised 5 days a week, most in March, 3,294 of 10,000 hours"). The screen around it supports Dynamic Type and VoiceOver.

### 18 · The sun laughs when tapped (`design/SunGiggle.dc.html`)

A small secret: tapping the sun makes it laugh like a baby. It gasps, scrunches its eyes, tips its head back and bounces in little "ha-ha-ha" hiccups, just over a second, with a real child's laugh when the sound is on. No hint, tooltip or counter; it never changes any number.

- **Where:** the big sun on Home (all three tabs), the intro pages, the future-self sheet and the tip jar. On the Timer a tap only gets a soft wink (no sound, no wiggle), so a session is never disturbed. Not in widgets, the Watch, the Live Activity or the year card image.
- **Tap target:** the whole sun, at least 44 pt.
- **Faces:** two new faces. **Gasp:** wide open eyes (r 7.5 with highlights) and a round "o" mouth. **Baby laugh:** eyes as happy upward crescents ^ ^ (6 pt stroke), a big open mouth with a pink tongue, round cheeks (r 11, #F48FA8). Reuses **happy** for the contented end.
- **Timing:**

| Time | What happens |
| --- | --- |
| 0.00 | Tap. Soft haptic. |
| 0.00–0.10 s | **Gasp:** stretch to 94% × 108%, up 4 pt, gasp face. |
| 0.10 s | Laugh sound starts (if allowed, below). |
| 0.10–0.90 s | **Belly laugh:** baby-laugh face; the sun tips back 5° and does five quick bounces of 0.16 s each (squash 106% × 94%, down 3 pt ↔ stretch 97% × 104%, up 5 pt), each a little smaller. Rays jiggle with the bounces (up to 108%). Four small gold sparkles pop out and fade. Light haptics on the first three bounces (0.12, 0.28, 0.44 s), each softer. |
| 0.90–1.25 s | **Contented:** spring back (response 0.4, damping 0.55) to the happy face with eyes closed; one tiny 2 pt hiccup at 1.05 s; the deeper blush fades back to normal. |

- **Tapping again:** a tap during the laugh adds two more bounces instead of restarting; a new laugh sound only starts once the current one has finished (never two at once). Five taps within 2 s: a longer belly laugh (the longest clip, eight bounces) and one full spin of the rays, then a 3 s rest during which taps only get the wink.
- **Stays in place:** at most 6 pt of movement and 5° of tilt; the sun's spot on the gauge or arc doesn't change, and the sea and its mask stay in front.
- **Sound:**
  - A few short recordings of a child laughing, bundled with the app (`Resources/Sounds/giggle-1.m4a`, `giggle-2.m4a`, …), each about 1 s (max 1.5 s), AAC, with a short fade-out and matched loudness. One is picked at random, never the same twice in a row.
  - Played with `AVAudioSession` category **`.ambient`** (mix with others): silent when the Ring/Silent switch is on silent, follows the ringer volume, never stops or ducks the user's music or podcast. If other audio is playing (`secondaryAudioShouldBeSilencedHint`), skip the sound.
  - Volume 0.7 of the system level. Preloaded once with `AVAudioPlayer` so it starts instantly; no audio work at all if the setting is off.
  - **Settings:** a switch **Giggle sound** (on by default) under a small "Sounds" group.
- **Haptics:** as in the timing table, only when system haptics are on.
- **Reduce Motion:** no gasp, bounce, tilt or spin; the baby-laugh face shows for 0.8 s, with the haptic and sound as normal.
- **VoiceOver:** the sun keeps its label and gets one custom action, "Tickle the sun", which plays the face change, haptic and sound.

### 19 · Scrub the forecast — full-screen Growth chart (`design/GrowthScrub.dc.html`)

The Growth chart opens full screen; drag a finger along the line, from the first hour to the finish, and feel a light tap at each milestone.

- **Open:** tap the Growth chart or its expand button. The card grows into a full-screen cover (matched geometry, 0.4 s). Close with the ✕ (top right) or a swipe down. Works in portrait and landscape (landscape gives a wider chart); on wide windows (iPhone Duo open, iPad) it uses the full width.
- **Layout (portrait):** "Piano · the long game" and ✕ at the top; a headline block (small line, big line, accent line); the chart, same colours and parts as the card (past line, grey area under it, dashed chosen-pace line, dotted actual-pace line and the key, dashed "Finish line · 10,000 h", the sun at the finish, "Today" on the time axis), with y labels 0 · 2.5k · 5k · 7.5k · 10k. A quiet capsule hint "Drag along the line" at the bottom, hidden after the first scrub ever (Settings.scrubHintSeen).
- **Idle headline:** "You'll finish the game around" / "November 2035" / "Likely between 2034 and later" (same as the card).
- **Draw-in:** on open, the past line draws left to right (0.8 s, ease-out), then the dashed chosen-pace line (0.5 s), the dotted actual-pace line (0.3 s) and the sun pops onto the finish point with a small bounce. Reduce Motion: a 0.2 s fade instead.
- **Milestone dots:** 1,000 · 2,500 · 5,000 · 7,500 h as small dots on the line (4.5 pt radius, 2 pt stroke): filled navy when reached, white with an orange outline when ahead. 10,000 is the sun.
- **Scrubbing:** touch and drag anywhere on the chart (no long-press needed). A navy vertical line and a white dot with a navy ring follow the finger along the curve (past line or forecast). The headline shows the point:
  - Past: "Played" / "14 Sep 2022 · 1,000 h" (day precision), plus a "Played" chip in the floating label.
  - Future: "At your chosen pace" / "Feb 2029 · 5,000 h" (month precision), plus a "Forecast" chip.
  - On a milestone the accent line reads "Milestone reached" (past) or "Milestone · halfway" / "Milestone · 7,500 h" (ahead); at 10,000, "The finish line".
  - A floating white label (radius 14, soft shadow) next to the dot repeats the date, hours and a short line; it flips side so it never leaves the screen or sits under the finger.
  - Releasing the finger keeps the point for 1.5 s, then the headline fades back to the idle text.
- **Haptics:** a light impact when the scrub crosses a milestone (with a short gold ring around its dot, 0.4 s), and a soft selection tick when crossing Today and at the first/last point. Nothing for ordinary movement. Only when system haptics are on.
- **Reached dates:** the day the running total first reached the milestone. If it was reached within the onboarding estimate (before tracking began), show the month with "about" ("about Sep 2022 · estimate"), since that part of the line is estimated.
- **Forecast:** uses the forecast algorithm; if "What if I practise more?" is above 0, the full-screen chart uses that value too (not saved).
- **VoiceOver:** the chart has an Audio Graph (`accessibilityChartDescriptor`) and an adjustable action: swipe up/down steps through Start → each milestone → Today → Finish line, reading the same text as the headline. The close button is "Close chart".
- **Build notes:** Swift Charts with `chartXSelection(value:)` (iOS 17) for the scrub value, snapping the dot to the curve; milestones and dates come from `Logic/` (pure functions, tested). Haptics through `sensoryFeedback(.impact(weight: .light), trigger:)` keyed on the milestone index.

### 20 · Accessibility beyond the basics (`design/Accessibility.dc.html`)

Colour is never the only cue, and the sun is always described in words.

**Calendar shapes (for everyone, always on)**

| Level | Hours that day | Shape (in a 14 pt cell) | Colour |
| --- | --- | --- | --- |
| Rest | 0 | small dot, Ø 4 pt | #C5D0EC |
| 1 | < 1 h | thin bar 12 × 4 pt, fully rounded | #FFE48C |
| 2 | 1–2 h | bar 12 × 8 pt, radius 2.5 | #FFC53D |
| 3 | 2–3 h | rounded square 12 × 12 pt, radius 3.5 | #FF9A3C |
| 4 | 3 h + | circle Ø 13 pt | #EE6420 |

- Shapes are centred in the cell; the photo dot sits in the centre on levels 1–4 (white, Ø 3–4 pt). The selected day keeps its navy ring around the cell.
- The same shapes are used in the legend, the year card's calendar strip and anywhere else the calendar levels appear. With Increase Contrast, level 1 and the rest dot get a 1 pt darker outline.

**VoiceOver: the sun in words**

- Every sun gauge is one accessibility element whose label starts with where the sun is, in words, followed by the numbers. Values update when they change (`accessibilityValue`), without moving focus.
- Words for a fraction p of the way: 0 → "on the horizon"; < 0.15 → "just rising"; then the nearest of "a quarter" (0.25), "a third" (0.33), "halfway" (0.5), "two thirds" (0.67), "three quarters" (0.75); ≥ 0.9 → "almost there"; ≥ 1 → "there". Add "just over" / "just under" when p is within 0.05 of a step but not on it (≤ 0.01 counts as on it).
- Texts (one formatted, pluralised String Catalog string each):
  - This week: "The sun is just over halfway to your weekly target. 6.5 of 12 hours, 5.5 to go, 3 days left." (Above target: "The sun is above your weekly target. 13.5 of 12 hours.") Adjustable: swipe up/down moves through the days of the week, reading "Monday, 1 hour 10".
  - The long game: "The sun is a third of the way to the finish line. 3,294 of 10,000 hours. At your pace, around November 2035."
  - Today: label "Today's stretch, 1 hour 5 minutes of 1 hour 45 minutes.", value "40 minutes to go." Covered: label "Today's stretch, done for today.", value "1 hour 45 minutes of 1 hour 45 minutes." or "2 hours 10 minutes, 25 minutes extra today."
  - Timer: "Session 25 minutes. 5 of 12 rays lit, next ray in 2 minutes 42. Total 3,294.7 hours." When a ray lights during a session and VoiceOver is running, post a low-priority announcement "Ray 6 lit" (queued, never interrupting speech).
  - Calendar day: "Thursday 22 October. 2 hours, a good day. Has a photo." Level words: rest day / a little / some / a good day / a full day.
  - Growth: as in section 19.
- **Other non-colour cues:** past vs forecast = solid vs dashed line plus "Played" / "Forecast" text; "Target reached", "covered" and milestones always say so in words; the stretch arc's travelled part is thicker (3 pt) than the dotted track (2 pt).
- **Contrast and settings:** text at 4.5:1 or better; test with VoiceOver, Voice Control (every button has a visible or `accessibilityInputLabels` name), Dynamic Type up to AX5, Bold Text, Differentiate Without Colour, Increase Contrast, Reduce Motion and a greyscale filter.

### Steppers for choosing hours (`design/Steppers.dc.html`)

Every place where the user picks a number of hours uses a stepper, never a slider: the yearly rows (step 3, and the current-year version), Your pace for the year (3b) and both Catch-up screens (11, 12). The "What if I practise more?" slider on Growth stays a slider: it's for exploring, not choosing.

- **Row stepper:** label (and optional sub-line) on the left, then a 36 pt round − button (#F3F0EA, navy glyph), the value (17 pt semibold, tabular, min 58 pt wide, centred), and a 36 pt + button. Each button has at least a 44 pt touch area.
- **Big stepper:** 56 pt round − and + either side of the big number (64 pt bold), unit under the number.
- **Tap:** one step (1 h; 0.5 h for the weekly target), with a selection haptic.
- **Hold:** after 0.4 s repeats 6 steps a second, after 1.5 s 12 a second, until released. A rigid haptic when a limit is reached.
- **At a limit:** that button turns pale (#F6F4EF, glyph #C9C3B8) and does nothing, but stays focusable so VoiceOver can say "Minimum" / "Maximum".
- **Tap the number:** opens a small sheet with the label, the value with a caret, "0 to 168" ("1 to 168" for the weekly pace), **Done** and the number pad (decimal pad for the weekly target). Out-of-range values snap to the nearest limit; empty means unchanged.
- **Quick picks** (Catch-up average only, never on the weekly pace): chips that set the value in one tap; the chip matching the current value is navy.
- **VoiceOver:** each stepper is one adjustable element ("2023, 10 hours a week"); swipe up/down steps; the two buttons are hidden from VoiceOver. Voice Control: "Tap plus", "Tap minus" work on the buttons.
- **Dynamic Type:** the value and labels grow; at accessibility sizes the row wraps so the label sits above the − value + group.
- **Liquid Glass (iOS 26+):** the round buttons use `.glass` (section on Liquid Glass); older iOS keeps the flat fills above.

### 21 · Launch screen and the opening sunrise (`design/Launch.dc.html`)

Every game begins at dawn. The app opens on a still night sea with the sun asleep on the horizon. The sun then rises into the day and lands in its place on Home.

**1 · The launch screen (still, shown by iOS)**
- iOS shows this the instant the icon is tapped, before the app has loaded, so it can't move.
- Contents:
  - the night sky of `design/redesign/Sky.dc.html` (navy, a peach glow at the horizon, stars and the crescent moon);
  - the night land and sea of `Land.dc.html`, with the shoreline at 60% of the screen height;
  - the sleeping sun of `Launch.dc.html` (Sun.dc.html, face "sleepy", no lit rays): 150 pt, centred, with its centre exactly on the shoreline so only its top half shows. All 12 rays are drawn faintly (22%), with the sun's soft gold halo behind it and a small blue-grey "z" (#8FA2E0) at its top right.
- No text, logo or wordmark. Launch screens aren't localised, and Apple asks that they don't look like an ad.
- Built as `LaunchScreen.storyboard`, because a storyboard can pin the sea to the bottom and the sun to the waterline on every screen size. The land and sea are a vector PDF; the sky and the sun are 2x/3x bitmaps (both have translucent gradients, which a PDF bands). `Tools/MakeLaunchAssets.swift` draws all three. The colours come from the asset catalogue.
- The water rule applies as everywhere: the sea is opaque and drawn in front of the sun, with nothing gold on or in the water.

**2 · The sunrise (in the app, 0–1.1 s)**
- The app's first frame draws exactly the same night scene in SwiftUI, so the hand-over from the still image is invisible.
- Then, together (all fades ease-in-out):
  - the night sky (with its stars and moon) and the night land fade away, showing the dawn sky and the day land underneath;
  - the sun rises 120 pt (on an 844 pt screen) with the curve `cubic-bezier(.45,0,.25,1)`;
  - 0.55–0.92 s: the sleeping sun cross-fades into the happy sun, so its rays light up and the "z" goes.

**3 · Good morning (1.1–1.4 s)**
- The sun opens its eyes for a moment (1.1–1.18 s open, 1.32–1.4 s closed again).

**4 · Settle (1.4–2.2 s)**
- The sun glides and shrinks into its spot on Today's arc (same curve as the rise).
- From 1.62 s the whole scene, sun included, fades out and Home shows underneath, so the sun hands over to Home's own sun.
- These are the keyframes of `design/redesign/Launch.dc.html`, which plays the same thing slowed down to a 7 s loop. `Logic/OpeningSunrise.swift` maps each board percentage to app time.
- The whole opening takes about 2 seconds, and a tap skips it.

**When it plays**
- Only on a cold start, when the app process launches. Coming back from the background goes straight to the app as it was.
- A tap anywhere skips to the end at once.
- It never plays when the app is opened from a widget, the Live Activity, a notification or a link. Those go straight to where they point.
- A running session doesn't change it: the full sunrise plays (the Launch board makes no exception).
- Before onboarding (first launch), it ends on Welcome instead of Home.
- With **Reduce Motion** on, or **VoiceOver** running: the short version, a 0.3 s cross-fade from the night frame to Home.
- In **dark mode** the launch screen is the same night frame. The sunrise stops at dusk and cross-fades into Home in dark.
- No sound and no haptic.
- The opening layer is hidden from VoiceOver. Focus lands on Home's first element once it's gone.
- **iPad and Mac:** the same scene, with the sea always spanning the full width. The Mac has no system launch screen, so its first window opens on the night frame and plays the sunrise.
- Debug option: "Play opening sunrise" replays it without restarting the app.
- Debug option (Settings): **Fill a sample year** adds this year so far as sessions that look like a real person's year, the same every time. A seeded generator (SplitMix64, seeded with the year) gives each week an energy (0–1); about 8% of weeks are a break, where 85% of days are rest. Otherwise a day is rest with probability 0.20, plus 0.14 on Saturday and Sunday, minus energy × 0.14. On a practice day, x = random × 0.75 + energy × 0.42 gives the level (1 below 0.33, 2 below 0.58, 3 below 0.84, otherwise 4) and the session length is picked inside that level's hours. About 1 in 7 practice days gets a sample photo. The previews' sample year and the designs (`Calendar.dc.html`, `YearCard.dc.html`) use the same rule. **Remove the sample year** deletes only those sessions.

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
- **Finish** opens a sheet: duration (editable ± 5 min, cannot exceed real elapsed time), the optional photo and note row (section 16), **Save** and **Discard**. Sessions under 1 minute offer Discard only.
- **Long sessions:** after 4 h running, send a gentle notification ("Still practising?"); at 12 h auto-pause.
- **Haptics:** light tick when a ray lights; success haptic on each golden hour and on save.

### Today's stretch on the Timer (`design/TodayStretch.dc.html`)

- **No banner or strip on the session screen.** The Timer shows only the sun, the total, the session clock and "Next ray in".
- When today's stretch is covered during the session, the sun winks once and a quiet gold line "Today's stretch covered" (13 pt semibold, #FFE08A) appears under "Next ray in". The session keeps running.
- **Never interrupt a session:** no pop-up, sheet, alert, sound or extra haptic for the stretch. The ray haptics stay as they are.
- The Finish sheet shows one small line above the buttons when this session covered today's stretch: "Today's stretch covered."
- Live Activity, widgets and the Watch stay as they are for now.

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
| Finish → Save | The Saved moment continues the Timer's scene (same sky, glow, sun and opaque sea in front) at today's progress with this session counted: p = (saved today + this session) ÷ today's stretch, sun centre y = 470 − 245p in the 844 pt layout. The sun shows the celebrate face and jumps 36 pt up and back (sin(q·π)); the glow swells up to 25%; mini suns and petals burst from the sun's current position (the sea hides what is below the horizon). "Saved", "+40 m · today 1 h 05" and one accent line ("40 m left of today's stretch" or "Today's stretch covered.") fade in from 0.3 to 0.8 s under the sea, coloured like the running Timer. Reduce Motion: no jump, no burst, a 0.3 s fade. Home's total counts up from old to new value. | Jump and burst 1.2 s, dismissed at 1.4 s; count-up 1.2 s |

Layout under the sun, top to bottom: the overall total in large gold numbers with one decimal ("3,294.7") and "of 10,000 hours · N%", counting up live as the session runs; a short divider; "This session" with the session clock; then the caption "Next ray in m:ss".

**Reduced Motion:** no breathing, motes, spin, burst or hour bounce (the sparkle ring fades instead); rays light with a fade; the sky stays fixed. VoiceOver reads "N of 12 rays lit, M minutes into this hour" once per ray.

Build notes: drive everything from elapsed time in a TimelineView (do not use timers for state). The sun is one SwiftUI view with face states: happy, focus, wink, sleepy, celebrate. The design's Timer screen shows the running state animated (CSS keyframes there are a reference for timings).

## Forecast algorithm

The finish line is worked out from the pace the user has **chosen** (Your pace for the year), so it's motivating and in their hands. The pace they have actually played lately ("your actual pace") is shown next to it for comparison. "Rhythm" stays reserved for days per week in History.

**Inputs**

- *T* = total hours now (baseline + logged).
- *p* = chosen weekly pace (`Settings.weeklyTargetHours`).
- *e* = extra hours from the What-if slider (0 when not used).
- *r* = actual pace, h/week: the lifetime average (total hours ÷ weeks since 1 January of the first estimate year), blended with the recent 12-week logged pace. Recent logging gets weight 0.5 × (weeks of data ÷ 12), so up to half. This is separate from the Home "Pace" stat.

**Lines** (straight lines from Today)

| Line | Weekly rate | Used for |
| --- | --- | --- |
| Chosen pace | p + e | Headline date, Home "Finish line" stat, Meet your future self, Your year, the dashed orange line and its sun, Growth scrubbing |
| Actual pace | r | The dotted grey line, the key and "At your actual pace: around YYYY" |

Finish date = today + (10,000 − T) ÷ rate weeks. A rate of 0 means "not within 30 years".

**Display rules**

- Headline = chosen-pace date as "Month YYYY"; the line under it = actual-pace year.
- If a line doesn't reach 10,000 h within 30 years, show "after YYYY" for it.
- Past 10,000 h: no forecast; the headline reads "You crossed the finish line on 12 May 2035".
- What-if text = difference between the chosen-pace date with and without *e*, in months (under 12) or years to one decimal.
- Recompute when the chosen pace changes, a session is saved, edited or deleted, and when estimates change.

## Accounts, sync and notifications

No account and no sign-in: the app uses the iCloud account already on the device. iCloud only adds backup and multi-device sync.

**Accounts and sync**

- **Save to iCloud** switch in onboarding step 3c and in Settings (on by default when an iCloud account is available). There is no Sign in with Apple. Turning it off keeps the data on the device and stops syncing; the iCloud copy stays until the user chooses "Delete iCloud copy" in Settings.
- Restore: on a new or reset device with the same Apple Account, Welcome back offers to continue the game (section 0).
- CloudKit private database mirrors all entities. Conflicts: last edit wins per session; sessions are never merged.
- A running timer syncs its timestamps (startedAt, pausedAt, accumulated pause, device) through iCloud as one small `ActiveSession` record, so a session started on one device shows on the others (iPhone, Mac) and any of them can pause or finish it. Only one active session at a time; if two devices start at once, the earlier start wins and the other device shows it. The Watch keeps using WatchConnectivity with the iPhone.
- Settings opens from the gear in the Home bar (and from the gear in History). Its first row is "Support Long Game" (the tip jar, screen 14). Under it, an **iCloud** group: the **Save to iCloud** switch, a status line ("Up to date", "Syncing…", "Last synced 10:42", or "Sign in to iCloud in the Settings app to keep a copy"), and **Delete iCloud copy** (with confirmation; the data on this device stays). No account, sign-in or sign-out rows. Its practice group has Your estimates, Archived crafts and **Switch to a new game** (opens the One craft sheet, screen 8). It also offers Export (CSV of sessions, including notes; photos are not exported) and Delete all data (photos included).

**Notifications** (all off by default; asked once, on the last setup step "A gentle nudge" (3d). Starting a session never shows a permission prompt; the milestone and long-session notifications are still planned, and iOS drops them if permission was not given)

Settings keeps a switch for the daily reminder and the rhythm nudge. Both start off for everyone; Settings is the only place to turn the daily reminder on (at 19:00 on every day to start) and choose its time and days. Turning one on asks iOS only if it never asked (someone who chose Not now). If notifications are off for Long Game, the switch stays off and a line reads "Notifications are off for Long Game in iPhone Settings" with an **Open Settings** button to the app's page in the Settings app.

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

- Two widgets: **The sun** (small, with Edit Widget → This week / The long game) and **This week and the long game** (medium, and the three Lock Screen sizes). The medium widget's long-game bar opens the long game tab; everything else opens This week.
- Data: the app mirrors what is *stored* (craft, estimates, every session's start and length, week start, weekly target) into `widget-data.json` in the App Group `group.com.wehavesun.LongGame.shared`, whenever any of it changes. The widgets compute totals, this week and today from that with the same Logic code; nothing derived is stored.
- Tapping opens Home on the matching tab (deep link `longgame://home/week` or `longgame://home/longGame`).
- Timeline: reload when a session is saved, edited or deleted, at midnight, and at the start of each week. While a timer runs, widgets show the saved total; the Live Activity shows the live time.

## Apple Watch app (`design/Watch.dc.html`)

A small companion app, dark and simple, same sun.

- **Two swipeable pages:** This week and The long game. Each has the sun rising over a dark sea with a small scale line and a gold tick at the sun's height, the big number and a short line ("of 12 h · 3 days left", "33% · finish ~2036"). The This week page has a gold **Start** button.
- **Timer:** focus sun with this hour's lit rays, the session clock, "3,294.7 h · next ray 2:42", **Pause** and **Finish**. A light tap on the wrist (haptic) when a ray lights. Pausing shows the sleepy sun and Resume.
- **Finished:** happy sun, "+42 m", "7.2 of 12 h this week", **Done**.
- **Complications:** circular (ring fills with this week's hours, sun inside), rectangular (sun, "6.5 / 12 h this week", bar), corner/inline ("6.5h").
- **Sync:** one session at a time across devices. A session started on the watch shows on the phone (and its Live Activity) and vice versa. The running timer is just timestamps, copied both ways over WatchConnectivity whenever it changes (latest-value context, plus a direct message when the phone is in reach); the newest change wins. The phone sends the watch its stored data (craft, estimates, session starts and lengths, week start, target) as a file whenever it changes, and the watch works out the same numbers with the app's Logic. A session finished on the watch (a minute or more) is queued to the phone with its own id, which the phone saves under that id so it is never saved twice; until the phone's data includes it, it still counts on the watch. If the phone is unreachable, the watch keeps the session and the system delivers it when it can. iCloud sync of the phone's database is separate and unchanged.
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

## iPad (`design/iPad.dc.html`)

The same universal app on iPad (iPadOS 17 or later): no separate download, the same iCloud game, and one running session shared with iPhone, Mac and Watch. The layout is chosen by window size (as for iPhone Duo), never by device.

- **Wide windows** (landscape full screen, or a Stage Manager window at least 1000 pt wide): the sidebar layout shared with the Mac app. Sidebar (260 pt, #EFEBE4): craft name and "3,294 of 10,000 h", **Play** (Today, This week, The long game), **History** (Calendar, Growth, Your 2026), **Settings** at the bottom; 40 pt rows, 15 pt text. Content: a 28 pt title with capsule buttons **Add past hours** (#EFEBE4) and **Start session** (navy) on the right; the sun gauge with its scale and the big total on the left; on the right a 340 pt column of cards: chosen pace · finish line · By Nov 2027 · Rhythm; Today with today's sessions; Meet your future self.
- **Tall full-screen windows** (portrait): Home's three tabs as a floating capsule at the top (Today · This week · The long game); "Piano" (34 pt) with round History and Settings buttons; a larger sun gauge (sun 220 pt); the big total (72 pt); two cards side by side (numbers, and Today with today's sessions); the Meet your future self row; **Add past hours** and **Start session** side by side at the bottom, 56 pt capsules. History, Growth and Your year open full screen as on iPhone, with wider content (max 760 pt).
- **Narrow windows** (Slide Over, a third or half of Split View, under about 600 pt wide): exactly the iPhone layout.
- **Timer** in wide windows: the focus sun (about 340 pt, with glow) on the left; on the right the craft, the gold total (56 pt), "of 10,000 hours · 33%", then "This session", a 104 pt clock and "Next ray in", and Pause / Finish as 180 pt capsules. Readable from a music stand or across a studio. Tall windows use the iPhone Timer, scaled up.
- **Keyboard** (when one is attached): ⌘N start or finish a session, Space pause or resume, ⌘L Add past hours, ⌘1–⌘5 views, ⌘, Settings; all listed when holding ⌘.
- **Also:** pointer hover effects on rows and buttons and pointer scrubbing on the Growth chart; drag an image from Photos or Files onto a session or the Finish sheet's photo square; Apple Pencil Scribble in the note field; the widgets on the iPad Home Screen and Lock Screen; the Live Activity where iPadOS supports it; Liquid Glass on iPadOS 26; alternate app icons as on iPhone.

## Mac app (`design/Mac.dc.html`)

For crafts practised at a desk (writing, coding, design, composing). A native SwiftUI Mac app, macOS 14 Sonoma or later, in the same Xcode project as a second app target that shares `Models/`, `Logic/` and `DesignSystem/`. Universal purchase: the same free App Store app on iPhone and Mac. With Save to iCloud on, everything syncs with the iPhone through the same CloudKit container.

- **Main window** (default 1180 × 740, min 900 × 600): a sidebar on #EFEBE4 with the craft name and "3,294 of 10,000 h", then groups **Play** (Today, This week, The long game) and **History** (Calendar, Growth, Your 2026), and **Settings** at the bottom. A toolbar with the view's title, **Add past hours** (bordered) and **Start session ⌘N** (navy). The Timer opens in the window when a session runs (Finish → the Finish sheet).
- **The long game view:** the sun gauge with its scale on the left (about 520 × 340, sun 190 pt, same sea and water rule) with the big total and "of 10,000 hours · 33%" under it; on the right a column (330 pt) of three white cards: (1) a 2 × 2 grid Your chosen pace · Finish line · By Nov 2027 · Rhythm; (2) Today: "1 h 05 of 1 h 45 · 40 m to go" (covered: "· Done for today" or "· 25 m extra today") and today's sessions; (3) Meet your future self. Today and This week use the same two-column layout with their own gauge and numbers.
- **History views** reuse the iPhone layouts at a wider size (Calendar and the day card side by side; Growth with its key, full width; scrubbing with the pointer, haptics on Force Touch trackpads only).
- **Menu bar extra** (`MenuBarExtra`, window style): a small sun icon; while a session runs it shows the clock ("25:18"), otherwise today's time ("1 h 05"). The popover (320 pt):
  - running: craft name and total, a navy card with the focus sun, "This session", the clock and "Next ray in", today's arc with "1 h 30 of 1 h 45 · 15 m to go" (covered: "· done" or "· 25 m extra"), **Pause** (Space) and **Finish**, and "Open Long Game ⌘O";
  - idle: today's arc with the big time and "of today's 1 h 45 · 40 m to go" (covered: "today's 1 h 45 · done", or "· 25 m extra" when over), **Start session ⌘N**, and links Add past hours / Open Long Game.
  - Settings option **Show in Dock** (on by default); off keeps only the menu bar sun.
- **Keyboard:** ⌘N start or finish a session · Space pause or resume (when the window or popover is focused) · ⌘L Add past hours · ⌘1 ⌘2 ⌘3 Today, This week, The long game · ⌘4 ⌘5 Calendar, Growth · ⌘, Settings. All in the menus (File, View, Session).
- **Also:** the same widgets on the desktop and in Notification Center (WidgetKit for macOS); notifications as on iPhone; drag an image onto a session (or the Finish sheet's photo square) to attach it; Liquid Glass on macOS 26 behind `if #available`; full keyboard access, VoiceOver, and Dynamic Type equivalents (the app follows the system text size where SwiftUI supports it).
- **Not on Mac:** Live Activities, the Apple Watch link and the alternate app icons (the Mac shows the current icon stage as its Dock icon instead, via `NSApp.applicationIconImage`, when "App icon grows with you" is on).

## App icon (the "10,000 ring")

The icon grows with the user: one new icon for every 1,000 hours, using iOS alternate app icons.

**Eleven icons** (asset sets `AppIcon`, then `AppIcon-1000`, `-2000`, … `-10000`; each has Any, Dark and Tinted):

| Stage (`IconStage(thousands:)`) | Ring filled | Number | Sun |
| --- | --- | --- | --- |
| 0 (primary, the start icon) | none, track only | 10,000 | 12 o'clock, happy |
| 1 … 9 | 10% … 90%, a tenth more each | 1,000 … 9,000 | tip of the arc, happy |
| 10 | 100% | 10,000 | 12 o'clock, celebrate face, 1.3×, halo r 132 |

**Geometry** (1024 × 1024, square, no transparency): ink #16244A background; track = circle at (512, 512), r 360, stroke 56, white 14%; arc = same circle in #FFD15C, round caps, from 12 o'clock clockwise to −90° + 360° × hours ÷ 10,000; sun = SunView geometry at 1.1× centred on the arc's end, on an ink halo r 112; number = SF Pro Bold 176, tracking −6, white, centred, as outlines. **Dark** = same artwork. **Tinted** = black background, white arc, sun and number, track white 20%.

**Generated** by `swift Tools/MakeIcon.swift LongGame/Resources/Assets.xcassets` (one function, `drawIcon(hours:look:)`). `DesignSystem/IconStageView.swift` draws all eleven stages with the real SunView for Xcode previews (normal, dark, tinted). The alternate sets are listed in `project.yml` (`ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`).

**When it changes** (`Logic/IconStage.swift`, `App/AppIconManager.swift`):
- `IconStage.for(totalHours:)` is the whole thousands reached, capped at 10 (2,500 h is still stage 2). `IconStage` is a count of thousands, not named cases.
- **1,000, 5,000 and 10,000** have a milestone celebration: the icon changes after the user taps its main button, so the system "You have changed the icon" alert never covers it. The 2,500 and 7,500 celebrations never change the icon themselves; they only release a stage that a jump was waiting for. 100 and 500 do nothing.
- **Every other thousand** (2,000, 3,000, 4,000, 6,000 … 9,000) has no celebration. The icon changes right after the user saves the session that crossed it (Finish sheet, Add past hours, Catch-up), once the sheet or timer has fully closed (`onDismiss`), so the alert appears over Home. While a sheet, the timer or Settings is up, nothing changes.
- A session saved from the Live Activity or the Watch while the app isn't active changes the icon the next time the app becomes active and Home appears.
- A jump over several thousands goes straight to the highest stage: one change, one alert.
- `setAlternateIconName` is called only when the app is active, `supportsAlternateIcons` is true, no session is running, and the wanted icon differs from `alternateIconName`. `AppSettings.appliedIconStageRaw` records the stage as a number; an unknown value (for example an old name) is treated as "set it again".
- When the total goes down (deleted sessions, lowered estimates) the icon is lowered quietly, once, on the next launch or return to the foreground (and whenever Home appears). Replace my craft sets the plain icon at once. A higher stage never jumps ahead of a celebration of 1,000 h or more that is due.
- New users already past 1,000 h get their stage once, when Home first appears after onboarding.
- Settings → **App icon grows with you** (on by default, below the reminders): "Grows every 1,000 hours". Off sets the primary icon; on sets the current stage.

## Visual system

Simple, flat and calm: warm-white background, flat white cards only where content needs grouping, navy text, one smiling sun. One primary action per screen; secondary actions are text buttons. No decorative icons next to labels.

**Tokens**

| Token | Value | Use |
| --- | --- | --- |
| background | #FAF8F4 | All light screens |
| surface | #FFFFFF, radius 18–22, soft shadow 0 8 24 at 6% navy (the We Have Sun redesign) | Cards (sheets keep a soft top shadow) |
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

### Liquid Glass (iOS 26 and later) (`design/LiquidGlass.dc.html`)

On iOS 26 and later, the tabs and buttons use Apple's Liquid Glass. On iOS 17–25 the app looks exactly as described above (flat). Only the system glass APIs are used, never a hand-made blur.

| Control | iOS 26+ look | API |
| --- | --- | --- |
| Segmented controls (Home: Today / This week / The long game; History: Calendar / Growth; Your year: Sunrise / Evening / Photos) | Glass capsule track; the selected tab is a brighter lens that slides and stretches to the tapped tab | Custom capsule control in a `GlassEffectContainer`, track `.glassEffect(.regular, in: .capsule)`, lens `.glassEffect(.regular.interactive())` + `glassEffectID` with a namespace so it morphs between tabs |
| Toolbar icons (History, +, Settings, back, Timer close) | 44 pt glass circles | `.buttonStyle(.glass)` with `.buttonBorderShape(.circle)` |
| Primary button (Start session, Save, Share, Start playing, …) | Capsule, navy-tinted glass, white text | `.buttonStyle(.glassProminent)` + `.tint(ink)`, `.buttonBorderShape(.capsule)`, 56 pt high |
| Secondary button (Add past hours, Discard, Keep playing, …) | Clear glass capsule, navy text, 48 pt high | `.buttonStyle(.glass)`, `.buttonBorderShape(.capsule)` |
| Timer: Pause / Resume | Clear glass capsule on the night sky, white text | `.buttonStyle(.glass)` |
| Timer: Finish | Bright glass capsule, navy text | `.buttonStyle(.glassProminent)` + `.tint(.white)` |

- **Glass only on controls.** The sun, sea, numbers, cards, the calendar, charts and sheet contents stay flat. No glass on glass.
- **Something to refract:** History, and Home on iPad, the Duo open and Mac, get a soft warm wash at the top of the background (#FFF0D6 fading into #FAF8F4 by about 40% of the screen). On a phone Home has no wash: its glass controls float on the sky itself (update 34). The content scrolls under them.
- **Shapes:** controls become capsules (corner radius = half the height); cards keep their 20–24 pt corners.
- **Accessibility:** Reduce Transparency and Increase Contrast make the system glass solid automatically; keep text contrast at 4.5:1 or better (navy on light glass, white on dark glass). With Reduce Motion the lens moves without the stretch.
- Sheets and the Live Activity keep the system's own appearance.

## Accessibility, edge cases and scope

**Accessibility**

- Dynamic Type up to AX5 (the largest accessibility size); big numbers scale down before wrapping. The three Home tab names and the calendar's weekday and month labels stop growing at XL (like system tab bars) so they stay whole.
- VoiceOver labels on every icon button and chart (the Growth chart reads its headline and range; calendar days read "Thursday 22 October, 2 hours").
- Calendar levels differ by shape and lightness, not only hue (section 20); rest days are labelled.
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

## We Have Sun redesign (update 32)

The sky, land and colour system replaced the old flat scene everywhere. Boards are in `design/redesign/`.

- **Scene:** `SceneTone` (night, dawn, day), `SkyView`, `LandView` (390 × 120 box, shoreline 46 down, dunes run behind an opaque sea). The sea is always opaque and always in front of the sun. All three Home heroes are 305 tall with the water at 231, so the water sits at the same height on Today, This week and The long game.
- **Stars (update 37):** a natural star field, like a dark sky over the Alentejo (`Logic/StarField.swift`, from `design/redesign/Sky.dc.html`). Seeded by the sky's size, `(round(w) × 73856093) XOR (round(h) × 19349663)`, with mulberry32, so each size has its own stars that never move. Stars live above `top = h × horizon × 0.9`; count `clamp(round(w × top / 1500), 14, 170)`. 32% fall in a soft Milky Way band from (0.08w, 0.02·top) to (0.98w, 0.97·top), spread by a gaussian (average of three uniforms) of σ ≈ 0.1 × min(w, top); the rest are uniform. They thin towards the horizon (dropped with probability (y / top)² × 0.7). Four classes: 62% radius 0.45 white at 45%, 26% 0.65 white at 70%, 9% 0.9 white at 90%, 3% 1.3 warm #FFF4D6 at 100%; each radius × 0.85–1.15. Opacities × 1 at night, × 0.45 at dawn, none by day. Stars are drawn before the moon. Every SkyView uses it (launch, Welcome, the empty day, The long game, Timer, year cards, widgets, Live Activity, Watch, Mac); the launch bitmap is drawn with a copy in `Tools/MakeLaunchAssets.swift` for a 402 × 874 screen (iPhone 17, iPhone 18 Pro), horizon 0.6, so on those phones it matches the first animated frame exactly; other sizes stretch it to fit. The app icon keeps its five hand-placed stars; session pictures keep their own seeded stars.
- **Opening sunrise:** a pure timeline (`Logic/OpeningSunrise.swift`), styles skip, full and short. The sun glides to its Home position. Dark mode plays the full sunrise too.
- **Timer:** the sun's height is today's progress p = (saved today + running) ÷ today's stretch. Night fades out by p 0.5, dawn peaks at 0.5, day is in by 0.95; text goes white to navy between 0.55 and 0.85. Once covered the sun stays up for the day. Timer state is still timestamps.
- **Session pictures:** drawn from a stable seed (FNV-1a of id, start minute and length) with palettes by part of the day, a sun sized by length and raised by `sunriseProgressAtEnd`, and one line per 5 minutes (2 to 18). Cached as PNGs in Caches. A session can hide its picture (`hidesDefaultPicture`) or replace it with a photo.
- **Photos:** a photo counts as viewed after 1 s on screen, once an hour. Year cards choose pinned, then most viewed, then a stable shuffle of the unopened. Settings → iCloud & storage shows sizes, "Your photos" with delete-by-year, and clears only the default-picture cache.
- **Apple Watch:** the session screen is the same sunrise, with the clock, today's total line (`WatchModel.todayLine`), a progress bar, Pause and Finish. Always On keeps the sun's height with the sleepy face, dims the sky, hides the buttons, shows minutes only and updates once a minute. Reduce Motion and Always On move the sun in whole minutes (`WatchSunrise`). A longer haptic plays when the sun is fully up.
- **Widgets, Live Activity, iPad, Mac:** same scene and colours, still pictures. The Mac sidebar icons are unchanged.
- **App icon:** navy gradient (#0B1433, #16244A, #2B2A4A), five faint stars, a warm glow from the bottom, track white 14%, amber arc (#FFE08A to #F0922A) with a soft glow, the sun on the tip on a navy halo, the number in white. Same 11 stages; Dark and Tinted included.

