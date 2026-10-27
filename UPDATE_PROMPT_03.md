# Update prompt 03 for Claude Code

Paste everything below the line into your Claude Code session in this folder. It replaces the quote parts of update prompt 02. If you haven't run prompt 02 yet, run this one instead: it includes the parts of 02 that still apply.

---

The design and spec have changed again. Please re-read `docs/SPEC.md` and the changed files in `design/` (Welcome, Home, Calendar, Growth, Timer, and the flat cards on every screen). Then apply these changes.

**1. No quotes in the app**
- Remove all quotes: the Welcome quote, the Timer session-start quote, the Growth quote and the Home "Line of the day" card. Also remove the quote list, the quote text style and the bundled Newsreader font.
- Remove the About screen and the info icon on Home.
- If prompt 02 was never run, simply don't build any of these.

**2. Keep from prompt 02**
- **Rhythm** replaces streaks everywhere: the Calendar stats become Rhythm / Steady for / Active days (spec "5 · History — Calendar"). The streak notification becomes the "Rhythm nudge".
- **Hour bounce** in the Timer: when the overall total crosses a whole hour, the sun does a small bounce and a ring of gold sparkles shimmers once (spec "Timer", animation table).
- Unit tests for Rhythm and Steady for.

**3. Cleaner, flatter look**
- **Cards:** remove every card shadow. Cards are flat white on the warm-white background (sheets keep their soft top shadow).
- **Home** (`design/Home.dc.html`) has no cards at all:
  - The sun rising over two thin wave lines, full width.
  - The total at 64 pt and "of 10,000 hours · N%".
  - The stats row between two hairlines.
  - The last 2 sessions as plain rows, with no heading.
  - One primary **Start session** button, with **Add past hours** as a text button below it.
  - The sun sits higher above the waves as the total grows (spec "4 · Home").
- **Growth:** remove the "Weekly rate by year" card and the chart legend. Label the dashed 10,000 h line "Finish line · 10,000 h" at its left end.
- **Timer:** the caption under the session clock is just "Next ray in m:ss".
- **Calendar:** no sun icon next to the Rhythm label.

When you're done: build, run the tests, and tell me what changed and how to see it in the Simulator.
