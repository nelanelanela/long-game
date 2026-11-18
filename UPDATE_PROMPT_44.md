# Update prompt 44 for Claude Code: feeling progress — look-back, anniversaries, last week's bars, a kinder return, haptics

Paste everything below the line into your Claude Code session in this folder.

---

Five quiet additions. Every new button uses the app's standard button styles: primary 56 pt high with radius 16, secondary and text buttons 44 pt. The mock-ups are smaller than real size, so don't copy button heights from them. Please read `design/redesign/FeelingProgress.dc.html` (four of them, with their rules), `design/redesign/WeekLookBack.dc.html` and `design/redesign/Haptics.dc.html`. None of them sends a notification, and none counts a streak. Stay on the `redesign` branch, and build and test after each part.

## 1 · A weekly look-back
Read `design/redesign/WeekLookBack.dc.html` for the full screen.

- **When:** the first time the app becomes active in a new week (week start from Settings), if the week that just ended had at least one session. Once per week: store the last week shown. Never on the very first week, and never while a session is running or another sheet is open (wait for the next open).
- **The sheet, top to bottom:**
  - **A small scene:** the day sky and one happy sun rising over the sea (the sun breathes as usual).
  - "LAST WEEK" and the dates ("2 – 8 November").
  - The week's hours, large ("9 h 30"), with "of your 12 h pace". With no pace set, the hours alone.
  - One comparison line, in ember, **only when the week was up**: "1 h 15 more than the week before." When it was level or down, the line isn't shown at all.
  - **The seven day bars**, the same gold bars as on This week, on a scale where the longest day is the tallest. A rest day is a small pale dot. Only the longest day carries its hours above the bar, in ember, with its letter in bold.
  - Three figures: **Days played** ("6 of 7"), **Longest day** ("Thu · 2 h 10") and **Mostly** (the part of the day with the most hours: Mornings, Afternoons, Evenings or Nights, by the same hours as the session pictures).
  - **A moment:** one card with a picture and words. The picture is the week's most-viewed photo, or else its most recent photo, or else the session picture of the longest session. The first line says when ("A moment from Thursday evening"); the second is that session's note, or its time and length when there's no note. Tapping it opens the photo viewer or the session.
  - **The long game:** "3,294 h · finish line Nov 2035" and a thin bar: navy for the total before the week, a glowing gold tip for what the week added.
  - "This week: 12 h, about 1 h 45 a day."
  - **Start the week** (primary) and **Change my pace** (text button, opens Your weekly pace). A swipe down also closes it.
- **Words:** the same calm sentences whatever the total. Never "only", "missed" or "behind".
- All numbers come from pure functions in `Logic/` (a `WeekLookBack` value), with tests:
  - the week boundaries for Monday and Sunday starts;
  - the longest day and its ties (later day wins);
  - days played;
  - the part of the day and its ties (later part wins);
  - the comparison line shown only when up;
  - which moment is chosen;
  - the once-per-week rule.
- VoiceOver: the bars are one element that reads the seven days; the rest reads top to bottom. The scene is decorative.

## 2 · Small anniversaries
- A one-line pill under Home's number (peach #FFF1DA, ember text), shown for that calendar day only, with the sun's celebrate face on the first open that day.
- **Which:**
  - a month, six months and each full year since the first session logged in the app: "A month since you started.", "Six months since you started.", "A year since you started.", "Two years since you started.";
  - the 10th, 50th, 100th, 250th, 500th and 1,000th session, on the day it's saved: "Your 100th session.";
  - the 100th and 365th day of practice: "100 days of practice."
- One a day at most. Order of priority: an hour milestone (its own celebration, no pill), then years, then session counts, then days of practice, then months.
- No sheet, sound, haptic or notification.
- Pure function in `Logic/` returning today's anniversary, with tests for each kind, the priority order and leap years.

## 3 · This week next to last week
- On This week's day bars (`DayBarsRow`), draw behind each day a faint bar (navy at 8%, 30 pt wide, radius 7) for the same weekday last week, on the same scale as this week's bars.
- Under the bars, a small key: "Last week" and "This week" with their swatches.
- Hide the faint bars and the key in the first week and when last week had no sessions.
- VoiceOver for each day: "Thursday, 1 hour 30. Last Thursday, 2 hours."
- Same on the wide layouts that show the day bars.

## 4 · A kinder return
- The welcome-back sheet (the first step of Catch up, after a gap of two weeks or more) becomes:
  - a small scene: a dawn sky, the sun opening its eyes over the sea;
  - **Welcome back.**
  - "The sun waited for you. Your 3,294 hours are all here." (the real total);
  - **I practised, let me add it** (primary), which goes to Catch up. The sentence with the date of the last session and the length of the gap moves there, to the top of the next step.
  - **I took a break** (text button), which closes the sheet. Home opens on Today with a toast: "Rest is part of the craft."
- The gap rule and everything after the first step stay as they are.

## 5 · Haptics: one language
First, list every haptic the app plays today (iPhone and Watch) and show me the list. Then make them follow this table, through one small `Haptics` helper in `DesignSystem/` so each moment names its meaning, not its pattern:

| Name | Feels like | Means |
| --- | --- | --- |
| softTap | one light impact | a ray lights · a session is saved · time is added · Undo |
| twoTaps | two light impacts, 0.12 s apart | today's stretch is covered (in the timer or by a save) |
| risingThree | three impacts, each a little stronger (light, medium, rigid) over 0.3 s | an hour milestone · the weekly pace is reached · 10,000 hours |
| tick | the system selection feedback | steppers, the Crown, the Growth chart crossing a milestone, switching tabs |
| giggle | as now | the giggle |
| none | nothing | errors, deleting, pausing |

- Never two at once: if a save both covers the stretch and reaches a milestone, play only the strongest (risingThree, then twoTaps, then softTap).
- Only when system haptics are on.
- On the Watch, use the matching `WKHapticType` (click, directionUp twice, success) and play it on the wrist when the iPhone is locked.
- Tests for which pattern each moment chooses, including the "strongest wins" rule.

## Text and docs
- All new text goes in the String Catalogs, with British spelling.
- Update `docs/SPEC.md` (Home, This week, Catch up, a new "Haptics" table) and `docs/AUDIT.md`.

This needs nothing from my Apple Developer account.

When you're done:
- build and run all the tests;
- tell me how to see each one in the Simulator: a debug way to show the look-back, to fake an anniversary, and to open the welcome-back sheet.
