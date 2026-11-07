# Update prompt 26 for Claude Code: a simple daily stretch, no 40 h cap, a forecast at the chosen pace, today's sessions

Paste everything below the line into your Claude Code session in this folder. Do it in four parts and check each in the Simulator before the next. Everything Claude Code needs is written out here. The spec (`docs/SPEC.md`: "4c · Today", "3", "3b", "6 · History — Growth", "19", "Steppers for choosing hours" and "Forecast algorithm") and the designs `HomeToday`, `Growth` and `GrowthScrub` were just updated. Read them from disk again.

---

**Part 1 · Today's stretch = weekly pace ÷ 7**
- Replace the stretch calculation with: **stretch = weekly pace ÷ 7, rounded to the nearest 5 minutes**, the same every day. For example:
  - 7 h a week → 1 h;
  - 12 h → 1 h 45;
  - 3 h → 25 m.
- Remove the guessing about which days the user will play:
  - the practice-day detection;
  - the free day (or rest day) state, with its screen, strings, VoiceOver text and tests;
  - the "week covered" state on the Today tab;
  - carrying shortfalls over from other days.
- Keep the stretch-covered state ("You reached the moon."), the moon, and the quiet line "40 m to the moon".
- `TodayStretch` should now only have `.inProgress(stretch, done)` and `.covered(stretch, done)`.
- **Tests:** 7 → 60 min, 12 → 105 min, 3 → 25 min, 0.5 → 5 min, 100 → 857 min; the same value on every weekday; "done" from today's sessions plus the running timer.

**Part 2 · No 40-hour cap**
- Hours-per-week pickers go up to **168** (every hour of a week) instead of 40:
  - the yearly rows in onboarding and in Settings: 0–168, step 1;
  - the weekly pace: 1–168, step 0.5;
  - Catch-up weeks and Catch-up average: 0–168, step 1.
- `YearEstimate.hoursPerWeek` allows 0–168.
- The typed-entry sheet says "0 to 168" (or "1 to 168" for the pace).
- The limit of 24 h for a single day stays as it is.
- **Tests:** clamping at 168, typing 200 snaps to 168, and the baseline maths with large values.

**Part 3 · The finish line at the chosen pace**
- Replace the forecast with two straight lines from today:
  - **Chosen pace:** rate = the weekly pace from "Your pace for the year" + the What-if extra. Finish date = today + (10,000 − total) ÷ rate weeks.
  - **Recent pace:** rate = the current blended pace (lifetime average blended with the last 12 weeks, as now).
- Remove the Low, Mid and High scenarios, the yearly trend, the likely-range band, and the "within 25% of the target" rule.
- The chosen-pace date is used everywhere a finish date appears:
  - the Growth headline;
  - the Home "Finish line" stat;
  - Meet your future self;
  - Your year;
  - full-screen scrubbing.
- **Growth chart:**
  - the past line, as now;
  - a **dashed orange line at the chosen pace** to 10,000 h, with the small sun at its end and a small orange label "Your pace";
  - a **dotted grey line (#9AA1B5, dash 1–6, round caps) at the recent pace**, with a small grey label "Recent pace";
  - no band and no legend.
- **Headline:**
  - "At your chosen pace, you'll finish around" / "November 2035" / "At your recent pace: around 2039".
  - Show "after YYYY" past 30 years.
  - If the recent pace is equal or faster, the last line reads "You're already playing at this pace".
  - Past 10,000 h, it reads "You crossed the finish line on 12 May 2035".
- **What if I practise more?** adds to the chosen pace. With no extra it reads "On top of your chosen pace of 12 h a week."
- **Full-screen chart:**
  - the same two lines;
  - draw-in: the past line, then the dashed line, then the dotted line, then the sun;
  - future points read "At your chosen pace";
  - VoiceOver describes both lines.
- **Tests:**
  - the finish date at several paces;
  - a 0 pace;
  - beyond 30 years;
  - past 10,000 h;
  - the What-if difference;
  - the recent pace equal to or faster than the chosen pace.

**Part 4 · Today's sessions under the Today tab**
- Under "40 m to the moon", add a small header "Today's sessions" (13 pt semibold, #8A93AB) and one row per session that started today, oldest first, separated by hairlines. Each row has:
  - a 40 pt photo thumbnail, or a small clock icon on #F1EDE6 when there's no photo;
  - the time range "07:40 – 08:20" (14 pt semibold), with the note under it (13 pt, one line, ending in an ellipsis if too long; "No note" in light grey when empty);
  - the duration on the right ("40 m", 15 pt semibold).
- A running timer appears as the first row, "Now · 12 m", with a small pulsing dot (still with Reduce Motion).
- Tapping a row opens that session to edit, in the same sheet as in History.
- With no sessions today, hide the section.
- The rows add up to the big number.
- If the rows don't fit, the area under the hero scrolls, while Start session and Add past hours stay fixed at the bottom.
- VoiceOver reads each row: "7:40 to 8:20, 40 minutes, Scales and arpeggios. Has a photo."
- Add previews with 0, 2 and 6 sessions and a running timer, and at AX5.

When all four parts are done:
- build and run all the tests;
- update `docs/AUDIT.md`;
- list the files you changed;
- tell me how to check each part in the Simulator.
