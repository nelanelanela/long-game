# Update prompt 38 for Claude Code: ask for notifications during onboarding

Paste everything below the line into your Claude Code session in this folder.

---

Right now iOS's notification prompt pops up the first time a session starts (`TimerStore.start` calls `Notifications.requestIfNeeded()`). A second "Want a gentle nudge?" alert follows after the first saved session (`askAboutReminders` in `HomeView`). Both interrupt the first session. We're moving the question into onboarding, as a last step that explains every notification first. Please read `design/redesign/Notifications.dc.html` (step 6) and the updated step dots on the other setup steps. Stay on the `redesign` branch.

**1. A new onboarding step: "A gentle nudge" (step 6 of 6)**
- Add `case notifications` to `OnboardingStep`, after `keepSafe`. Update every step indicator to "Step N of 6".
- On Keep your game safe (step 5), **Start playing** becomes **Continue** and goes to the new step. Finishing onboarding (saving everything, opening Home) moves to the new step's buttons.
- The screen, top to bottom:
  - the back chevron and step dots;
  - a small scene: day sky, the sun with the wink face, the land and sea, and a bell in a white bubble beside the sun;
  - **A gentle nudge**;
  - "Long Game can send you a few quiet notifications. Never ads, never streaks.";
  - a white card with three rows, each with a small icon on a peach tile:
    - **A daily reminder**: "At 7 pm, when the sun is waiting. Change the time or days in Settings."
    - **Milestones**: "“1,000 hours of piano. Sunrise is coming.”" (the craft's name, as in the real message)
    - **A long-session check**: "“Still practising?” after 4 hours, so a forgotten timer doesn't count."
  - "Your session on the Lock Screen shows either way. Change your mind any time in Settings.";
  - **Allow notifications** (primary), **Not now** (text button), and "by We Have Sun".
- **Allow notifications:** call `Notifications.requestAuthorization()` (this shows iOS's own prompt). If granted, turn on the daily reminder at 19:00 on every day (as `enableDailyReminder` does today), then finish onboarding. If declined, finish onboarding without the reminder.
- **Not now:** finish onboarding. No iOS prompt.
- Either way, set `notifications.asked` to true.
- If notifications are already authorised or denied (for example after "Switch to a new game"), skip this step.

**2. Remove the old asks**
- `TimerStore.start`: remove the `requestIfNeeded()` call. Starting a session never shows a permission prompt. Keep scheduling the milestone and long-session notifications; iOS ignores them if permission wasn't given.
- `HomeView`: remove the "Want a gentle nudge?" alert after the first saved session, and `askAboutReminders`.
- Settings keeps its notification switches. If permission was never asked and the user turns one on there, ask then. If it was denied, show "Notifications are off for Long Game in iPhone Settings" with a button that opens the app's page in Settings.

**3. Accessibility and text**
- The three rows are read as one element each ("A daily reminder. At 7 pm…").
- The bell bubble is decorative.
- All new text goes in the String Catalog, with British spelling.

**4. Checks**
- Tests:
  - the step order;
  - the step is skipped when permission is already decided;
  - Allow sets the 19:00 reminder only when granted;
  - starting a session never asks.
- A preview of the new step at the smallest and largest Dynamic Type.

This needs nothing from my Apple Developer account.

When you're done:
- build and run all the tests;
- update `docs/SPEC.md` (onboarding, and "Notifications": now asked during onboarding) and `docs/AUDIT.md`;
- tell me how to see the new step again in the Simulator. Reset the onboarding, and reset notification permission by deleting the app.
