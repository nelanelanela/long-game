# Update prompt 53 for Claude Code: a shorter, clearer onboarding

Paste everything below the line into your Claude Code session in this folder.

---

A tester tried the onboarding and found four problems:
- She said she started this year and gave her hours a week. The next screen asked for hours a week again (the pace for the future), and she was confused.
- The craft she wanted wasn't in the list, and it wasn't clear she could type her own.
- The onboarding felt long, and the weather step could come later.
- She only got a picture of what she'd set up at the very end.

This update fixes all four. Stay on the `redesign` branch; it's part of the 1 December release. The design boards were just replaced or added, so read them from disk again rather than relying on an earlier copy:
- `design/redesign/Craft.dc.html`
- `design/redesign/StartYear.dc.html`
- `design/redesign/YearlyHours.dc.html`
- `design/redesign/YearlyHoursThisYear.dc.html` (new)
- `design/redesign/WeeklyPace.dc.html`
- `design/redesign/ICloud.dc.html`
- `design/redesign/SetupScene.dc.html` (new, a shared component)
- `design/redesign/TimerNotifyAsk.dc.html` (new)
- `design/redesign/WeatherInvite.dc.html` (new)

Every board's script has comments describing its behaviour; follow them. Work in the order below, build and test after each part, and commit in small steps.

## 1 · Setup becomes 5 steps
- The steps are now: **What's your game?** → **When did you start?** → **Before today** → **From today on** → **Keep your game safe**. The step dots show 5 on every step.
- Remove **A gentle nudge** (notifications) and **The weather outside** from onboarding. Their content moves to parts 6 and 7 below. Don't delete the views if part 6 or 7 can reuse them.
- On **Keep your game safe**, the button is now **Start playing**. It saves everything and opens Home on The long game, as the last step did before.
- Nothing in onboarding asks for any permission any more: no notification prompt, no location prompt.

## 2 · What's your game? (`Craft.dc.html`)
- Placeholder: "Type any craft, or pick one below". The field icon is a pencil, not a magnifier, because typing is a real way to answer, not only a search.
- As soon as 2 or more characters are typed, the first row of the list is a small label **Your own** with one chip holding the typed text (with a "+" in front), **already selected** (navy). If the text exactly matches a suggestion (ignoring case), that suggestion is selected instead and there's no Your own row.
- Matching suggestions still show under their group labels; tapping one selects it instead of the typed text.
- No matches: only the Your own row, plus the line "Not on the list? It's your game, call it anything." (14 pt, #5E6782).
- The field gets a 1.5 pt navy ring and a clear (✕) button while it has text.
- The button reads **Play <name>** once a name of 2–40 characters exists ("Play Calligraphy"), otherwise **Continue**, disabled. Return on the keyboard does the same as the button.
- VoiceOver: the own chip reads "Your own: Calligraphy, selected".

## 3 · Before today (`YearlyHours.dc.html`, `YearlyHoursThisYear.dc.html`)
**A time strip on steps 3 and 4.** Under the setup scene (part 5), a thin strip: "Before today" · a bar · a navy dot labelled "Today" · a bar · "Next 12 months". The part the screen is about is lit: a gold bar and a bold #B4561A label. The other part is grey (#E4DFD6, or dashed on step 3), with a #5E6782 label. VoiceOver reads it once as "This screen is about the time before today" / "…the next 12 months".

**Step 3, several years**
- Title **Before today**, line "Roughly, hours a week in each year."
- Same yearly stepper rows as now. The current year's row gets a second line, "So far this year" (12 pt, #5E6782).
- "Use N h for the years after YYYY" stays.
- The separate "Your starting score" row is removed: the score is now a chip in the setup scene, updating live.

**Step 3, started this year** (start year = current year; new screen)
- Title **Before today**, line "You started this year. About how many hours have you played so far, in total?"
- One big stepper in **hours** (not hours a week): "40" with "hours so far" under it. 0–5,000 h, step 5 on tap, hold to repeat as the other steppers do, tap the number to type it. Default 20.
- Under it: "A rough guess is fine. Only focused practice counts." and a white pill button **I'm just starting · 0 h**, which sets 0.
- **Data:** add an optional `totalHours: Double?` to `YearEstimate`. For the current year, when it's set, that year's baseline is `totalHours` instead of hoursPerWeek × weeks elapsed. Store hoursPerWeek too, as `totalHours ÷ weeks elapsed since 1 January`, rounded to 0.5 h (minimum 0), so pace blending and Your estimates in Settings keep working. If the user later edits that year in Your estimates as hours a week, clear `totalHours`. Add a lightweight migration (the field is optional, so existing stores open unchanged) and a test.
- Going back to step 2 and choosing an earlier year shows the several-years version, with the current year's row prefilled from the total.

## 4 · From today on (`WeeklyPace.dc.html`)
- Onboarding title **From today on**, line "How many hours a week do you want to play for the next 12 months?". The time strip lights "Next 12 months".
- Under it, a small white card that links back to step 3. One dot, then a bold first part and a muted second part:
  - several years entered: "**Last year: N h a week.** Keep that pace, or change it." (the year before the current one);
  - only the current year has hours a week: "**This year so far: N h a week.** Keep that pace, or change it.";
  - started this year with a total: "**So far: N h.** Now choose a pace for each week.";
  - started from 0: "**Starting from zero.** Pick a pace you can keep."
- Default pace: the latest year's hours a week, as now. For the started-this-year screen, default 5 h.
- Under the stepper, two centred lines: "About 1 h 43 m a day · until Nov 2027" and, in #B4561A semibold, "At this pace, you reach 10,000 h around December 2037". Use the chosen-pace line of the forecast algorithm, and update live with the stepper. Beyond 30 years: "At this pace, you reach 10,000 h after 2056". Over 10,000 already: "You're already past 10,000 h".
- Remove the daily-stretch picture (the arc and its caption) from this screen.
- When opened from the This week tab to change the pace, keep the old title "Your pace for the year" and **Save**, with no setup scene and no time strip. The link card and the finish line still show.

## 5 · The setup scene (`SetupScene.dc.html`)
A small picture of your game that builds up through setup, so people see what they're making before Home.
- **Where:** at the top of steps 2, 3 (both versions) and 4, full width, right under the top bar. One SwiftUI view, `SetupSceneView`, driven by the onboarding state.
- **Picture** (80 pt tall): the day sky and land, a dashed gold line near the top with "Finish line · 10,000 h" (10 pt semibold, #B4561A) at its right end, and the happy sun (48 pt) centred. Its centre moves linearly from the horizon (0 h, lower half hidden by the land) to the finish line (10,000 h). When the starting score changes, the sun springs to its new height (response 0.5, damping 0.7). The land is drawn in front of the sun, with the same water/land rule as Home.
- **Chips** (8 pt under the picture, wrapping, 28 pt high capsules, 12 pt): the craft name · "Since 2019" · "3,100 h" · "12 h a week".
  - Not yet set: a dashed outline (#D9D2C6) with a muted placeholder: "start year", "starting score", "weekly pace".
  - The chip being changed on the current screen: #FFF0C8 with a 1.5 pt #F0B43A ring.
  - Step 4 adds a gold chip **Finish line ~Dec 2037** (gradient #FFD66B → #F0A93A, bold), updating live.
- VoiceOver: one element, "Your game: Calligraphy, since 2019, 3,100 hours so far, 12 hours a week, finish line around December 2037." Update its value without moving focus.
- Reduce Motion: the sun moves without the spring.

## 6 · Notifications: asked on the first session (`TimerNotifyAsk.dc.html`)
- **When:** the first time the user starts a session from the app, right after the timer has started. The timer keeps running underneath; the sheet never pauses or delays it. If the first session was started from the Live Activity, the Watch, a Control or a Shortcut, show it the next time the app is opened while that session is still running. Shown once ever: add `notificationAskShown` to Settings. Don't show it if notification permission has already been decided.
- **The sheet** (bottom sheet over the dimmed timer): a pulsing orange dot and "Your first session is running"; the wink sun (64 pt) next to the title **Lost in your work?**; then "It happens to everyone: you get absorbed in what you're making and forget to stop the timer."
- A card with two rows:
  - bell icon · **We'll tap you on the shoulder** · "After 4 hours, a quiet "Still practising?", so you can stop it."
  - pencil icon · **You can always fix the time** · "Change a session's length when you finish, or later in History."
- Note: "Only a few quiet notifications: this check and your milestones. Never ads, never streaks."
- **Allow notifications** shows the system prompt. If allowed, schedule the 4-hour "Still practising?" notification for the session that's already running. **Not now** or a swipe down closes the sheet. Either way it's never shown again.
- Remove the old rule "asked after the first saved session". Settings keeps its notification switches; turning one on there asks for permission if it hasn't been decided.
- Check the 4-hour notification is cancelled when the session is paused, finished or discarded, and rescheduled on resume (with the remaining time).

## 7 · Weather: asked after a week (`WeatherInvite.dc.html`)
- **When** (all must hold): at least 7 days since onboarding; Weather in the scene is off; the invite was never shown (add `weatherInviteShown` to Settings); and a session has just been saved and Home is back, after any celebration, icon change or other sheet has finished. Never while a timer is running.
- **The sheet:** a small rainy scene with the sleepy sun, **Bring the weather in?**, "You've been playing for a week now. When it rains where you are, it can rain here too. Mist, wind, cloud and snow pass through quietly.", the same two-row card as the old onboarding step (Only in the landscape · Your rough area is enough), and "iPhone will ask for your location next. You'll find it in Settings any time."
- **Show the weather** shows the location prompt and turns the Settings switch on if allowed (same behaviour as the switch, including the refusal line in Settings). **Not now** or a swipe down closes it. Either way it's never shown again.
- The location prompt is still only ever shown from this button or the Settings switch.

## 8 · Tests and checks
- Unit tests:
  - the baseline with `totalHours` set and not set;
  - the link-card text for each of the four cases;
  - the finish-line text (normal, beyond 30 years, already past 10,000);
  - the craft list: own chip shown, exact match selects the suggestion, no-match line;
  - the notification and weather rules (shown once, the 7 days, never during a timer).
- Previews:
  - each onboarding step in light and dark, and at AX5;
  - the craft step empty, with "pa", and with "Calligraphy";
  - step 3 with one, seven and twenty years (check the list scrolls and nothing overlaps the scene).
- Add the new screens to the accessibility UI tests from update 47.
- Update `docs/SPEC.md`:
  - sections 1–3c: five steps, new titles and copy, the setup scene, the started-this-year screen;
  - the Notifications paragraph: asked on the first session;
  - update 49's weather section: the invite after 7 days instead of the onboarding step.
- Update `docs/AUDIT.md`, and check every new string is in the String Catalog with British spelling.

This needs nothing from my Apple Developer account. When you're done, tell me how to see each part in the Simulator: reset onboarding with the debug option, and add debug actions to show the notification sheet and the weather invite straight away.
