# First prompt for Claude Code

Paste everything below the line into Claude Code, started in this folder.

---

We're building Long Game, the iPhone app described in `docs/SPEC.md`, with the screen designs in `design/`. Read `CLAUDE.md`, then the spec, then skim each design file.

Before writing code, give me a short plan in plain language: the folder structure, the data model, and anything in the spec you think is unclear or risky. Then wait for my OK.

After I approve, build it in these phases. At the end of each phase, build and run the tests, tell me how to try it in the Simulator, and wait for me before starting the next one:

1. **Foundation** — git repo, XcodeGen project (ask before installing XcodeGen), SwiftData models, the `Logic/` calculations (baseline, totals, pace, this week, streaks, calendar levels, forecast) with unit tests, and the design system: colours, type, cards, buttons and the SunView with all five face states.
2. **Onboarding** — Welcome (sunrise sky), Your craft (search + grouped suggestions), When did you start, Hours per week each year. Saves the craft and estimates.
3. **Home and Add past hours** — sunrise card with the sun over the sea, stats, recent sessions, edit/delete a session, the One craft at a time sheet with Replace my craft.
4. **Timer** — timestamp-based timer, pause/resume/finish sheet, the full "sun's hour" animation from the spec (breathing, rays lighting every 5 minutes, wink, motes, warming sky, golden hour, sleepy pause, finish celebration), haptics, Reduce Motion version, then the Live Activity.
5. **History** — Calendar grid (blue rest days, yellow→orange levels, day detail, streaks) and Growth (cumulative chart with forecast band, weekly rate bars, What-if slider).
6. **Polish** — Settings (week start, reminders, edit estimates, archived crafts, export CSV, delete data), notifications and milestone celebrations, accessibility pass, app icon from the sun drawing. CloudKit sync and Sign in with Apple last, after asking me about my Apple Developer account.

Keep the look simple and calm, exactly like the designs.
