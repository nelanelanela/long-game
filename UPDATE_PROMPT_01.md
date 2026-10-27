# Update prompt 01 for Claude Code

Paste everything below the line into your Claude Code session in this folder.

---

The design and spec have been updated. Please re-read `docs/SPEC.md` and the changed files in `design/`, then apply these changes to the app. If a part isn't built yet, build it this way when you get to it instead.

**1. Timer: show the overall total** (`design/Timer.dc.html`, spec "Timer")
- Under the sun, add the overall total in large gold numbers with one decimal (e.g. "3,294.7"), with "of 10,000 hours · N%" below it. It counts up live while the session runs.
- Then a short divider, a small "This session" label, the session clock, and the caption "Next ray in m:ss · golden hour bonus in mm:ss".

**2. New feature: Welcome back catch-up** (`design/CatchUpAsk.dc.html`, `CatchUpWeeks.dc.html`, `CatchUpAverage.dc.html`, spec "9 · Welcome back")
- On launch or return to foreground (after onboarding, no timer running), if the gap since the last day with a session is 7+ days, show the Welcome back sheet. Gap = day after the last session day (or the onboarding date) up to yesterday.
- Ask at most once every 7 days: add `lastCatchUpPromptAt` to Settings. Adding hours, "No, I took a break", or dismissing all count as asked.
- Gap of 7–27 days: one slider per week. Split the gap into 7-day blocks counting back from yesterday; leftover days join the oldest block. Each row shows the date range, a 0–40 h slider (default = current pace, rounded) and "N days · about H h MM m a day".
- Gap of 28+ days: one average-hours-per-week slider (0–40), showing the period, hours per day in the calendar, and the total (= average × gap days ÷ 7).
- Store the hours as one Session per day across the gap, with the new source `catchUp`, start = 12:00 that day. The duration is the block's hours split evenly, rounded to the minute, with the rounding remainder on the last day so totals match exactly.
- These days show in the normal calendar colours; the day detail says "Added after a break"; they can be edited and deleted. They count towards total, pace, forecast and streaks.
- Add `catchUp` to the Session source enum, and unit tests for the gap, the week blocks, the even split and the once-a-week rule.

**3. Copy: the game voice** (spec "Principles · Game voice")
Long Game is "the longest game on the App Store — about 10,000 hours long, and played in real life". Update these strings:

| Screen | Old | New |
| --- | --- | --- |
| Welcome subtitle | Mastery takes about 10,000 hours… | The longest game on the App Store. About 10,000 hours long, and played in real life. |
| Your craft title | What is your craft? | What's your game? |
| Your craft subtitle | Pick one, or type your own. | Your craft is the game. Pick one, or type your own. |
| Start year subtitle | A rough guess is fine. | You don't start at level one. A rough guess is fine. |
| Hours per year subtitle | More or less. Only focused practice. | This is your starting score. Only focused practice counts. |
| Hours per year button | Start tracking | Start playing |
| Home stat label | Mastery | Finish line |
| Growth headline label | Mastery forecast | You'll finish the game around |
| Timer caption | golden hour in | golden hour bonus in |
| One craft sheet title | One craft at a time | One player, one game |
| One craft sheet text | Splitting your hours… keeps you focused on one. | No switching games. Splitting your hours across several crafts slows every one of them down, so Long Game keeps you playing just one. |
| One craft buttons | Keep my focus / Replace my craft | Keep playing / Switch to a new game |
| Welcome back question | Did you practise since then? | Did you keep playing since then? |

Use the same light game voice for any new text (no lives, coins or leaderboards). Put all user-facing strings in a String Catalog if you haven't already.

**4. Labels with numbers**
Build labels that combine a number and words as one formatted string (e.g. "Add 24 hours", "24 h", "12 days", "+2 h/wk"), with proper pluralisation ("1 hour" / "24 hours").

When you're done: build, run the tests, tell me what changed, and how to see the Welcome back flow in the Simulator. Add a debug-only setting that pretends the last session was N days ago so I can test it.
