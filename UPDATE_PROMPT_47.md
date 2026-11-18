# Update prompt 47 for Claude Code: an accessibility check in the Simulator

Paste everything below the line into your Claude Code session in this folder.

---

Before the 1 December release, I want the app checked for accessibility as far as the Simulator allows. Some of it can be automated, some needs a person, and some (VoiceOver itself, haptics) needs a real iPhone. Please do all the parts that can run here, fix what you find, and write up the rest as a short checklist for me.

Start a branch `accessibility-check` from the branch that will ship. If `dark-mode` is ready, check both looks; if not, check the light look and note it.

Read these first:
- `docs/ACCESSIBILITY_REPORT.md` (the earlier static review and what is still open);
- the Accessibility section of `docs/AUDIT.md`;
- `docs/SPEC.md` section 20.

Before you start, tell me in plain words what you're going to run and roughly how long it takes.

## 1 · A UI test target for accessibility
- Add a `LongGameUITests` target (`bundle.ui-testing`) in `project.yml` and regenerate the project. No new dependencies.
- Add a debug-only launch argument set the tests can use. Reuse `-demoData` (it fills a sample game).
  - Add what's missing so each screen can be reached directly, without tapping through onboarding, for example `-uitest.screen home.today`.
  - Add `-uitest.freshInstall` for the onboarding path.
  - Add `-uitest.disableAnimations`, so the tests don't wait for the sunrise.
  - All of this only in DEBUG builds.
- Screens to cover:
  - **Onboarding:** Welcome, the three intro pages, all six setup steps, including A gentle nudge.
  - **Home:** Today (empty day, in progress, stretch covered), This week, The long game, and the weekly look-back sheet.
  - **Timer:** running, paused, the Finish sheet (including the "Forgot to stop?" card), Saved.
  - **History:** Calendar (a full year and the first week), Growth, Growth full screen, the photo viewer.
  - **Your year:** the three card looks; the milestone celebration and the milestone card.
  - **Sheets and settings:**
    - Catch up (welcome back, by week, average);
    - Add past hours;
    - One craft at a time;
    - Meet your future self;
    - the tip jar and thank you;
    - Settings, Data & storage, Your photos (and the delete confirmation), Your weekly pace.

## 2 · The automatic audit
- On every screen above, run `XCUIApplication().performAccessibilityAudit()` (Xcode 15 and later), for all audit types: contrast, element detection, hit region, sufficient element description, Dynamic Type, text clipping and trait.
- Run the whole pass four times:
  - default text size, light;
  - the largest accessibility size (`-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXXXL`), light;
  - default size, dark (if dark mode is in);
  - with Increase Contrast. Set it with `xcrun simctl ui <device> increase_contrast enabled` before the run, and switch it off after.
- Attach a screenshot of every screen in every pass to the test results (`XCTAttachment`, kept always), so I can look through them in Xcode's report navigator.
- Don't silence a finding to make a test pass. If one is a real false alarm (for example a decorative image the audit can't tell is decorative), ignore only that issue in the audit's handler, with a comment explaining why, and list it in the report.

## 3 · Checks the audit can't make, still in the Simulator
- **Reduce Motion:** there's no Simulator switch for it in tests. Add a DEBUG-only launch argument that makes the app behave as if Reduce Motion were on, routed through the same place the app already reads it (don't add a second code path). Then confirm with screenshots and short tests:
  - the opening plays the short fade;
  - no sun breathing, ray turning or water sway;
  - the giggle shows just the face.
- **Reduce Transparency and Differentiate Without Colour:** the same approach. Check that the glass becomes opaque, the title doesn't fade on Home, and calendar levels still read without colour.
- **VoiceOver order:** for Home · Today, the Timer, the Finish sheet, the Calendar and Settings, write a UI test that walks the accessibility elements in order and compares their labels with an expected list. The expected list is the order a person should hear things, top to bottom. This catches wrong order, missing labels and duplicates.
- **Tap targets:** a test that every button, link and toggle on the covered screens is at least 44 × 44 pt (frame or content shape).
- **Dynamic Type layouts:** at AX5, check nothing is cut off. That covers the big numbers, the tab names, the calendar legend, the session rows and the onboarding buttons; the audit's text-clipping check helps here.
- **Accessibility Inspector:** tell me how to open it (Xcode ▸ Open Developer Tool ▸ Accessibility Inspector) and run its Audit on the Simulator for the five busiest screens, so I can see it for myself.

## 4 · Fix, then report
- Fix what you find, in small commits, each naming the screen and the issue. Leave any design change (a colour, a layout that needs rethinking) out of the fixes and list it for me instead.
- Re-run until the automatic audit is clean or every remaining item is explained.
- Rewrite `docs/ACCESSIBILITY_REPORT.md` with today's date:
  - what was run;
  - what passed;
  - what was fixed (with commits);
  - what's left and why;
  - screenshots worth looking at.

## 5 · What only a real iPhone can check
Finish the report with a short checklist for me to do on my own phone, about 20 minutes. Keep each step to one line saying what to turn on, where to go and what to listen or feel for:
- **VoiceOver:** a full session from Begin to Save, the calendar, the Growth chart's audio graph, the year card summary, "Tickle the sun".
- **Voice Control:** "Tap Begin", "Tap Save", "Show names".
- **Switch Control:** a quick pass on Home.
- **Haptics:** the soft tap, two taps and rising three.
- **The Watch and the Live Activity with VoiceOver.**
- **Spoken Content:** Speak Screen on Home.

This needs nothing from my Apple Developer account. Testing on my own iPhone later only needs it plugged in and trusted, which I'll do myself.

When you're done:
- build and run all the tests;
- update `docs/AUDIT.md`;
- tell me in plain words:
  - how many issues were found and fixed;
  - what's left for me to decide;
  - how to open the screenshots.
