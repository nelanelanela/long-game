# Update prompt 13 for Claude Code: your year, a shareable card

Paste everything below the line into your Claude Code session in this folder.

---

We're adding a shareable card of the user's year. Please read these parts of `docs/SPEC.md`:
- the new section **"17 · Your year — a shareable card"**;
- the new last bullet in "6 · History — Growth";
- the new row in "4b · The long game".

Also read `design/YearCard.dc.html`. Then implement the following.

**The spirit:** a calm keepsake, not a competition. Nothing about other people, no rankings, no notifications, no pop-ups. Notes never appear on a card.

**1. Logic** (pure functions in `Logic/`, nothing stored)
- `YearSummary(year)` returns:
  - hours played that year (logged sessions only, without the onboarding estimate);
  - days of practice;
  - Rhythm (the median number of practice days per week over the year's complete weeks);
  - the most played month (on a tie, the later month);
  - the overall total at the end of the year, or now for the current year;
  - the percentage of 10,000;
  - the calendar levels per day;
  - the "since" date if onboarding was during that year;
  - the year's sessions with photos, newest first.
- Which year to show: the current year, except from 1 to 15 January, when it shows the year that just ended.
- Hide the entry rows when the year has fewer than 4 weeks of data.
- **Tests:**
  - the hours and days;
  - Rhythm for the year;
  - most played month, including ties;
  - the 1–15 January rule;
  - an onboarding date during the year;
  - fewer than 4 weeks;
  - the Sunday or Monday week start;
  - a session crossing midnight on 31 December.

**2. Entry points**
- History → Growth: a quiet **Your 2026** row at the bottom, there all year.
- The long game tab: the same row under "Meet your future self", from 1 December to 15 January only.

**3. The "Your year" screen**
- A back chevron and the title. When more than one year has data, the title is a menu to pick the year.
- A segmented control: **Sunrise | Evening | Photos**. Photos only appears when the year has at least 6 sessions with a photo.
- The card preview, scaled to fit the screen.
- A **Show hours** switch, on by default. When it's off, the card shows days and a percentage instead of hours.
- A primary **Share** button.

**4. The cards**
- Build each card as a SwiftUI view laid out at 360 pt wide, with fixed text sizes so it always fits:
  - the Sunrise and Evening stories at 9:16;
  - the Photos card as a square.
- Follow the spec and the design exactly:
  - colours, text, the still happy sun, the year's calendar strip, the three stats and the footer;
  - the sea fully covering the lower part of the sun, with nothing gold on the water.
- The Photos card:
  - uses the 6 most recent photos of the year;
  - lets you long-press a tile in the preview to swap it for another of the year's photos.
- Reuse the existing sun, sea and calendar-colour code rather than copying it.

**5. Sharing**
- Render with `ImageRenderer` at 1080 × 1920 for stories and 1080 × 1080 for the square, using the layout × 3.
- Share a PNG through `ShareLink`, so it goes to Instagram Stories, Messages, Save Image and anywhere else.
- The image always uses the chosen look, whatever the system's light or dark setting.

**6. Accessibility and text**
- The preview is one VoiceOver element with a spoken summary, as in the spec.
- The screen supports Dynamic Type and VoiceOver. The rendered image itself uses fixed sizes.
- All new text goes in the String Catalog, with British spelling. Format numbers and month names for the user's locale.
- Add SwiftUI previews of all three cards, with hours shown and hidden.
- Add a debug option to fill a sample year so I can see the card straight away.

This feature needs nothing from my Apple Developer account. Saving the image to Photos goes through the share sheet, so there's no new permission.

When you're done:
- build and run all the tests;
- update `docs/AUDIT.md`;
- tell me how to open the card in the Simulator and share it.
