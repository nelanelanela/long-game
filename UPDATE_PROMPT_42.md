# Update prompt 42 for Claude Code: design polish — Data & storage, milestone card, first week, words and sizes

Paste everything below the line into your Claude Code session in this folder.

---

A round of design improvements. Please read these boards in `design/redesign/`:
- `Settings`, `DataStorage` and `SavedPhotos`;
- `Milestone` and `MilestoneCard`;
- `CalendarEarly` and `GrowthEarly`;
- `WeeklyPace`, `Calendar` and `YearCard`.

The Home boards (Today, This week, the empty day, The long game) were also redrawn with the transparent glass top bar from prompt 34. They need no change in the app, but check yours still matches them.

Stay on the `redesign` branch, and build and test after each part.

## 1 · A shorter Settings, with a Data & storage screen
- **Settings keeps, in order:**
  - Support Long Game;
  - Notifications;
  - While you play: Focus, Widgets and **Giggle sound**. The Sounds group goes, and its one switch moves here.
  - **Your data**: one row, **Data & storage**, with a cloud icon on a light blue tile, the subtitle "iCloud on · photos 486 MB · export" (live values; "iCloud off" when off) and a chevron.
  - Your game;
  - the footer.

  The page should fit on one iPhone screen at the default text size.
- **Data & storage** (new pushed screen, back to Settings):
  - **iCloud:**
    - the Save to iCloud switch with its status line;
    - **Delete iCloud copy** in red (with its confirmation, as now);
    - under the card: "Private to your Apple Account. Deleting the iCloud copy keeps everything on this iPhone."
  - **Storage:**
    - **Your photos**: "214 photos · 486 MB", opening the Your photos screen;
    - **Default pictures**: "3.1 MB cache · never your photos", with Clear.
  - **Your data:**
    - **Export sessions**: "A CSV file with dates, times and notes. Photos aren't included." Tapping it shares the CSV with the share sheet.
    - **Delete all data** in red (with its confirmation, as now);
    - under the card: "Deletes your game, sessions, notes and photos from this iPhone and iCloud. This can't be undone."
- Your photos' back button returns to Data & storage. Mac and iPad Settings get the same structure.

## 2 · A milestone card to share
- On the milestone celebration (100, 500, 1,000, 2,500, 5,000, 7,500 and 10,000 h), add a secondary button above Keep playing: **Share this moment**, with a share icon. It's translucent white, 50 pt high, with a thin navy outline.
- It renders `MilestoneCard` as a 9:16 image (1080 × 1920, from a 360-pt layout × 3, like the year card) and opens the share sheet:
  - the dawn sky with the moon to the right, the still sea, and the sun with the celebrate face;
  - "A MILESTONE IN THE LONG GAME" (gold #FFE08A, letter-spaced) and the craft name;
  - the big number ("1,000 h"), then the milestone line ("A thousand hours.");
  - "Reached on 5 November 2026 · started in 2019" (the onboarding start year);
  - the year card's footer.
- The card has no sun animation and no water sway. Reuse the year card's rendering and share code.
- VoiceOver: "A thousand hours of piano. Reached on 5 November 2026."

## 3 · The first week
- **Calendar**, before the first full week:
  - Rhythm shows "–" (already the case);
  - days before the game began are pale dots (#EFEBE4) instead of rest dots, so they don't read as missed days;
  - under the calendar card: "Your calendar fills in as you play. Rhythm appears after your first full week."
- **Growth**, before two weeks of sessions:
  - no actual-pace line and no "Your actual pace" key row;
  - the line under the headline reads "Your actual pace shows after two weeks of playing."
  - The chosen-pace forecast shows as normal.
- Where the **Your 2026** row is hidden (fewer than 4 weeks), show instead: "Your year card appears after four weeks of playing."
- Use the existing rules in `Logic/` for when each appears. Add the two thresholds there if they aren't already, with tests.

## 4 · Words
- Your weekly pace: "Each day, a stretch from the sea to the moon." becomes **"Your pace, split into a stretch for each day."** (`WeeklyTargetView`).

## 5 · Small text
Raise the smallest text where there's room:
- the calendar's month labels from 11 to 12 pt;
- the weekday letters from 9 to 10 pt;
- the legend lines from 11 to 12 pt, letting the legend wrap onto two lines at large sizes;
- the year card strip's month labels (`YearCardView`, now 9 pt) to 11 pt.

Check the shared year card image at both looks.

This needs nothing from my Apple Developer account.

When you're done:
- build and run all the tests;
- update `docs/SPEC.md` (Settings, milestones, History, onboarding words) and `docs/AUDIT.md`;
- tell me how to see each new screen in the Simulator:
  - Data & storage;
  - a milestone with Share;
  - History on a brand-new game.
