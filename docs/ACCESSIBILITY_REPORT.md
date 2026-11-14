# Accessibility report — Long Game

**Date: 14 November 2026.** Branch `accessibility-check` (made from `dark-mode`, so both the day and the night look
were checked). Update prompt 47. This replaces the report of 5 November, whose items 2–9 were done in update 17.

## What ran

| Check | How | Time |
|---|---|---|
| Apple's accessibility audit, every screen | `LongGameUITests/AccessibilityAuditTests.swift` calls `performAccessibilityAudit()` on 36 screens (onboarding, Home's three tabs and states, Timer, Finish sheet, History, Growth full screen, Your year, Catch up, every sheet, Settings). A screenshot of each screen is kept in the results. | about 20 min a pass |
| The same, in four passes | **light** (default text), **large** (largest accessibility text size, AX5 = `AccessibilityXXXL`), **dark** (Settings › Look › Night), **contrast** (Increase Contrast on, through `xcrun simctl ui … increase_contrast`) | 80 min |
| Behaviour checks | `LongGameUITests/AccessibilityBehaviourTests.swift`: Reduce Motion (short opening, a still Home, the giggle), Reduce Transparency, Differentiate Without Colour, 44 pt tap targets on eight screens, VoiceOver reading order on five screens | about 10 min |
| Unit tests | `LongGameTests` (everything in `Logic/`) | 1 min |

Debug-only launch switches make this possible (they do nothing in a release build): `-uitest.screen <name>` opens a
screen directly, `-uitest.freshInstall` starts from onboarding, `-uitest.disableAnimations`, `-uitest.appearance
light|dark`, and `-uitest.reduceMotion` / `-uitest.reduceTransparency` / `-uitest.differentiateWithoutColor`, which
set the same values the system settings would. See `LongGame/App/UITestLaunch.swift`.

To run them yourself: Xcode ▸ Product ▸ Test (⌘U) runs everything. To run one pass of the audit, edit the
LongGame scheme ▸ Test ▸ Arguments ▸ Environment Variables and set `LG_PASS` to `light`, `large`, `dark` or
`contrast` (for `contrast`, also turn on Increase Contrast in the Simulator's Settings app first).

## What was found and fixed

Every fix is its own commit on `accessibility-check`, named after the screen.

| # | Screen | What was wrong | Fix |
|---|---|---|---|
| 1 | Sun on Home, Timer, sheets | The sleeping sun's "z" was read as a word on almost every screen, and as text that ignores the text size | Painted as part of the drawing, never read out |
| 2 | Home, History, Your year tabs | On the dark dawn sky the tab names were white on pale glass, about 1.5:1 | The glass takes its dark material and a navy tint there: 5.5–7:1 |
| 3 | Same tabs | They stop growing at the largest sizes (to stay whole) with no way to read them big | Long press shows the Large Content Viewer, as system tab bars do |
| 4 | Intro pages | The page dots were 6 pt tall targets | 44 pt targets, same look |
| 5 | Finish sheet, Add past hours | The note field's tap area was its first line only | The whole box starts typing |
| 6 | Weekly look-back | The longest day's label sat in a fixed 14 pt box | It grows with the text |
| 7 | Finish sheet (both kinds) | At the largest text sizes words were cut off ("A long one. Did t…", "Keep 3 h…") and the note ran into "Today's stretch covered." | Everything above Save scrolls, the sheet opens full height, Keep / Use stack |
| 8 | Weekly look-back | At the largest sizes: "Longe st day", "After…", "Sun ·…", "3…" | The header, the total and the three figures stack; the label over the bars hides (Longest day says it in full) |
| 9 | Growth full screen | At the largest sizes the title and headline ended in "…", the key was cut off and the years ran into each other ("2019202420292034") | The page scrolls with the chart at a fixed height; year labels spaced out |
| 10 | Milestone celebration | At the largest sizes "A thousand h…" and "Your app icon has…" | The scene shrinks to its smallest size and the words wrap |
| 11 | Add past hours / Edit session | At the largest sizes the title was drawn on top of Cancel | The title goes under Cancel |
| 12 | Timer | "Paused. The sun is r…" at the largest sizes | Wraps |
| 13 | Setup steps | The step bar ("Step 2 of 6") read as a 4 pt tall target | Its frame is the 44 pt row it sits in; nothing moves |
| 14 | Milestone celebration | VoiceOver could wander into Home underneath it (the audit found Home's words behind it) | The celebration is modal, and Home underneath is hidden from VoiceOver while it shows |
| 15 | Home | VoiceOver heard Begin and Add past hours before the tabs and today's words | The bottom bar is read last, as it is drawn |
| 16 | Finish sheet | Save and Discard were heard before the time and the note | Read last, as drawn |
| 17 | Add past hours | The − / + buttons were 36 pt targets | 44 pt targets, the same 36 pt circles |
| 18 | Tip jar | The price buttons read as 64 × 34 | The whole 44 pt height is the target |

Test set-up (not an app bug): a paused timer saved on disk by one test opened the next test's Timer paused. The
test launches now clear it first.

## What is left for you to decide (design)

1. **Calendar day cells are 18 × 18 pt** (about 120 audit findings per pass, one per day). Apple's minimum is 44 pt.
   VoiceOver and Voice Control can reach every day (each is a labelled button), but a finger with a tremor will miss.
   Options: (a) bigger cells at the largest text sizes only, (b) tap a week row to open that week, (c) leave it, and
   rely on the day list below the grid.
2. **"Your 50th session." anniversary pill:** ember `#B4561A` on peach `#FFF1DA` measures **4.4:1**, just under 4.5:1.
   A slightly darker ember (or navy text) would pass. At the largest text sizes the audit marks it failed outright.
3. **Words drawn inside pictures don't grow:** the gauge's scale labels on Home (`0`, `2.5k` … `10k`, `3 h 00` …),
   and "Today · 3,253 h" / "~Aug 2037 · 10,000 h" on Meet your future self. They are part of the picture and are read
   by VoiceOver as one summary, so nothing is lost for VoiceOver users; low-vision users without VoiceOver can't make
   them bigger. Options: let them grow up to a limit, or leave them.
4. **Home's tabs are 36 pt tall** (Today / This week / The long game, and Calendar / Growth in History), and
   **This week's day bars are 42 pt wide.** Both are easy to hit in practice and close to 44; making the tabs 44 pt
   tall would make the top of Home taller. Your call.
5. **History · Calendar: "Potentially inaccessible text"** (4–5 per pass) without naming an element. I could not find
   which words it means; the Accessibility Inspector on a Mac may show it (see below).

## False alarms (written down, not silenced)

`LongGameUITests/KnownFalseAlarms.swift` ignores only these, each with the reason and a measurement:

1. Liquid Glass capsule buttons (Begin, Save …): the audit samples the glass, not what is drawn. Measured 15:1.
2. Your year's card: a fixed picture of the image that gets shared; VoiceOver reads it as one summary.
3. Tab names not growing at the largest sizes: on purpose, with the Large Content Viewer (fix 3).
4. Tab tracks' contrast: the same glass misreading as 1. Measured 5.5–13:1.
5. Small grey captions (iCloud, A gentle nudge, Tip jar, Your weekly pace): measured 5.2:1; the audit reads the
   soft edges of thin 13 pt letters.
6. Words scrolled under the pinned buttons' soft fade at the bottom of Home and setup steps 1 and 3: 5:1 or more once
   scrolled into view.
7. "BY WE HAVE SUN": it does grow (see the AX5 screenshots), more slowly than body text, as caption text does.

8. The Timer's title on the pale evening sky at the largest size: measured 5.8:1 against the lightest sky behind it.
9. The note box: the audit sees only the text view's first line; a tap anywhere in the box starts typing, and a
   test checks exactly that (`testNoteBoxStartsTyping`).
10. Undo in the "added" toast: gold on the navy pill measures 7.2:1.
11. Words on the Finish sheet reported as cut off: the sheet is drawn very slightly scaled (0.995), and the
    screenshots show every word whole; at the largest sizes the sheet now scrolls.

The 44 pt tap-target test also leaves out, with the reason in the code: the system's own controls at their standard
sizes (sheet grabber, date picker, segmented pickers, switches) and the design decisions above.

Everything else fails the test, so a new problem shows up as a red test.

## The screenshots

Every screen in every pass has a screenshot named "pass · screen" (for example "large · Finish sheet").

- **In Xcode:** after ⌘U, open the Report navigator (⌘9) ▸ the latest Test ▸ a test ▸ the paperclip next to the
  screen. Each audit finding also has Xcode's own screenshot with the element outlined.
- **From a run on disk:** double-click the `.xcresult` file; it opens in Xcode the same way.
- Worth a look first: "large · Finish sheet · Forgot to stop?", "large · Weekly look-back", "large · Growth · full
  screen" (fixes 7–9), and "light · History · Calendar" (decision 1).

## Accessibility Inspector (on your Mac, 10 minutes)

The audit above is the same engine, but the Inspector lets you point at things.

1. Run the app in the Simulator (⌘R).
2. Xcode ▸ Open Developer Tool ▸ Accessibility Inspector.
3. In its top-left menu choose the Simulator.
4. Press the **Audit** tab (the triangle with "!"), then **Run Audit**. Do this on the five busiest screens: Home ·
   Today, Timer, Finish sheet, History · Calendar, Settings.
5. Click a finding to see the element outlined. The eye button shows a screenshot.
6. For the calendar's "Potentially inaccessible text", click it and tell me which words it outlines.

## On a real iPhone (about 20 minutes)

Do these on your phone with the Debug build; tick as you go. Settings app ▸ Accessibility for each switch. The
Accessibility Shortcut (triple-click the side button) can hold VoiceOver, Voice Control and Switch Control.

**VoiceOver (8 min).** Turn it on. Swipe right through, without looking:
- [ ] Home · Today: you hear the craft, then today's number and what is left, then Begin. Double-tap Begin.
- [ ] Timer: "This session, …" doesn't repeat itself every second. Find Pause, then Finish. (The app has no
  two-finger double-tap "Magic Tap" yet; tell me if you reach for it.)
- [ ] Finish sheet: the time is adjustable (swipe up / down), then Save. You hear "Session saved".
- [ ] The "added" toast after Add past hours: Undo is reachable.
- [ ] History: each calendar day reads "Thursday 22 October, 2 hours …". Growth: swipe up / down steps through the
  milestones; the rotor's Audio Graph plays the chart.
- [ ] Settings ▸ Write to us opens Mail.

**Voice Control (3 min).** Turn it on. Say "Show numbers" on Home, Timer and Calendar: every control gets a number.
Say "Tap Begin", "Tap Pause", "Tap Finish".

**Switch Control (3 min).** Turn it on with the screen as a switch (Settings ▸ Accessibility ▸ Switch Control ▸
Switches ▸ Add ▸ Screen ▸ Full Screen). Start and finish a session. The scanning should never get stuck in the sky.

**Haptics (2 min).** System Haptics on (Sounds & Haptics). Save a session (one soft tap), cover today's stretch (two
taps), scrub the Growth chart (a tick at each milestone). Then turn System Haptics off: nothing buzzes.

**Watch and Live Activity with VoiceOver (3 min).** Start a session on the phone, lock it: VoiceOver reads the Live
Activity's craft, whether it is running, and the time. Pause it from the Lock Screen. On the Watch with VoiceOver, add 30 minutes.

**Speak Screen (1 min).** Settings ▸ Accessibility ▸ Spoken Content ▸ Speak Screen on. On Home and the weekly
look-back, swipe down with two fingers from the top: it reads the words in order and nothing twice.

## What I could not check

- Real VoiceOver speech, Voice Control, Switch Control, haptics, the Watch and the Live Activity: the Simulator can't
  do these properly; the iPhone list above covers them.
- The Accessibility Inspector needs hands on a Mac (list above).
- The iPad and Mac layouts were not audited (the tests run on iPhone 18 Pro).
