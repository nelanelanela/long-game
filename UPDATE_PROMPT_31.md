# Update prompt 31 for Claude Code: remove the + button from the top bar

Paste everything below the line into your Claude Code session in this folder.

---

We're removing the **+** ("Add a craft") button from Home's top bar. Please read these parts of `docs/SPEC.md`:
- the Header line in "4 · Home";
- "8 · One craft at a time — sheet";
- the Settings paragraph in "Accounts, sync and notifications".

Then make these changes.

**1. Home's top bar**
- Remove the `plus` / "Add a craft" button everywhere it appears in `Features/Home/HomeView.swift`: the phone header, the tall iPad page, the iPhone Duo layouts and anywhere else.
- The phone header keeps two buttons: History (calendar) and Settings (gear).
- The tall iPad page currently has only History and +. Give it the Settings gear in place of the +, so Settings can be reached there too.
- Keep the sizes, spacing and 44 pt touch targets the same as now.

**2. Keep the One craft sheet reachable**
- In Settings, add a row **Switch to a new game** to the practice card, under Archived crafts.
- The row opens the existing `OneCraftSheet`, which keeps its current behaviour: Keep playing, and Switch to a new game with the confirmation.
- In the Mac and iPad sidebar layouts, the same row appears in their Settings view.
- Remove any keyboard shortcut or menu item that only existed for the + button.

**3. Clean up**
- Remove the "Add a craft" string from the String Catalog if nothing else uses it. Add "Switch to a new game" if it isn't there, with British spelling.
- VoiceOver: the row reads "Switch to a new game, button".
- Update any UI tests or previews that tapped the + button.

This needs nothing from my Apple Developer account.

When you're done:
- build and run all the tests;
- update `docs/AUDIT.md`;
- tell me where to find Switch to a new game in the Simulator.
