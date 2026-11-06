# Update prompt 17 for Claude Code: accessibility beyond the basics

Paste everything below the line into your Claude Code session in this folder.

---

We want Long Game to be truly inclusive: colour is never the only cue, and the sun is always described in words. Please read these parts of `docs/SPEC.md`:
- the new section **"20 · Accessibility beyond the basics"**;
- the updated colour line in "5 · History — Calendar";
- the Accessibility line in the edge-case section.

Also read `design/Accessibility.dc.html`. Then implement the following.

There's already a `docs/ACCESSIBILITY_REPORT.md` from earlier work. Read it first, build on what's already done, and don't redo or duplicate anything.

**1. Calendar shapes** (for everyone, always on)
- Put the shapes in one `CalendarLevelMark` view in `DesignSystem/`:
  - rest: a small dot;
  - under 1 h: a thin bar;
  - 1–2 h: a taller bar;
  - 2–3 h: a rounded square;
  - 3 h or more: a full circle.
- Use the sizes and colours from the spec table, centred in the cell.
- Use it everywhere calendar levels appear:
  - the History calendar and its legend;
  - the year card's calendar strip, if it exists yet.
- The photo dot sits in the centre. The selected day keeps its navy ring.
- With Increase Contrast, add the 1 pt darker outline to level 1 and the rest dot.

**2. VoiceOver: the sun in words**
- Add a pure function to `Logic/`: `sunPositionWords(fraction:) -> SunPhrase`. It returns the words from the spec ("just rising", "a third", "halfway", "two thirds", "almost there"…), plus "just over" or "just under".
- Use it in one formatted, pluralised String Catalog string per screen:
  - Home: This week, The long game and Today (including the free-day and above-target versions);
  - the Timer;
  - the calendar day;
  - Growth (as in section 19).
- Each sun gauge is one accessibility element:
  - Its label leads with the words, then the numbers.
  - Values update through `accessibilityValue` without moving focus.
  - On This week, the gauge is adjustable: swiping up or down reads each day.
- Timer: when a ray lights and VoiceOver is running, post a low-priority, queued announcement, "Ray 6 lit", that never interrupts speech.
- Calendar days read their level in words: rest day, a little, some, a good day, a full day.

**3. Other non-colour cues**
- Check that the forecast is dashed and that "Played" / "Forecast" appear as text.
- Check that reached and covered states always say so in words.
- Make the travelled part of the stretch arc thicker than the dotted track.
- Fix anything that relies on colour alone, and list what you changed.

**4. Tests**
- `sunPositionWords`:
  - every step and boundary;
  - 0 and exactly 1;
  - above 1;
  - "just over" and "just under";
  - values within 0.01 counting as on the step.
- The spoken strings for each screen, including pluralisation ("1 hour" or "2 hours").
- The calendar level for each hour band, including 0, exactly 1, 2 and 3 hours, and over 24 hours (capped).

**5. Checks**
- Add previews of the calendar in greyscale (`.grayscale(1)`), with Increase Contrast and at AX5 Dynamic Type.
- Run an Accessibility Inspector audit on Home (all three tabs), the Timer, History and the Finish sheet, and fix what it finds.
- Build, run all the tests and update `docs/AUDIT.md`.

When you're done, tell me how to hear and see each part:
- turning on VoiceOver in the Simulator: Settings → Accessibility, or Accessibility Inspector;
- seeing the calendar in greyscale: Settings → Accessibility → Display → Colour Filters.

This needs nothing from my Apple Developer account.
