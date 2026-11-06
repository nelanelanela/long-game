# Update prompt 11 for Claude Code: Today's stretch, and no glints on the water

Paste everything below the line into your Claude Code session in this folder.

---

The spec and designs have been updated. Please read these parts of `docs/SPEC.md`:
- "4 · Home", especially the new **4c · Today: today's stretch** and "Shared hero details";
- "Today's stretch on the Timer", in the Timer section;
- the `lastHomeTab` line in the data model.

Also read `design/TodayStretch.dc.html`, `design/HomeWeek.dc.html` and `design/Home.dc.html`. Then implement the following. Work in two parts. After each part, build, run the tests, tell me how to see it in the Simulator, and wait for my OK before the next.

**Part 1 · The water: remove the gold glints**
- Remove the small gold glints (dashes) on the water everywhere they appear: Home, the intro pages, the future-self sheet, the iPhone Duo layouts and the widgets. They make it look as if the sun is showing through the sea.
- Nothing gold or yellow may be drawn on or inside the water. Layer order, back to front: glow → sun → sea fill → pale wave → navy wave line.
- Keep everything else about the sea exactly as it is: opaque fill, sun masked above the wave path, the drift animation and Reduce Motion.
- If I already removed some of this myself, keep what I did and just finish the job.

**Part 2 · Today's stretch**

*Logic (in `Logic/`, pure functions, nothing stored):*
- `practiceDays(sessions, today, weekStart)`: a weekday is a practice day if I practised on it in at least 2 of the last 4 full weeks. With less than 2 full weeks of history, or if no days qualify, every day counts.
- `todayStretch(...)` returns one of these states:
  - `.stretch(target, done)`
  - `.covered(target, done)`
  - `.restDay(done)`
  - `.weekCovered(done)`
  - `.noTarget`
- How the stretch is worked out:
  - stretch = (weekly target − hours logged this week before today) ÷ practice days left this week, including today;
  - round to the nearest 5 minutes, with a minimum of 15 minutes;
  - the stretch is fixed for the whole day.
- "Done today" counts every session that starts today (timer, manual and catch-up), plus the running timer's elapsed time.
- Use the target that applies this week (the TargetPeriod history).
- **Tests**, at least:
  - the rounding and the 15-minute minimum;
  - a short yesterday spreading over the remaining days;
  - today's sessions not changing today's stretch;
  - rest days;
  - the week already covered;
  - no history yet (every day counts);
  - week start on Sunday versus Monday;
  - a session crossing midnight;
  - a time-zone change.

*Home: a third tab:*
- The segmented control becomes **Today | This week | The long game**.
- Home opens on **Today** every time the app starts. Right after onboarding it still opens on The long game, once. Update `lastHomeTab`.
- The Today tab:
  - The sun moves along a wide dotted arc from the sea on the left to a small pale-blue moon on the horizon on the right.
  - The part the sun has travelled is a solid gold line. There are no ticks or labels.
  - Big number: today's time ("1 h 05"). Under it: "of today's 1 h 45". Then one quiet line: "40 m to the moon".
  - Use the exact text from the spec for the other states: covered, week covered, rest day and playing on a rest day.
- Reuse the same sun and sea components and the same water rule. At 0 the sun's lower half is hidden by the sea.
- Switching tabs: the sun glides between its spot on the arc and its spot on the scale (0.6 s). With Reduce Motion it moves without animating.
- VoiceOver reads the picture as one element, for example: "Today's stretch: 1 hour 5 minutes of 1 hour 45. 40 minutes to go."
- Add the third tab to the iPhone Duo wide layout too.

*Timer:*
- Add the slim stretch strip under the Timer header: a small arc that fills live, with "Today's stretch" and "1 h 05 of 1 h 45". Drive it from the same `TimelineView` as the clock.
- When the stretch is covered mid-session:
  - the strip turns gold ("1 h 45 · covered");
  - the sun winks once;
  - a quiet gold line "Today's stretch covered" appears under "Next ray in".
- **Never interrupt the session.** No pop-up, sheet, alert, sound or extra haptic.
- Hide the strip on a rest day or when the week is already covered.
- In the Finish sheet, show the line "Today's stretch covered." when this session covered it.
- Leave the Live Activity, the widgets and the Watch as they are.

All new text goes in the String Catalog, with British spelling. Everything must support VoiceOver, Dynamic Type and Reduce Motion. Add a debug option to set "hours this week before today" and to make today a rest day, so I can see every state.

When you're done:
- build and run all the tests;
- update `docs/AUDIT.md`;
- tell me how to see each state in the Simulator.
