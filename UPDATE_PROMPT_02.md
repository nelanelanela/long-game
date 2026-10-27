# Update prompt 02 for Claude Code

Paste everything below the line into your Claude Code session in this folder.

---

The design and spec have been updated again. Please re-read `docs/SPEC.md` (sections "Quotes", "4 · Home", "5 · History — Calendar", "6 · History — Growth", "13 · About", "Timer", "Notifications" and "Visual system") and the changed files in `design/` (Welcome, Home, Timer, Growth, Calendar, and the new About). Then apply these changes. If a part isn't built yet, build it this way when you get to it.

**1. Quotes**
- Add one list of four quotes with their sources (spec "Quotes"), kept in one place so they're easy to change.
- Bundle Newsreader Italic (Google Fonts, OFL) and add a reusable quote style: serif italic 17–20 pt, ink colour, source line in SF Pro 12 pt. It's the only serif text in the app.
- Welcome: the blacksmith proverb under the subtitle.
- Timer: "Be truly present to your art." fades in under the header when a session starts, stays about 8 s, then fades out. Once per session, not on resume.
- Growth: the grace quote at the bottom of the forecast card, under a divider, at 14 pt.
- New About screen (`design/About.dc.html`), opened from a new info icon in the Home header. It has the "Why there are no leaderboards" card with the bald-man proverb, plus Privacy, Contact us and Rate Long Game rows.

**2. Line of the day on Home**
- A card on the warm paper colour (#F6ECDA) between the stats row and Recent.
- It shows a small "Line of the day" label, one quote and its source.
- It cycles through the four quotes, one per day (day number since onboarding), changing at local midnight.

**3. Rhythm instead of streaks**
- Remove streaks everywhere (the Calendar stats, the "Streak at risk" notification, any streak code).
- Calendar stats become **Rhythm** ("N days/wk", the median number of practice days per week over the last 8 complete weeks plus this week), **Steady for** ("N weeks" in a row with at least Rhythm − 1 practice days) and **Active days**.
- Replace the streak notification with the gentle "Rhythm nudge" from the spec table.
- Catch-up sessions count towards Rhythm like any other session.

**4. Small wins in the Timer**
- Each time the overall total crosses a whole hour (e.g. 3,294.9 → 3,295.0), the sun does a small happy bounce (scale 100 → 114 → 96 → 104 → 100 %, about 0.6 s spring) and a ring of gold sparkles shimmers once around it. Add a light haptic.
- This is separate from the session's golden hour.
- With Reduce Motion: no bounce; the sparkle ring just fades in and out.

Add unit tests for Rhythm and Steady for, including weeks with no practice, a brand-new user with less than a week of data, and catch-up days. Also test the quote-of-the-day rotation.

When you're done: build, run the tests, and tell me what changed and how to see each change in the Simulator. Add a debug-only setting to jump the overall total to just under a whole hour, so I can see the bounce.
