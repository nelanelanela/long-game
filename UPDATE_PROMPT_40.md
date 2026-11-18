# Update prompt 40 for Claude Code: no daily reminder from onboarding

Paste everything below the line into your Claude Code session in this folder.

---

The daily reminder is only turned on by the person, in Settings. The onboarding step "A gentle nudge" (`NotificationsStepView`) should no longer mention it or switch it on. Please read the updated `design/redesign/Notifications.dc.html`. Stay on the `redesign` branch.

**1. The screen**
- Remove the **A daily reminder** row ("At 7 pm, when the sun is waiting…") and the divider above Milestones. The card keeps two rows: **Milestones** and **A long-session check**.
- Everything else stays the same, including "Your session on the Lock Screen shows either way. Change your mind any time in Settings."

**2. The behaviour**
- **Allow notifications** only asks iOS for permission. It no longer sets a reminder time.
- Remove `reminderTime` from the onboarding model, the code that saves it into Settings at the end of onboarding, and `NotificationAsk.reminderTime(granted:)` (or whatever only exists for this).
- The daily reminder starts off for everyone. Settings is the only place to turn it on and choose its time and days. If permission was never asked, turning it on there asks; if it was denied, Settings shows the "Notifications are off for Long Game in iPhone Settings" row from prompt 38.

**3. Text and tests**
- Remove the strings that are no longer used from the String Catalog.
- Update the tests: allowing notifications in onboarding leaves the reminder off; turning the reminder on in Settings still works.
- `docs/SPEC.md`: the notifications step lists milestones and the long-session check only; the daily reminder is off until turned on in Settings.

This needs nothing from my Apple Developer account.

When you're done:
- build and run all the tests;
- update `docs/AUDIT.md`;
- tell me how to check in the Simulator that onboarding leaves the reminder off.
