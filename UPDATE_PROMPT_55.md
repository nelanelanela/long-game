# Update prompt 55 for Claude Code: gentler words on the first-session notification sheet

Paste everything below the line into your Claude Code session in this folder.

---

The sheet that asks for notifications on the first session (update 53, part 6) should sound gentler and plainer. Only the words change; layout, timing and behaviour stay as they are. Please read `design/redesign/TimerNotifyAsk.dc.html` again from disk. Stay on the `redesign` branch.

**New text, top to bottom**

| Where | Before | Now |
| --- | --- | --- |
| Line with the orange dot | Your first session is running | (unchanged) |
| Title | Lost in your work? | **Can we check in?** |
| Under the title | It happens to everyone: you get absorbed in what you're making and forget to stop the timer. | Sometimes the timer keeps running after you've stopped. We can send one quiet note to check. |
| Row 1 title (bell) | We'll tap you on the shoulder | **After 4 hours** |
| Row 1 text | After 4 hours, a quiet "Still practising?", so you can stop it. | A note asks "Still practising?" Tap it to stop the timer, or keep going. |
| Row 2 title (pencil) | You can always fix the time | **Easy to fix later** |
| Row 2 text | Change a session's length when you finish, or later in History. | You can change a session's length when you finish, or any time in History. |
| Small note | Only a few quiet notifications: this check and your milestones. Never ads, never streaks. | We only send this note and your milestones. Nothing else. |
| Buttons | Allow notifications · Not now | (unchanged) |

- The sheet's accessibility label becomes "Can we check in?".
- Use typographic quotes and apostrophes, and keep British spelling ("practising").
- Update the String Catalog entries (remove the old ones), `docs/SPEC.md` (the Notifications paragraph) and the accessibility UI test's expected reading order for this sheet.
- Check the title stays on one line at the default text size and wraps cleanly at the largest sizes.

This needs nothing from my Apple Developer account. Build, run the tests, and commit with a clear message.
