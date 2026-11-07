# Update prompt 29 for Claude Code: Long Game for iPad

Paste everything below the line into your Claude Code session in this folder. Do it in three parts and check each in the iPad Simulator before the next. If prompt 28 (the Mac app) has already added a sidebar layout, reuse it rather than building a second one.

---

Long Game should feel made for iPad. Please read the new section **"iPad"** in `docs/SPEC.md`, the "iPhone Duo" section (same rule: layout by window size, never by device) and `design/iPad.dc.html`, read from disk. Everything important is also below.

**Before you start**
- Make sure the app target supports iPad (`TARGETED_DEVICE_FAMILY = 1,2` in `project.yml`), with all orientations and multitasking (no `UIRequiresFullScreen`).
- This needs nothing from my Apple Developer account. If App Store screenshots or settings for iPad are needed later, just list them at the end.

**Part 1 · Layouts by window size**
- Choose the layout from the window's real width and height, and size classes:
  - **Wide** (landscape full screen, or a Stage Manager window at least 1000 pt wide): the sidebar layout.
  - **Tall full screen** (portrait): the top-tabs layout.
  - **Narrow** (under about 600 pt: Slide Over, a third or half of Split View): exactly the iPhone layout.
- Changing the window size keeps the current view, the scroll position, open sheets and the running timer, and animates between layouts.

**Part 2 · The screens**
- **Sidebar layout:**
  - **Sidebar:** 260 pt wide, #EFEBE4. It has the craft name and "3,294 of 10,000 h", then **Play** (Today, This week, The long game), **History** (Calendar, Growth, Your 2026), and **Settings** at the bottom. Rows are 40 pt, with 15 pt text.
  - **Title bar:** the view's title at 28 pt, with capsule buttons **Add past hours** (#EFEBE4) and **Start session** (navy) on the right.
  - **The long game view:**
    - on the left, the sun gauge with its scale and the big total under it;
    - on the right, a 340 pt column of cards:
      - Your chosen pace · Finish line · By Nov 2027 · Rhythm;
      - Today, with today's sessions;
      - Meet your future self.
  - Today and This week use the same two columns.
  - Share these views with the Mac target if it exists.
- **Top-tabs layout (portrait):**
  - Home's three tabs as a floating capsule at the top.
  - "Piano" at 34 pt, with round History and + buttons.
  - A larger sun gauge (sun 220 pt) and the big total at 72 pt.
  - Two cards side by side: the numbers, and Today with today's sessions.
  - The Meet your future self row.
  - **Add past hours** and **Start session** side by side at the bottom, as 56 pt capsules.
  - History, Growth and Your year open full screen as on iPhone, with their content at most 760 pt wide.
- **Timer, wide layout:**
  - on the left, the focus sun at about 340 pt, with its glow;
  - on the right:
    - the craft;
    - the gold total at 56 pt;
    - "of 10,000 hours · 33%";
    - "This session", a 104 pt clock and "Next ray in";
    - Pause and Finish as 180 pt capsules.
  - In tall windows, the iPhone Timer, scaled up.
- Keep every existing rule: the sea always covers the lower part of the sun, Reduce Motion, Dynamic Type and VoiceOver.

**Part 3 · iPad extras**
- **Keyboard shortcuts:**
  - ⌘N start or finish a session;
  - Space pause or resume;
  - ⌘L Add past hours;
  - ⌘1–⌘5 views;
  - ⌘, Settings.
  - Register them with `.keyboardShortcut` and menu commands, so holding ⌘ lists them.
- **Pointer:** hover effects on rows and buttons, and pointer scrubbing on the Growth chart.
- **Drag and drop:** drop an image from Photos or Files onto a session row or the Finish sheet's photo square to attach it. Use the same processing as the photo picker.
- **Apple Pencil:** Scribble works in the note field. Check it isn't blocked.
- **Widgets:** check the iPad Home Screen and Lock Screen sizes.
- **Live Activity:** use it where iPadOS supports it.
- **Liquid Glass** on iPadOS 26, behind `if #available`.

**Checks**
- Add previews and test runs on:
  - iPad Pro 11" in landscape (1194 × 834) and portrait (834 × 1194);
  - iPad mini;
  - Split View at half and a third of the screen;
  - a Stage Manager window that you resize.
- Build, and run all the tests on the iPhone and iPad Simulators.
- Update `docs/AUDIT.md`.
- Tell me how to try each layout in the iPad Simulator, including how to open Split View and Stage Manager there.
