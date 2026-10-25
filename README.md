# Long Game

**A free iPhone app that tracks the hours you put into one craft on the way to 10,000.**

Pick one thing you want to master (piano, drawing, writing, code), count only the focused hours, and watch a smiling sun rise a little further each day. No ads, no subscription, no price tag.

## Why one craft?

The "10,000 hours" idea is about sticking with something for a long time. Long Game holds exactly one active craft at a time. If you start a new one, the old one is archived with all its history, read-only.

## Features

- **Gentle onboarding.** Tell the app when you started and roughly how many hours a week you practised each year. It estimates your past hours so you don't start from zero.
- **Timer.** Start, pause and finish a session. The sun animates through the hour. Runs as a Live Activity and in the Dynamic Island.
- **Add past hours.** Log a session you forgot to time.
- **History.** A calendar of practice days and a Growth chart of your pace over time.
- **Mastery forecast.** A projected date for reaching 10,000 hours, with an early-to-late range and a "what if I practised more?" slider.
- **Streaks and milestones.** Celebrations at 100, 500, 1,000, 2,500, 5,000, 7,500 and 10,000 hours.
- **Reminders.** Optional and off by default: daily nudge, streak at risk, long-session check-in.
- **Your data stays yours.** Everything is stored on the device and works offline. iCloud sync with Sign in with Apple is optional. Export your sessions to CSV any time.
- **Accessible.** Supports Dynamic Type, VoiceOver and Reduce Motion.

## Built with

- Swift 6 and SwiftUI, iPhone only, iOS 17 and later (Liquid Glass styling where the OS offers it)
- SwiftData for local storage, CloudKit for optional sync
- Swift Charts for the Growth view
- ActivityKit for the timer Live Activity
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) to keep the project file reviewable (`project.yml`)
- No third-party dependencies in the app

## Project layout

```
LongGame/          The app
  App/             Entry point and root navigation
  Models/          Craft, YearEstimate, Session, Settings (SwiftData)
  Logic/           Pure, tested calculations: totals, pace, streaks, forecast
  Features/        Onboarding, Home, Timer, History, Add hours, Settings
  DesignSystem/    Colours, typography, cards, buttons, the sun mascot
LongGameWidgets/   Live Activity extension
LongGameTests/     Unit tests for everything in Logic/
Shared/            Code shared by the app and the widget
design/            HTML mock-ups of every screen
docs/SPEC.md       Full product spec
Tools/             Helper scripts (app icon generator)
```

Derived numbers such as totals, streaks and the forecast are never stored. They are always calculated from the saved sessions and estimates.

## Open and run

You need a Mac with Xcode 16 or newer.

1. Clone the repository and double-click `LongGame.xcodeproj`.
2. Pick an iPhone simulator at the top and press ▶︎.
3. To see the app full of sample data (debug builds only): Product ▸ Scheme ▸ Edit Scheme ▸ Run ▸ Arguments ▸ add `-demoData`. Remove it to start fresh.

To run on a real device or use iCloud sync and Sign in with Apple, you need to select your own Apple Developer team and bundle identifier in Xcode's Signing & Capabilities.

If you change `project.yml`, regenerate the project with `xcodegen generate`.

## Tests

```bash
xcodebuild -scheme LongGame -destination 'platform=iOS Simulator,name=iPhone 16' test
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
