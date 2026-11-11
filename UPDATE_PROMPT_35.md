# Update prompt 35 for Claude Code: direct words on Today, and a more natural sample year

Paste everything below the line into your Claude Code session in this folder.

---

Two small changes. Stay on the `redesign` branch.

## 1 · Direct words for today's stretch

The line under Today's number stops talking about the moon. The dotted arc and the moon stay in the picture; only the words change.

| State | Line under the number (`TodayQuietLine`) |
| --- | --- |
| In progress | **40 m to go** |
| Covered, within a minute of the stretch | **Done for today** |
| Covered, a minute or more over | **25 m extra today** (the time beyond the stretch) |

- Add the extra time to the covered case: `extra = done − target`, in whole minutes, formatted with the same `clockUp` style ("25 m", "1 h 10").
- Change `StretchText.toGo` to "\(time) to go", and add `StretchText.doneForToday` and `StretchText.extraToday(_:)`. Use them everywhere the old wording appeared:
  - `TodayQuietLine` (phone, wide pane);
  - the Today card line in `HomeView` ("1 h 05 of 1 h 45 · 40 m to go");
  - `MenuBarText.todayLine` and `idleCaption` on the Mac ("of today's 1 h 45 · 40 m to go"; covered: "today's 1 h 45 · done", or "· 25 m extra" when over).
- VoiceOver (`SunWords.today` and `StretchText.description`) drops the moon too:
  - in progress, label "Today's stretch, 1 hour 5 minutes of 1 hour 45 minutes." and value "40 minutes to go.";
  - covered, label "Today's stretch, done for today." and value "1 hour 45 minutes of 1 hour 45 minutes." or "2 hours 10 minutes, 25 minutes extra today."
- Leave the Weekly target explainer ("Each day, a stretch from the sea to the moon.") as it is. It describes the picture, not the progress.
- String Catalog: remove "%@ to the moon", "You reached the moon." and "Today's stretch is covered. The sun has reached the moon." if nothing else uses them; add the new strings with British spelling.
- Tests: the three states, including exactly at the target, 30 s over (still "Done for today") and 25 min over.

## 2 · A sample year that looks real

The debug **Fill sample year** in Settings and `YearSummary.sample()` (previews) use a fixed arithmetic pattern, so the calendar and the year cards show diagonal stripes. Replace both with a seeded random generator, so it looks like a real person's year but is the same every time:

- A small deterministic generator (e.g. SplitMix64 seeded with the year) in a shared helper, used by both.
- Each week gets an energy (0–1). About 8% of weeks are a break, where 85% of days are rest.
- A day is rest with probability 0.20, plus 0.14 on Saturday and Sunday, minus energy × 0.14.
- On a practice day: `x = random × 0.75 + energy × 0.42`, then the level is 1 below 0.33, 2 below 0.58, 3 below 0.84, otherwise 4. For the sample sessions, pick a length inside that level's range.
- About 1 in 7 practice days gets a sample photo.
- The designs `design/redesign/Calendar.dc.html` and `YearCard.dc.html` use this same rule, so you can compare.

This needs nothing from my Apple Developer account.

When you're done:
- build and run all the tests;
- update `docs/SPEC.md` (Today's line and the debug option) and `docs/AUDIT.md`;
- tell me how to see each Today state and the new sample year in the Simulator.
