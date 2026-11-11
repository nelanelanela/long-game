# Update prompt 41 for Claude Code: remove "Your usual" from Catch up

Paste everything below the line into your Claude Code session in this folder.

---

On the Catch up sheet, the average step ("On average, how many hours a week did you practise?") offers quick picks "Your usual · 9", 0, 5 and 10. Please remove **Your usual**. Stay on the `redesign` branch, and see `design/redesign/CatchUpAverage.dc.html`.

- In `CatchUpSheet.averagePicks` (`LongGame/Features/CatchUp/CatchUpSheet.swift`), keep only 0, 5 and 10.
- The number the stepper starts on stays as it is now (`CatchUp.defaultHours(pace:)`), so nothing else changes about the sheet.
- Remove the "Your usual · %lld" string from the String Catalog if nothing else uses it, and update the comment above `averagePicks`.
- Update any test or preview that expected four quick picks, and `docs/SPEC.md` (section 9, Catch up) if it mentions Your usual.

This needs nothing from my Apple Developer account.

When you're done:
- build and run all the tests;
- update `docs/AUDIT.md`.
