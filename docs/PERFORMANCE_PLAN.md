# Performance plan: making Long Game feel smooth

15 November 2026. Steps 1 and 3 of the suggested order are done (see "Done so far" at the end); the measuring
(step 2) is next and needs your iPhone.

"Smooth" means three things you can feel:

1. **No stutters (hitches):** scrolling, tab switches and the sun's glide never skip a frame.
2. **Quick to respond:** a tap does something within 0.1 s, and the app opens fast.
3. **Calm when idle:** with Home just sitting there, the phone stays cool and the battery barely moves.

Part 1 is how we measure, with Xcode Instruments. Part 2 is what reading the code turned up: the places most likely to
cost frames, ranked. The plan is to measure first, fix the top items, then measure again, so every change is backed by
a number and not a guess.

---

## Part 1: Measuring with Instruments

### Ground rules

- **A real iPhone, a Release build.** The Simulator runs on the Mac's processor and graphics card, and a Debug build
  is several times slower than what people get, so both give the wrong picture. In Xcode: Product › Profile (⌘I)
  builds Release and opens Instruments. This needs the phone signed in to your developer account, which you already
  use to run the app on your phone.
- **The oldest phone you can borrow is the most useful one.** If it is smooth on an iPhone 12, it is smooth everywhere.
- **Heavy data.** Most problems only show with years of sessions. I'd add a debug-only launch switch
  `-demoData.heavy`: 8 years of near-daily sessions (about 2,900), 300 of them with photos, all milestones passed.
  Today's `-demoData` is much lighter.
- **Each run: 3 times, write down the middle number** in the results table at the bottom.

### The six sessions to record

| # | Instruments template | What you do on the phone (about 30 s) | What we read |
|---|---|---|---|
| 1 | **App Launch** | Quit the app fully, start recording, the app opens and plays the sunrise | Time to first frame, and anything slow before it (SwiftData opening, iCloud, sounds) |
| 2 | **Animation Hitches** | Home: switch This week ↔ The long game 5 times, open and close the Timer, scroll Settings, scroll the Calendar | Hitch ratio (ms of hitch per second of scrolling) and each red hitch bar, with what the main thread was doing |
| 3 | **SwiftUI** (new in Xcode 26) | Same as 2, then leave Home still for 20 s with the Timer running minimised | Which views redraw, how often, and how long each body takes. The key question: does Home redraw every second? |
| 4 | **Time Profiler** | Open Growth full screen, scrub the chart, open the Year screen, open Photos | The heaviest functions. Anything of ours over 5 ms on the main thread is a fix |
| 5 | **Power Profiler** (or Energy Log) | Home untouched for 2 minutes; then the Timer running for 2 minutes with the screen on | CPU and GPU use when nothing changes. Goal: close to zero when idle |
| 6 | **Allocations + Leaks** | Open and close the Timer, Photos and Year screen 10 times each | Memory that keeps growing, photos kept in memory after their screen closes |

Instruments shows an instrument's track as a timeline. Clicking a red bar (a hitch) and then the Main Thread track
below shows exactly which code was running at that moment. I can read the saved `.trace` files with you: save each
recording (File › Save) into a `perf-traces/` folder and I'll go through them.

### Making traces easy to read (small code change)

Add named markers (signposts) around the app's own moments, so they appear as labelled bars in every recording:
"Opening sunrise", "Home summary", "Growth history", "Calendar month", "Photo thumbnail", "Widget publish". About
20 lines in a new `Logic/Signposts.swift`, using Apple's `OSSignposter`. They cost nothing in normal use.

### Guarding it automatically (performance tests)

So it stays smooth after future changes, add to `LongGameUITests` next to the existing launch test:

- **Scrolling test:** scroll Calendar, Settings and Growth with `XCTOSSignpostMetric.scrollingAndDecelerationMetric`
  (Apple's own hitch measure).
- **Tab switch test:** the This week ↔ The long game glide, with the same hitch metric.
- **Idle test:** Home still for 20 s with `XCTCPUMetric`: catches anything that keeps the processor busy.

And unit tests in `LongGameTests` with `measure` around the heavy `Logic/` functions with 2,900 sessions: Home's
summary, `GrowthSeries`, the calendar levels, the forecast. Xcode remembers a baseline and fails the test if one gets
more than 10% slower.

### Goals

| Measure | Goal |
|---|---|
| Launch to first frame (iPhone 12, Release) | under 0.4 s |
| Hitch ratio while scrolling and switching tabs | under 5 ms/s (Apple calls this "good") |
| Any single main-thread task | under 8 ms (one frame at 120 Hz) |
| CPU with Home idle, no Timer | under 5% |
| CPU with the Timer running | under 10% |

---

## Part 2: What the code review found

Ranked by how much I expect each to matter. "Likely" means the code makes it very probable; Part 1 confirms it.

### 1. Home rebuilds itself every second while a session runs (likely the biggest)

`HomeView` has a `tick` that changes every second while the Timer runs minimised, and every 30 s otherwise
(`TodayLive`, `HomeView.swift:1700`). Each tick reruns all of Home's `body`, which turns every session into a plain
value again (`sessions.map(\.record)`, ~16 ms with 4,000 sessions in Debug), works out the week bars, the stretch,
the summary, and reloads today's photos. That is a stutter waiting to happen every second, right while the sun and
the sea are animating. The start button also has its own one-second clock (`HomeView.swift:1691`).

**Fix:** keep the work that depends on sessions in a value that is worked out only when the sessions change, and
let only the small live parts (today's minutes, the button's clock) tick, each inside its own `TimelineView`. Home's
big body then only runs when something real changes.

### 2. Three or four 30 fps animations run on Home all the time

The sea and dunes (`LandView`, `Scene.swift:175`), the idle sun (`SunView.swift:52`) and the weather layer
(`WeatherLayerView.swift:19`) each have their own 30 frames-per-second clock, forever. Each one redraws its whole
`Canvas` from scratch every frame.

- **Weather is not paused** when the app is covered or in the background (the sea and the sun are). Easy fix: pause
  on `scenePhase` like the others.
- **Clouds are blurred again every frame** (`drawLayer` + `.blur` per cloud), but they drift across the sky over
  15 minutes, so they move less than a pixel a second. Draw the clouds once and slide the picture instead, or redraw
  them once a second.
- **One clock instead of three:** a single `TimelineView` on Home that hands the time to the sea, sun and weather
  means one redraw per frame instead of three separate ones.
- **30 fps on a 120 Hz screen:** the sea at 30 fps is fine (it is slow), but the **sun's glide and tab switch** should
  run at the screen's full rate so they look silky on ProMotion phones. Worth checking those aren't capped.

### 3. Photos read from disk while the screen is being drawn

Photos live in their own files (good). But `PhotoThumb` takes the whole photo's `Data` as an input, so to show a
56 pt thumbnail the screen first loads the full ~0.5 MB file, on the main thread, during drawing. This happens in the
Calendar day card (`CalendarTab.swift:243`), the Year screen's photo picker (`YearScreen.swift:292`), Home's today
list (`HomeView.swift:445`, every tick, see 1) and the memory card. The thumbnail itself is made in the background,
and cached, but only after the file was read.

**Fix:** give `PhotoThumb` the session's id and a way to load the photo, check the thumbnail cache first, and read
the file only in the background when it is not cached.

### 4. Every session, of every craft, read at the top of the app

`WidgetSync` (`WidgetBridge.swift:41`), attached to the app's root view, has an unfiltered `@Query` for all sessions
and works out the widget snapshot on every redraw of the root. The root redraws when anything in it changes, and the
snapshot walks all sessions each time.

**Fix:** filter to the active craft, and work the snapshot out only when the sessions change (or a few seconds after,
grouped), not on every root redraw.

### 5. Settings and Data storage load all sessions up front

`SettingsView` has four session/craft queries, including all sessions of all crafts (`SettingsView.swift:17-21`),
and `DataStorageView` the same. Opening Settings loads everything just to show a few numbers. Count them in the
background (as `PhotoLibrary.loadStats` already does for photos) or with `fetchCount`.

### 6. Smaller things to check in the traces

- **Shadows:** 31 `.shadow` modifiers, several on cards that scroll. Shadows are drawn by the GPU each frame. If the
  hitch trace shows GPU time on scrolling screens, give those cards a fixed shadow shape
  (`.shadow` on a `RoundedRectangle` background rather than on the whole card).
- **Calendar's 371 day squares** are separate views; if the Calendar scroll shows hitches, draw the grid in one
  `Canvas` and keep VoiceOver elements on top.
- **Growth chart:** already thinned to 180 points (good); check the draw-in at 120 Hz.
- **Launch:** confirm nothing waits on SwiftData or iCloud before the first frame (the audit says it doesn't; App
  Launch will prove it on a device).
- **The pulsing dot** in Today's sessions uses `repeatForever`; fine, but make sure it stops when off screen.

---

## Suggested order

1. Add signposts and `-demoData.heavy` (small, makes everything after it measurable).
2. Record the six sessions on your phone, Release build, and fill in the "Before" column.
3. Fix 1 (Home's tick) and 3 (photos): the most likely stutters.
4. Fix 2 (animations) and 4 (widgets): idle battery and heat.
5. Record again, fill in "After"; add the performance tests so it stays that way.
6. Fix 5 and anything new the traces show.

## Results

| Measure | Before | After |
|---|---|---|
| Launch to first frame | | |
| Hitch ratio: Home tab switch | | |
| Hitch ratio: Calendar scroll | | |
| Hitch ratio: Settings scroll | | |
| CPU, Home idle | | |
| CPU, Timer running | | |
| Home redraws per minute, Timer minimised | | |
| Memory after 10× Photos open/close | | |

## Done so far (15 November 2026)

- **Markers:** `Logic/Signposts.swift`. In Instruments they're on the "Points of Interest" track: "Home figures",
  "Session records", "Photo read", "Photo thumbnail", "Widget snapshot", "Widget publish".
- **Heavy sample game:** launch switch `-demoData.heavy` (Debug builds). In Xcode: Product › Scheme › Edit Scheme ›
  Run › Arguments, add `-demoData.heavy`, run once on the phone (the first launch takes a little while, it is writing
  eight years). It is written only once, so after that run you can Profile (⌘I, a Release build) and the data is
  still there. `-demoData` puts the small sample game back.
- **Finding 1, Home every second:** Home now keeps the sessions' values between redraws
  (`Features/Home/SessionRecordsCache.swift`) and reads them again only when a session is added, removed or edited
  (here or from iCloud). Today's list looks only at today's sessions instead of all of them. Home still redraws
  every second while a session runs, but each redraw no longer goes through the whole history.
- **Finding 3, photos:** thumbnails made from a saved session (`PhotoThumb(session:)`) check the thumbnail memory
  first and read the photo's file only when it isn't there, after drawing. Home's today rows no longer carry the
  photo's bytes (they were compared every second). The photo viewer's strip is lazy, so opening it no longer reads
  every photo. Known gap: a photo replaced on another device keeps its old thumbnail until the app is restarted.
- Tests: `LongGameTests/PerformanceTests.swift`.
