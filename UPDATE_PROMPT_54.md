# Update prompt 54 for Claude Code: What's your game? shows every choice while typing

Paste everything below the line into your Claude Code session in this folder.

---

On **What's your game?**, typing now hides the other choices: the list filters down to the matches, or to only the typed name. I want the typed name and all the other choices visible at the same time. Please read `design/redesign/Craft.dc.html` again from disk (its script comments describe the behaviour). Stay on the `redesign` branch; it's part of the 1 December release.

**What changes**
- **The list is never filtered.** All the groups and all their choices (Music, Visual arts & making, Performing arts, Words & mind, Professions) are always shown, whatever is typed.
- **While 2 or more characters are typed** and they don't exactly match a choice, the top of the list shows:
  - the small label **Your own**;
  - one chip with the typed text and a "+" in front, already selected (navy);
  - under it, the line "Not on the list? It's your game, call it anything." (13 pt, #5E6782). It now shows whenever the own chip shows, not only when nothing matches.
  - Then all the groups follow, unchanged.
- **When the typed text exactly matches a choice** (ignoring case), there's no Your own row: that choice is selected in its group, and everything else stays visible.
- **Tapping any choice** selects it instead of the typed text. The text field keeps what was typed, so tapping the own chip again selects it back.
- **Only one thing is selected at a time:** the own chip or one choice.

**Unchanged:** the placeholder, the pencil icon, the field's navy ring and ✕ while it has text, **Play <name>** / **Continue**, Return on the keyboard, and VoiceOver ("Your own: Calligraphy, selected").

**Scrolling:** the list scrolls under the field with the soft fade at the bottom, as now. When the own chip appears, don't scroll away from it: keep the top of the list in view.

**Tests**
- Update the craft-list tests from update 53:
  - the own chip is shown with all choices (count every group's choices);
  - an exact match selects the choice and shows no own chip;
  - the "Not on the list?" line shows exactly when the own chip shows.
- Update the previews: empty, "pa", "Calligraphy" and "piano".

This needs nothing from my Apple Developer account. Build, run the tests, and commit with a clear message.
