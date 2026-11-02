# Update prompt 09 for Claude Code: pace for the year, Home tabs, widgets, Apple Watch

Paste everything below the line into your Claude Code session in this folder. It's a big one, so ask Claude Code to do it in the four parts below and check each part in the Simulator before the next.

---

The spec and designs have grown. Please read these sections of `docs/SPEC.md`: "3b · Your pace for the year", "4 · Home", "Widgets", "Apple Watch app" and the data model. Also read these files in `design/`: `WeeklyTarget`, `HomeWeek`, `Home`, `Main`, `StartYear`, `YearlyHours`, `Widgets` and `Watch` (`.dc.html`). Work in four parts. At the end of each part, build, run the tests, tell me how to see it in the Simulator, and wait for my OK before starting the next.

**Part 1 · Your pace for the year**
- **Data:** add `weeklyTargetHours`, `targetSetAt`, `targetEndsAt` and `lastHomeTab` to Settings, and a `TargetPeriod` history (hours, start, end). Past weeks are judged against the target that applied then.
- **Onboarding:** add the new screen as step 4 of 4 (update the step dots on steps 1–3). "Hours per week, each year" now says **Continue**. The new screen's **Start playing** saves everything and opens Home on This week.
- **Screen:**
  - The title and text from the spec.
  - A big number with a slider (1–40, step 0.5), defaulting to the recent pace, with "Your recent pace: N" under the slider.
  - The Until / About / In a year card.
  - When opened from Home to edit, the button says **Save** and the 12 months restart from today.
- **End of the year:** 14 days before the end, show the reminder in the target row. After the end date, open "A new year of pace" as a sheet once, with the old value pre-filled.
- **Forecast:** use the target for the next 12 months only when the user is within 25% of it (spec).
- **Tests:** the 12-month window, the TargetPeriod history, the end-of-year reminder and sheet, and the forecast rule.

**Part 2 · Home with two tabs and the sun gauge**
- **Tabs:** a segmented control "This week | The long game" under the header. Remember the last tab.
- **Sun gauge:**
  - A vertical scale on the left (line, ticks, labels) and a navy pill at the sun's height, joined to the sun by a dashed gold line.
  - The sun's centre height maps linearly from the horizon (0) to the top tick (100%). Above 100% it stays at the top with the celebrate face.
  - This week: 0 → target, ticks at 0, half and target. The long game: 0 → 10,000, ticks every 2,500.
  - When switching tabs, the sun glides (0.6 s) and the labels cross-fade.
- **This week:** "6.5 h", "of 12 h this week · 54%", the 7 day bars (tap a bar to open that day in History), and the target row ("5.5 h to go · 3 days left" or "Target reached · +1.5 h", plus "Your pace for the year…"), which opens the target screen.
- **The long game:** the total, "of 10,000 hours · N%", the stats Pace / By Nov 2027 / Finish line, and the Meet your future self row.
- Remove the Recent rows from Home.
- Keep everything from the existing hero:
  - the opaque sea that always covers the lower part of the sun (sun masked above the wave path);
  - the animation (waves, glints, breathing, slowly turning rays, eye peek);
  - Reduce Motion.
- Check in previews that the sea covers the sun at every height.

**Part 3 · Widgets** (WidgetKit, shared App Group)
- **Small:** the sun-over-the-sea scene at the right height (no animation), with "6.5 h / of 12 h this week". Use an App Intent configuration to choose This week or The long game.
- **Medium:** the this-week scene plus two bars (gold this week, navy long game) and "Today 1 h 30 m".
- **Lock Screen:** circular (ring with sun), rectangular and inline, as in the spec table.
- Deep link into Home on the matching tab. Reload timelines when a session is saved, at midnight and at the start of each week.

**Part 4 · Apple Watch app**
- **Watch app target:**
  - two swipeable pages (This week with **Start**, The long game), each with the sun, a small scale and the big number;
  - the timer (focus sun with lit rays, clock, total and next ray, Pause/Resume, Finish, a haptic when a ray lights);
  - the Finished screen.
- **Complications:** circular, rectangular, and corner/inline (WidgetKit for watchOS).
- **Sync:**
  - One session at a time across phone and watch: WatchConnectivity for the live session, the shared store for saved sessions.
  - A session started on the watch shows on the phone and in its Live Activity, and vice versa.
  - If the phone is out of reach, the watch keeps the session and sends it later.
- If the phone app isn't set up yet, the watch shows "Set up Long Game on your iPhone first."
- Ask me before adding the watch target, in case my Apple Developer account needs anything.

All new text goes in the String Catalog, and everything supports VoiceOver, Dynamic Type and Reduce Motion. When all four parts are done, update `docs/AUDIT.md`.
