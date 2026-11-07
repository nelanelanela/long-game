# Update prompt 28 for Claude Code: Long Game for Mac

Paste everything below the line into your Claude Code session in this folder. It's a big one, so do it in four parts and check each part before the next.

---

We're adding a Mac app. Please read these parts of `docs/SPEC.md`:
- the new section **"Mac app"**;
- the updated line about the running timer under "Accounts and sync".

Also read `design/Mac.dc.html` from disk. Everything important is also written below.

**Before you start**
- Adding a macOS target, signing it, enabling iCloud/CloudKit for it and making it a universal purchase all touch my Apple Developer account. Stop and tell me exactly what to click before you change signing, capabilities or App Store settings.
- Until then, build the Mac app so it runs locally from Xcode on my Mac.

**Part 1 · The Mac target and shared code**
- In `project.yml` (XcodeGen), add a **macOS app target "LongGame Mac"**:
  - macOS 14 or later;
  - the same bundle ID family, with universal purchase in mind;
  - sharing `Models/`, `Logic/` and `DesignSystem/` with the iPhone app.
- Put iPhone-only code (Live Activity, Watch link, alternate icons, haptics) behind `#if os(iOS)` or in iOS-only files.
- Keep the iPhone app building and all tests passing.
- `Logic/` stays the same for both. Add a Mac test scheme that runs the same `LongGameTests`.
- Tell me which files you had to split and why.

**Part 2 · The main window**
- Default size 1180 × 740, minimum 900 × 600, with a `NavigationSplitView`:
  - **Sidebar** on #EFEBE4: the craft name and "3,294 of 10,000 h", then **Play** (Today, This week, The long game), **History** (Calendar, Growth, Your 2026), and **Settings** at the bottom.
  - **Toolbar:** the view's title, **Add past hours** (bordered) and **Start session ⌘N** (navy). When a session runs, the window shows the Timer, and Finish opens the Finish sheet.
- **The long game view:**
  - On the left: the sun gauge with its scale (about 520 × 340, sun 190 pt, the same sea and water rule as iPhone), with the big total and "of 10,000 hours · 33%" under it.
  - On the right: a 330 pt column of three white cards:
    1. a 2 × 2 grid: Your chosen pace · Finish line · By Nov 2027 · Rhythm;
    2. Today: "1 h 05 of 1 h 45 · 40 m to the moon", plus today's sessions;
    3. Meet your future self.
- **Today and This week:** the same two-column layout, with their own gauge and numbers.
- **History:** reuse the iPhone views at a wider size:
  - Calendar with the day card beside it;
  - Growth with its key, full width;
  - scrubbing with the pointer.
- **Menus and shortcuts:**
  - ⌘N start or finish a session;
  - Space pause or resume;
  - ⌘L Add past hours;
  - ⌘1 ⌘2 ⌘3 Today, This week, The long game;
  - ⌘4 ⌘5 Calendar, Growth;
  - ⌘, Settings.
  - Show them all in the File, View and Session menus.

**Part 3 · The sun in the menu bar**
- Add a `MenuBarExtra` in window style.
- The icon is a small sun:
  - while a session runs, it shows the clock ("25:18"), driven by `TimelineView` or `Text(timerInterval:)` and never by a counter;
  - otherwise it shows today's time ("1 h 05").
- **The popover, 320 pt wide.**
  - Running:
    - the craft and total;
    - a navy card with the focus sun, "This session", the clock and "Next ray in";
    - today's arc with "1 h 30 of 1 h 45 · 15 m to the moon";
    - **Pause** (Space) and **Finish**;
    - "Open Long Game ⌘O".
  - Idle:
    - today's arc with the big time and "of today's 1 h 45 · 40 m to the moon";
    - **Start session ⌘N**;
    - links to Add past hours and Open Long Game.
- **Settings:** add **Show in Dock**, on by default. When it's off, use the accessory activation policy, so only the menu bar sun remains.

**Part 4 · Sync and one session everywhere**
- Use the same CloudKit container and the same SwiftData models. Only sync when Save to iCloud is on.
- **Running session:** add a small `ActiveSession` record synced through iCloud: startedAt, pausedAt, accumulated pause, device name.
  - A session started on the Mac shows on the iPhone, with its Live Activity, and the other way round. Either device can pause or finish it.
  - If two devices start at once, the earlier start wins and the other shows it.
  - The Watch keeps using WatchConnectivity with the iPhone.
- **Also:**
  - the widgets on the Mac desktop and in Notification Center (WidgetKit for macOS);
  - notifications;
  - drag an image onto a session, or onto the Finish sheet's photo square, to attach it;
  - Liquid Glass on macOS 26, behind `if #available`.
- **Not on Mac:** Live Activities, the Watch link and alternate app icons. Instead, when "App icon grows with you" is on, set the Dock icon to the current stage with `NSApp.applicationIconImage`.
- **Accessibility:** full keyboard access, VoiceOver labels as on iPhone, and the system text size where SwiftUI supports it.
- **Tests:**
  - ActiveSession conflict resolution: the earlier start wins;
  - pause and finish from the other device;
  - the menu bar text when running and idle.

When each part is done:
- build both apps and run all the tests;
- tell me how to run the Mac app from Xcode (choose the "LongGame Mac" scheme and "My Mac").

At the end:
- update `docs/AUDIT.md`;
- list exactly what I need to do in my Apple Developer account and App Store Connect for the Mac version.
