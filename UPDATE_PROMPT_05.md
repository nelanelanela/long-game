# Update prompt 05 for Claude Code

Paste everything below the line into your Claude Code session in this folder.

---

Onboarding now explains the game before setup. Please read `docs/SPEC.md` section "0a–0c · How the game works" and the new files `design/Intro1.dc.html`, `Intro2.dc.html` and `Intro3.dc.html` (also `Welcome.dc.html`, whose Get started now leads to them). Then:

- **Pages:** add three swipeable intro pages between Welcome and "What's your game?". Use the titles, text, illustrations and buttons from the spec table.
- **Controls:** each page has a back chevron, **Skip** (goes straight to "What's your game?"), page dots and one primary button. The last page's button is "Choose your game".
- **Illustrations:**
  - Reuse the Home hero pieces: the breathing sun, slowly turning rays and the animated opaque sea.
  - The sea must fully cover the lower part of the sun, as on Home.
  - Page 0a has the dashed gold "Finish line · 10,000 hours" line.
  - Page 0b has the white chip "Your starting score · 3,208 h". Show the real estimate once known; until then use the example number.
  - Page 0c has the sun with 8 of 12 rays lit and the navy chip "+1 h today".
- **When they show:** only in first onboarding, not after "Switch to a new game".
- **Accessibility:** support Reduce Motion, VoiceOver ("Page 1 of 3") and Dynamic Type; the text must scroll if it gets long.
- Put all text in the String Catalog.

When you're done: build, run the tests, and tell me how to see the intro again in the Simulator. Add a debug option to reset onboarding.
