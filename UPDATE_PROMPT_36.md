# Update prompt 36 for Claude Code: the year card's calendar follows the legend

Paste everything below the line into your Claude Code session in this folder.

---

The History calendar draws each day with the legend's shapes (rest = a small dot, then a circle, softer and sharper squares). The year card's strip (`YearStrip` in `LongGame/Features/Year/YearCardView.swift`) doesn't: every day is the same rounded square, rest days included. Please make it match. Stay on the `redesign` branch, and read `design/redesign/YearCard.dc.html` first.

- In `YearStrip`'s `Canvas`, draw each day with `CalendarLevelShape(level:)` in its cell (`path(in: rect)`), instead of the rounded rectangle. Keep the pitch and the cell size (`pitch × 0.86`) as they are.
- Rest days become the small dot, like the History calendar: `#C5D0EC` on Sunrise and `#3D4D93` on Evening (replacing #DCE3F3 and #2A3566).
- The level colours stay `LGColor.calendar(level)`.
- Future days and days outside the year stay empty.
- The year card image is rendered at 1080 px wide, where each cell is about 15 px, so the shapes are clear in the shared image. Check the rendered PNG for both looks.
- Update the previews and `docs/SPEC.md` (17 · Your year): "The year's calendar as a strip of 53 weeks × 7 days, with the calendar's shapes and colours (rest is a small dot)".

This needs nothing from my Apple Developer account.

When you're done:
- build and run all the tests;
- update `docs/AUDIT.md`;
- tell me how to see the Sunrise and Evening cards in the Simulator.
