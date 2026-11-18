# Update prompt 48 for Claude Code: Then and now, and The sun remembers

Paste everything below the line into your Claude Code session in this folder.

---

Two features that show people their own story. Both are made only from sessions and photos already saved. Please read `design/redesign/ThenAndNow.dc.html` and `design/redesign/SunRemembers.dc.html`. Work on the branch that will ship after the release (ask me which if it isn't clear), and build and test after each part. Every button uses the app's standard styles (primary 56 pt, text buttons 44 pt).

## 1 · Then and now

An early photo next to a recent one, so progress can be seen.

**When it exists**
- The person has at least two session photos taken 90 days or more apart.
- **Then** is the earliest photo. **Now** is the most recent one. Pure function in `Logic/` (`ThenAndNow.pair(photos:)`), with tests:
  - fewer than two photos;
  - less than 90 days apart;
  - photos deleted;
  - a chosen pair that is still valid, or no longer valid.

**Where it's reached**
- A row at the bottom of History › Growth, above "Your 2026": a small sun, **Then and now**, "Your first photo next to your latest". It's hidden when no pair exists.
- A secondary button on the milestone celebration, **See then and now**, shown only when a pair exists. It sits above Share this moment.

**The screen** (pushed, back chevron, title "Then and now")
- A small sun with open eyes, **Look how far.**, and "984 hours of piano between these two." That's the difference between the overall totals at the two sessions, with the craft's name in lower case.
- Two white photo cards, one above the other, tilted very slightly (−1.5° and +1.2°; the tilt is still, so Reduce Motion doesn't change it):
  - the photo (aspect fill, radius 10) with a small dark pill in its corner: **Then** / **Now**;
  - the date ("12 March 2024") and "at 2,310 h" (the overall total at the end of that session);
  - the session's note on one line, or nothing when there's no note.
- Between the cards, a navy pill with gold text: "2 years 8 months later" (years and months; under a year, months; under two months, weeks).
- **Share** (primary): renders a 9:16 image (1080 × 1920, like the year card) with the peach-to-background wash, "THEN AND NOW · PIANO", both photos with their dates and hours, the "… later" pill, "984 hours between these two", and the year card's footer. Notes are not on the shared image. Reuse the year card's rendering and share code.
- **Choose other photos** (text button): opens a picker of the person's session photos (a grid by year, newest last) to pick Then, then Now. Now must be later than Then. The choice is remembered (store the two session ids) until one of them is deleted; then it falls back to earliest and latest.
- Tapping a photo opens it in the photo viewer.

**Accessibility**
- Each card is one element: "Then. 12 March 2024, at 2,310 hours. First try at the nocturne. Photo."
- The pill is read as "2 years 8 months later".
- Dynamic Type: at the accessibility sizes the screen scrolls.

## 2 · The sun remembers

Small, rare lines that show the app knows the person's history.

**The memories** (pure function in `Logic/`, `Memories.today(...)`, returning at most one)

| Memory | Text | Condition |
| --- | --- | --- |
| A year ago today | Before today's first session: "A year ago today, you played 20 m." After it: "A year ago today, you played 20 m. Today, 1 h 05." | A session on this calendar date in an earlier year (most recent such year; "Two years ago today" and so on). The "Today" part is only added when today's time is equal or more. |
| Your day of the week | "Thursdays are your day. 31 of them so far." | Today is the weekday with the most days played, with at least 10 of them, and a clear lead (at least 2 more than the next weekday). |
| A photo's anniversary | "Two years ago today, you took this photo." | A session photo taken on this date in an earlier year. Shows its thumbnail. |
| The same month, a year on | "Last November: 18 h. This November so far: 22 h." | From the 10th of the month, only when this year's month is already ahead of the whole of last year's. |
| Your first day | "Three years ago today, you played your first session here." | The anniversary of the first session logged in the app. |

- Order of preference when several apply: first day, photo's anniversary, a year ago today, the same month, your day of the week.
- **How often:** at most one memory in any 7 days (store the date the last one was shown). Never on a day that has a small anniversary pill or a milestone, and never on an empty first month.
- **Never a comparison that stings:** a memory with numbers is shown only when today's side is equal or better. Otherwise that memory isn't eligible.

**On Home**
- One card under Today's number and quiet line: peach #FFF1DA, radius 14, the text with its opening words in ember bold, an optional 40 pt photo thumbnail on the left, and a small chevron.
- The sun winks once on the first open that day.
- A tap opens that day in History (or the photo in the viewer). The card is there for the whole day and gone the next.
- No notification, sound or haptic.

**Settings**
- In the group with Giggle sound, a switch **The sun remembers**, on by default, with the subtitle "Now and then, a memory from your own history".

**Tests**
- Each memory's condition, including 29 February and time zones around midnight.
- The order of preference.
- The 7-day rule, and the rule against anniversaries and milestones on the same day.
- Nothing shown when today's side is lower.

## Text and docs
- All new text goes in the String Catalog, with British spelling. Dates, durations and month names are formatted for the person's locale.
- Update `docs/SPEC.md` (History, milestones, Home, Settings) and `docs/AUDIT.md`.

This needs nothing from my Apple Developer account.

When you're done:
- build and run all the tests;
- tell me how to see both in the Simulator. Add debug options to fill sample photos two years apart and to force each memory.
