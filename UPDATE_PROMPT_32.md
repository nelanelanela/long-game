# Update prompt 32 for Claude Code: the We Have Sun redesign (ships 1 December)

The redesign files are in `design/redesign/` (57 `.dc.html` screens and components, plus `canvas.json` for how they are laid out). They are the visual reference for everything below.

Paste everything below the line into your Claude Code session in this folder.

---

We're giving Long Game a new look, "by We Have Sun": warmer light, Alentejo dunes meeting the sea, nights with stars, and the same smiling sun. Everything below ships together on 1 December, so work on a branch `redesign` and keep the app building after every part.

Please read `design/redesign/` first, especially `Main`, `Sun`, `Land`, `Sky`, `SunInteractions`, `Timer`, `TimerProgress`, `SessionArtExamples`, `YearCard*`, `SavedPhotos*` and `Settings`. The CSS and JS in those files show sizes, colours and timings; build everything natively in SwiftUI.

**Ground rules**
- This is a visual redesign plus a few small features, listed below. Don't change the data model, sync, forecast or any number logic except where a part says so.
- Keep every existing sun behaviour: breathing, slowly turning rays, the eye peek, a ray every 5 minutes, the whole-hour bounce, sleepy on pause, the save burst, milestones and the giggle (gasp, baby laugh, sound, haptics, five-tap laugh, the Timer wink). Only the scenery around the sun changes.
- Remove every remaining **ring** visual and mention, and the **half-hour block** concept, from screens, copy, VoiceOver labels and the String Catalog. The app icon ring is the only ring that stays.
- Liquid Glass (iOS 26) stays as built; the minimum stays iOS 17.
- All new text goes in the String Catalog, British spelling, sentence case.

## 1 · Design tokens (`DesignSystem/`)

Replace the colour set with these named colours (no dark-mode variants unless listed):

| Name | Hex | Use |
| --- | --- | --- |
| background | #FAF7F1 | Screens |
| navy | #16244A | Text, primary buttons |
| muted | #5E6782 | Secondary text |
| sunBody / sunRays | #FFC93C / #FFB627 | The sun (unchanged) |
| cheek | #F7A1B5 | Sun cheeks (laugh: #F48FA8) |
| peachWash | #FFF0D6 | The wash behind Home's top titles (setup steps: #FFF1DA) |
| tabTrack | #EFE2CF | Segmented control track |
| amber / ember | #F0922A / #B4561A | Accents, destructive-soft buttons |
| night | #0B1029 | Night sky, Timer base |
| sea / seaDeep | #CFD8EF / #E3E8F4 | Sea gradient (night: #1A2148 → #111737 → #0B1029) |
| dune / duneFar | #DCCDB8 / #EBD6BC | Dunes (night: #232442 / #5A4A5E) |
| contour | #9FB0E0 | Sea lines (night: #3D4D93) |

Type stays Inter / SF with the current scale. Primary buttons: navy, radius 16, 56 pt. Cards: white, radius 18–22, shadow `0 8 24 rgba(22,36,74,0.06)`.

## 2 · The scene: `SkyView`, `LandView` and the sun

- **SkyView(tone: .night / .dawn / .day, horizon:, moon:)**: night is a navy gradient with small stars and a crescent moon; dawn is navy → violet → warm peach at the horizon; day is transparent (the screen background shows). The warm glow is clipped at the horizon so nothing gold ever shows below it.
- **LandView(tone:, still:)**: asymmetric dunes (a tall dune on the left, a lower one on the right, a mid layer in front), then the sea: a gradient from sea at the top through seaDeep to the background colour at the bottom, with a navy shoreline (55% opacity) and four contour lines spaced wider as they go down (at 55, 64, 74, 85 of a 120-tall box; opacity 0.7, 0.5, 0.32, 0.18). Shapes as in `Land.dc.html`; keep its soft S-shaped shoreline.
- **The water moves.** The shoreline and each contour line sway gently side to side (±6–7 pt, with a 0.6–0.8 pt dip) on their own ease-in-out loops of 7, 8, 9, 10 and 12 s, out of phase. The sea fill itself doesn't move. `still: true` for widgets, the Live Activity and the year card image; Reduce Motion stops the sway.
- **Water rule:** the sea and the solid fill below it are always opaque and always in front of the sun, at every height, during every animation and every cross-fade. When two sea layers cross-fade (night → day), keep the lower layer fully opaque and fade only the top one. Add a preview test that places the sun at its lowest point on every screen and checks no ray shows below the sea.
- **SunView**: same character. Add an `idle` flag (default on): breathing (4 s, up 4 pt, 104.5%, halo pulse), rays turning (one turn per 120 s) and the blink (every ~9 s; happy opens both eyes for 0.5 s, focus peeks one eye). Off in widgets, the Live Activity, Watch complications, the year card, the app icon and during the launch animation.

## 3 · Launch

As in `Launch.dc.html` and the orange note beside it: a still night launch screen (sun asleep, half under the night sea, no text); on cold start, about 1 s: the sky warms to dawn and the stars fade (0–0.5 s), the sun rises and opens its eyes for a moment (0.5–0.65 s), then glides and shrinks into its place on Home while Home fades in (0.65–1 s). A tap skips it. Reduce Motion: a 0.3 s cross-fade. No animation when returning from the background.

## 4 · Onboarding and Welcome

- Welcome and the intro pages get the new scene (dawn sky, sun, land) and the line **by We Have Sun** under the wordmark.
- 0b copy: "…starting score. Not sure how many? We'll work it out together, one year at a time."
- 0c copy: "Start the timer, or add your hours later. Each hour is a step. What matters most is to keep walking."
- Remove the **Why this game** section from Your game (step 1).
- Keep all logic, steps and buttons.

## 5 · Home

- The hero is the new scene; heights as in the boards (Today 305, This week 272, The long game 285) so the sea is never clipped.
- The title area keeps the peach wash; the segmented control **Today | This week | The long game** sits on the tabTrack colour.
- Empty day: "The sun is up." / "What will you practise today?" and **Begin**.
- Save toast: "1.5 h added." (formatted value).
- This week: remove the weekly note box ("what helped / what got in the way").
- Today's sessions: rows without a photo show a **session picture** (part 8) instead of the clock icon.

## 6 · Timer: one sunrise a day

The session screen becomes a sunrise that follows **today's** progress, not the session's.

- `p = todayMinutes / todayStretch`, clamped 0…1. A session starts from where the day left off (the first session of the day starts in the dark at p = 0).
- Sun centre y = horizon − (horizon − top) × p (in the 844-pt board: 470 − 245p). At p = 1 the sun is fully up and **stays there** for the rest of the session and the day.
- Sky cross-fade: night opacity 1 − p/0.5; dawn rises to 1 at p = 0.5 then fades out by 0.95; day fades in from 0.5 to 0.95. Land: the night land and navy fill are always opaque; the day land and background fill fade in on top from p = 0.45 to 0.85.
- Text colour mixes from white to navy between p = 0.55 and 0.85; the big today number from #FFD66B to ember.
- Under the sun: today's total, "of today's 1 h 45", a progress bar (the part before this session in a softer gold), "This session" and the clock, then "Next ray in m:ss", or "Today's stretch covered." once p reaches 1 (with the celebrate face for 1.3 s and a success haptic).
- Copy: "The phone can rest."
- Paused: sun sinks 24 pt, sleepy face, sky desaturated (saturation 0.55, brightness 0.88), "Paused. The sun is resting.", **Resume** in gold and **Finish**. Rebuild the paused state from the running screen, not as a separate layout.
- A tap on the sun: only the soft wink, as now.

## 7 · Milestone, Future self, Settings copy

- Milestone: "A thousand hours." (and the matching line for each milestone).
- Meet your future self: remove Why this game. The text becomes three short lines with bold lead-ins:
  - **Who you're becoming.** Every hour you play shapes the person you'll be at 10,000.
  - **How Long Game helps.** It keeps that person in view, counts every step and shows how close you are.
  - **Why steady matters.** A little, most days, beats a lot once in a while. That's how hours turn into mastery.
  - Above Keep playing: *Nature does not hurry, yet everything is accomplished.*
- Weekly note notification: "Your week in the sun: 6.5 of 8 hours."
- Settings footer: "Long Game · by We Have Sun" and the version.

## 8 · Session pictures (new)

Sessions without a photo get a small abstract "session sunrise", drawn from the session itself (`SessionArt.dc.html`, rules in `SessionArtExamples.dc.html`). Nothing is stored as an image.

- **Data:** add `sunriseProgressAtEnd: Double` to `Session` (today's p when the session ended; for manual and catch-up entries, compute it from the day's order of sessions). Migration: fill it for existing sessions the same way.
- **Seed:** a stable hash of the session's id, start minute and length, so the same session always draws the same picture on every device.
- **Drawing** (a SwiftUI `Canvas`, 240 × 240 design units, scaled):
  - Palette by start hour: night (< 5:30 or ≥ 21:30), morning (< 10), midday (< 14:30), afternoon (< 18), evening. Exact colours in `SessionArt.dc.html`.
  - Horizon 150–164 (seeded); sun x 60–180 (seeded); sun radius 18 + min(minutes,150)/150 × 34; sun y = horizon + 0.15r − p × 90; radial glow behind it.
  - A back dune and a front dune from two seeded sine waves; then flowing lines over the front dune, one per 5 minutes (2 to 18), parallel to it and fading in amplitude as they go down.
  - Night and evening add soft glowing lines and a few stars.
- **Cache:** thumbnails go in the Caches directory for smooth scrolling and are redrawn whenever missing.
- **Where:** Today's sessions on Home, the day card in History, the Watch session list if there is one. A photo always takes its place.
- **VoiceOver:** "Session picture, morning, 40 minutes".

## 9 · History

- Calendar day shapes, all the same 12 pt size: the least hours a circle (radius 6, #FFE48C), then radius 4 (#FFC53D), radius 2 (#FF9A3C), and the most hours a square (#E8561E). Rest days: a 4 pt dot (#C5D0EC).
- A day with a photo gets a white 4 pt dot in the centre (with a hairline outline on the lightest level).
- Legend: "Rest is part of the craft.", Less → More with the four shapes, and "White dot: a day with a photo".
- The tab switcher uses the tabTrack colour.

## 10 · Your year cards

- **Sunrise** and **Evening** stories (9:16) in the new scene: dawn sky + day land, or night sky + night land with the big number in gold; the calendar strip's rest colour is #DCE3F3 / #2A3566. Same content and Show hours switch as now. Hours off: "241 days", "of practice this year", and the total becomes "33%", "of the way".
- **Photos** (1:1): peach-to-background wash, "MY 2026 · PIANO", the big number and the sun, a 3 × 2 grid, the summary line and "Long Game".
- **Which photos:** add `viewCount: Int` and `lastCountedAt: Date?` to the photo (or its session). Count an open in the photo viewer once the photo has been on screen for 1 s, at most once per hour. The card uses the six most-viewed photos of the year (ties: newer first), then fills with the most recent. A photo swapped in by long-press stays for that year (store the pinned ids per year). The count is never shown and is deleted with the photo.

## 11 · Settings: storage and sounds

- **Sounds:** the **Giggle sound** switch, subtitle "When you tickle the sun. Silent in silent mode".
- **iCloud & storage** group:
  - Save to iCloud (as now).
  - **Your photos** · "214 photos · 486 MB" → opens the Your photos screen.
  - **Default pictures** · "3.1 MB cache · never your photos" with a **Clear** button that empties only the session picture cache. VoiceOver: "Clear the default pictures cache. Your photos are not affected."
- **Your photos screen:** total size, "N photos you added to your sessions. The default pictures drawn by the app aren't here; they take no space.", then one card per year (newest first) with count, size, five thumbnails (the last showing "+N") and **Delete all photos from 2025…** in red. Footer: "Deleting photos keeps your sessions, hours and notes. Tap a photo in History to delete just one."
- **Delete confirmation** (action sheet): "Delete all 112 photos from 2025?" / "This frees 254 MB. Your 2025 sessions, hours and notes stay. The photos are removed from this iPhone and from iCloud, and can't be brought back." / **Delete 112 photos from 2025** (destructive) / Cancel. Delete only the photos (and their view counts) for sessions starting in that year.
- Sizes come from the stored photo data; compute them off the main thread.

## 12 · Beyond the phone

- **Watch:** the session screen becomes the same sunrise (today's progress, night → dawn → day, sun stays up when covered), with today's total, the clock, the time, a progress bar, Pause and Finish. Always On: the sun stays at its height with the sleepy face, the sky dims, buttons hide, minutes only, updated once a minute. A longer haptic when the sun is fully up. Reduce Motion: the sun moves in steps once a minute. Complications keep their layout in the new colours, still.
- **Widgets and Live Activity:** the new sky, land and colours; no animation; the sea in front of the sun.
- **iPad and Mac:** same scene and colours; keep the Mac sidebar icons as they are.

## 13 · App icon

The original ring icon, restyled (`Icon.dc.html`): a navy night gradient (#0B1433 → #16244A → #2B2A4A) with five faint stars and a warm glow from the bottom edge; the track in white at 14%; the arc as an amber gradient (#FFE08A → #F0922A) with a soft glow; the sun riding the tip on a small navy halo; the number in white Inter Bold. Same 11 stages and change rules for "App icon grows with you". Export all stages at the required sizes, plus Dark and Tinted.

## Checks

- Previews for every changed screen in light, at the smallest and largest Dynamic Type, and with Reduce Motion on.
- Tests: the Timer's p and sun position (first session, a later session, after the stretch is covered), `sunriseProgressAtEnd` for timer, manual and catch-up entries, the session picture seed being stable, photo view counting (1 s, once per hour), the year card photo choice, delete-by-year (only that year's photos, sessions untouched) and cache clearing (photos untouched).
- Search the project and the String Catalog for "ring", "half an hour", "half-hour", "Why this game" and "to the moon" (the empty-day line only) and remove what's left.

This needs nothing from my Apple Developer account except uploading the new app icon set with the build. If anything else does, ask me first.

When you're done:
- build and run all the tests;
- update `docs/SPEC.md` and `docs/AUDIT.md`;
- tell me how to see the launch animation, the Timer sunrise, a session picture and the Your photos screen in the Simulator.
