# Verify prompt for Claude Code

Paste everything below the line into your Claude Code session in this folder. Use it after the update prompts, to check that the whole app matches the spec and fix whatever doesn't.

---

Please do a full audit of the app against `docs/SPEC.md` and the screens in `design/`. Treat the spec as the source of truth. Where the spec and a design file disagree, follow the spec and tell me.

**How to work**
1. Read the whole spec and every file in `design/` first.
2. Make a checklist in `docs/AUDIT.md` with one line per requirement below. Mark each line ✅ done, 🟡 partly done or ❌ missing, and add the file where it lives.
3. Fix every 🟡 and ❌. Don't ask me first unless a fix needs a product decision; list those at the end instead.
4. Build, run all tests, and update `docs/AUDIT.md` with the final status.

**Checklist**

*Data and maths*
- Four entities: Craft, YearEstimate, Session (source timer / manual / catchUp), Settings. Totals are always derived, never stored.
- Baseline, logged, total, progress (capped at 100%, keeps counting), This week, Pace exactly as in "Derived values".
- Only one active craft at a time; archived crafts are read-only.

*Onboarding*
- Welcome (sunrise gradient, sun, Get started, I already have an account). No quote.
- Your craft: search, five suggestion groups, custom name 2–40 characters.
- When did you start: stepper, default current year − 3, range 1940 to now; the current year skips the next step.
- Hours per week, each year: one slider per year, 0–40, live "Estimated so far", "Start playing" button.

*Home*
- No cards. The sun rises out of an opaque animated sea, sitting higher as the total grows. Nothing of the sun is visible below the waterline at any wave phase (sea in front of the sun, sun masked above the wave path).
- "Meet your future self" row and sheet, shown once after onboarding.
- Total 64 pt with "of 10,000 hours · N%". Stats row between two hairlines: This week, Pace, Finish line.
- Last 2 sessions as plain rows. Start session (primary), Add past hours (text button). Start session becomes "Resume · mm:ss" while a timer runs.
- Header has only History and +. No info icon, no About screen, no "Line of the day".

*History*
- Calendar: 53 weeks, blue rest days, the four yellow-to-orange levels, tap a day to see and edit its sessions.
- Stats: Rhythm ("N days/wk"), Steady for ("N weeks"), Active days. No streaks anywhere in the app, and no icon next to Rhythm.
- Growth: past line, dashed forecast, likely-range band, sun at the finish point, "Finish line · 10,000 h" label. No legend, no weekly-rate card.
- Forecast exactly as in "Forecast algorithm", including the 30-year limit, the blended forecast pace and the "Not within 30 years" text.
- What if I practise more? slider updates the forecast live and isn't saved.

*Timer*
- Timestamp-based. It survives closing the app, has a Live Activity and Dynamic Island with Pause/Resume and Finish, a Finish sheet with editable duration and note, and the 4 h notification and 12 h auto-pause.
- Overall total in gold with one decimal, counting up live. Then "This session" and the clock, and the caption "Next ray in m:ss" only.
- Every row of the animation table: breathing, halo and motes, ray turning, a ray every 5 minutes, wink, sky warming, golden hour, pause and resume, finish.
- Hour bounce: when the overall total crosses a whole hour, the sun bounces and a ring of gold sparkles shimmers once.
- No quote. Reduce Motion is handled as described.

*Other flows*
- Add past hours: day, hours, minutes, note, "Add N hours", no future days, a day can't go over 24 h.
- One craft sheet: "One player, one game", Keep playing, Switch to a new game with confirmation and archiving.
- Welcome back: the 7-day gap rule, asked at most once every 7 days, the slider per week under 4 weeks, one average slider at 4+ weeks, even split per day with the rounding remainder on the last day, "Added after a break" in the day detail.

*Accounts, sync, notifications, settings*
- Works with no account. Sign in with Apple restores and syncs through the CloudKit private database. Export CSV and Delete all data in Settings. YearEstimates are editable in Settings, and archived crafts are listed there.
- Notifications are off by default and asked after the first saved session. The four types are Daily reminder, Rhythm nudge (no streak notification), Long session and Milestone. Milestones are 100, 500, 1,000, 2,500, 5,000, 7,500 and 10,000 h, each celebrated once.

*Look and copy*
- Flat white cards with no shadows (sheets keep their top shadow). Colours and sizes from "Visual system". SF Pro only, with no serif or Newsreader font left in the project.
- Every string is in the String Catalog and uses the game voice from the spec. Labels that combine numbers and words are one formatted string, pluralised correctly ("1 hour" / "24 hours").
- Accessibility: Dynamic Type up to XXXL, VoiceOver labels on every icon button and chart, contrast of at least 4.5:1, and Reduce Motion everywhere.
- Edge cases from the spec: time-zone change during a timer, sessions crossing midnight, editing estimates later, deleting a day's only session, and passing 10,000 h.

*Tests*
- Unit tests for baseline, pace, forecast, Rhythm and Steady for, the catch-up gap, week blocks and even split, the once-a-week rule, the 24 h day limit, and pluralisation. All tests pass.

**When you're done**, tell me:
1. What was missing or wrong, and what you changed.
2. Anything you couldn't do, and any decisions you need from me.
3. How to check the main flows in the Simulator, including the debug settings for the Welcome back flow and the hour bounce.
