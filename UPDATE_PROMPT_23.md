# Update prompt 23 for Claude Code: remove the quick picks from the weekly pace

Paste everything below the line into your Claude Code session in this folder. Everything Claude Code needs is written out here.

---

Please remove the quick-pick chips from the weekly pace screen. The design file `design/WeeklyTarget.dc.html` was just replaced, so read it from disk again rather than relying on an earlier copy.

**What to remove**
- The row of quick-pick chips under the big − / + pace stepper, for example "Recent pace · 12", 5, 8, 15 and 20, or "Recent · 12".
- Remove it in both places this screen appears:
  - **onboarding step 4, "Your weekly pace"**;
  - **"Your pace for the year"**, opened from the target row on the This week tab.
- Also remove any hint line under the stepper, such as "Tap the number to type it · hold − or + to go faster".

**What the screen should look like now, top to bottom**
1. Onboarding only: the back chevron and the step dots (step 4 of 5).
2. The title:
   - onboarding: "Your weekly pace", with one line under it: "For the next 12 months, the only distance to cover.";
   - from This week: "Your pace for the year".
3. The big stepper:
   - a 56 pt round − button, the number (64 pt bold) with "hours a week" under it, and a 56 pt round + button;
   - 1 to 40 hours, in steps of 0.5;
   - it still supports holding to repeat and tapping the number to type it.
4. One quiet line, 14 pt, #5E6782, centred: "About 1 h 43 m a day · until Nov 2027" (the target ÷ 7, and the date 12 months from today).
5. Space, then the button at the bottom: **Continue** in onboarding, **Save** from This week.

**Keep**
- The quick picks on the Catch-up "on average" screen ("Your usual · N", 0, 5, 10). Only the weekly pace loses them.
- The default value: the recent pace rounded, or the latest yearly estimate during onboarding.

**Clean up**
- If the shared `HoursBigStepper` has a chips parameter, make it optional with no chips by default, so only Catch-up passes chips.
- Delete strings that are no longer used ("Recent pace · %@" and the hint) from the String Catalog.
- Update the previews and any UI or snapshot tests that expected the chips.

**When you're done**
- Build and run the tests.
- List the files and lines you changed.
- Tell me how to check both versions:
  - reset onboarding with the debug option and go to step 4;
  - on Home → This week, tap the target row.
