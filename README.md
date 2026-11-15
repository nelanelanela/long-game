# Long Game

**A free app for iPhone, iPad, Apple Watch and Mac that counts the hours you put into one craft on the way to 10,000.**

Pick one thing you want to master (piano, drawing, writing, code), count only the focused hours, and watch a smiling sun rise a little further each day. No ads, no account, no subscription, no tracking.

Version 1.0, released 1 December 2026.

## Why one craft?

The "10,000 hours" idea is about sticking with something for a long time. Long Game holds exactly one active craft at a time. If you start a new one, the old one is archived with all its history.

## Features

- **Gentle setup** in seven short steps: your craft, when you started, roughly how many hours a week each year (so you don't start from zero), a weekly pace for the next 12 months, iCloud, reminders and the weather.
- **Home** in three tabs: Today (what's left of today's stretch), This week (your pace) and The long game (your total and when you'll reach 10,000 hours).
- **Timer** with a sunrise that rises through the session, a Live Activity, a Control Centre control and an Action Button shortcut. Undo right after saving.
- **Add past hours** for anything you didn't time, with a note and a photo.
- **History:** a calendar of every day you played and a Growth chart of where your pace takes you, with a full-screen chart you can drag along. A **Rhythm** of days a week instead of streaks, so a day off never breaks anything.
- **Milestones** at 100 and 500 hours, every 1,000, and at 2,500 and 7,500, each with a card to share. A **keepsake poster** of your calendar, ready to print, at every 1,000.
- **Letters to your future self**, sealed until the sun brings them back at a milestone.
- **Then and now**, your first photo next to your latest; **the sun remembers** small moments from your own history; a weekly look-back.
- **Weather in the scene** (off by default): rain, mist, wind, cloud and snow from outside your window pass through the landscape.
- **A night look** that follows your iPhone, or Light and Dark by choice.
- **Apple Watch:** start, pause and finish a session, and add time with the Crown. **Widgets** on the Home Screen and the Lock Screen. **iPad and Mac** with a sidebar layout and a sun in the Mac's menu bar.
- **Your data stays yours.** Everything is stored on the device and works offline. iCloud sync is optional, with no sign-in. Export your sessions to CSV any time.
- **Accessible.** Dynamic Type up to the largest sizes, VoiceOver, Reduce Motion, Increase Contrast, Differentiate Without Colour and 44 pt targets, checked by automated audits (`docs/ACCESSIBILITY_REPORT.md`).

## Built with

- Swift 6 and SwiftUI; iOS 17 and later (Liquid Glass styling from iOS 26), watchOS and macOS
- SwiftData for local storage, CloudKit for optional sync
- Swift Charts, ActivityKit, WidgetKit, App Intents, WeatherKit
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) to keep the project file reviewable (`project.yml`)
- No third-party dependencies in the app

## Project layout

```
LongGame/              The iPhone and iPad app
  App/                 Entry point, storage, sync, weather, debug launch switches
  Models/              Craft, YearEstimate, Session, AppSettings, Letter … (SwiftData)
  Logic/               Pure, tested calculations: totals, pace, rhythm, forecast, milestones, letters …
  Features/            Onboarding, Home, Timer, History, Letters, Keepsake, Settings …
  DesignSystem/        Colours, typography, cards, buttons, the sun mascot, the scene
LongGameWidgets/       Widgets, the Live Activity and the Control Centre control
LongGameWatch/         The Apple Watch app (and LongGameWatchWidgets/)
LongGameMac/           The Mac app (and LongGameMacWidgets/)
Shared/, WatchShared/  Code shared between the app and its extensions
LongGameTests/         Unit tests for everything in Logic/, and the migration test
LongGameUITests/       Accessibility audits and flow tests
design/                HTML mock-ups of every screen
docs/                  SPEC.md (the product spec), AUDIT.md, RELEASE.md, ACCESSIBILITY_REPORT.md
Tools/                 Helper scripts (app icon generator)
```

Derived numbers such as totals, rhythm and the forecast are never stored. They are always calculated from the saved sessions and estimates.

## Open and run

You need a Mac with Xcode 26 or newer.

1. Clone the repository and double-click `LongGame.xcodeproj`.
2. Pick an iPhone simulator at the top and press ▶︎.
3. To see the app full of sample data (debug builds only): Product ▸ Scheme ▸ Edit Scheme ▸ Run ▸ Arguments ▸ add `-demoData`. Remove it to start fresh. Other debug switches are listed in `LongGame/App/UITestLaunch.swift`, and Settings has a Debug only card in debug builds. None of them exist in Release builds.

To run on a real device or use iCloud sync and the weather, you need to select your own Apple Developer team and bundle identifier in Xcode's Signing & Capabilities.

If you change `project.yml`, regenerate the project with `xcodegen generate`.

## Tests

```bash
xcodebuild -scheme LongGame -destination 'platform=iOS Simulator,name=iPhone 18 Pro' test
```

## App icon

```bash
swift Tools/MakeIcon.swift LongGame/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png
```

redraws the icon from the same sun geometry as the app.

## Design and spec

The product spec is in [`docs/SPEC.md`](docs/SPEC.md). Screen designs are in [`design/`](design/); the `.dc.html` files are reference markup for a design runtime rather than normal web pages.

## Contributing

Issues and suggestions are welcome. This is a small personal project, so please open an issue to discuss an idea before sending a large pull request.

## Licence

Code is released under the [MIT License](LICENSE).

The sun mascot, app icon and screen designs are © Natalia Terlecka, all rights reserved.

## Author

Made by Natalia Terlecka.
