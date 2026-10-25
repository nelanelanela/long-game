# Long Game

Free iPhone app that tracks hours spent on ONE craft on the way to 10,000 hours of mastery, shown as a sunrise with a cute smiling sun mascot.

- Full product spec: `docs/SPEC.md` — the source of truth. Read it before any feature work.
- Screen designs: `design/*.dc.html` — HTML mock-ups of every screen (layout, copy, colours, sizes, sun SVG, timer animation timings). They need a design runtime to render, so read them as reference markup rather than opening in a browser. Living canvas: https://claude.ai/artifact/9eccVNQk6JN4hBPGe9VhU6

## Owner

Natalia is a visual artist, not a full-time iOS developer. Explain decisions in plain language, keep the project easy to open and run in Xcode, and stop to ask before anything that needs her Apple Developer account (signing, capabilities, App Store Connect).

## Stack

- Swift 6, SwiftUI, iPhone only, minimum iOS 17. Use iOS 26 Liquid Glass APIs only behind `if #available`.
- SwiftData for storage (local-first). CloudKit sync is opt-in and comes last.
- Swift Charts for the Growth chart. ActivityKit for the timer Live Activity.
- No third-party dependencies unless agreed first. Use XcodeGen (`project.yml`) so the project file stays text and reviewable; install it with Homebrew only after asking.

## Structure

```
LongGame/
  App/            LongGameApp.swift, root navigation
  Models/         Craft, YearEstimate, Session, Settings (SwiftData)
  Logic/          Pure, testable: totals, pace, streaks, calendar levels, forecast
  Features/       Onboarding/, Home/, Timer/, History/ (Calendar, Growth), AddHours/, OneCraft/, Settings/
  DesignSystem/   Colors, Typography, Card, Buttons, SunView (all mascot states)
  LiveActivity/   Widget extension for the timer
LongGameTests/    Swift Testing tests for everything in Logic/
```

## Rules

- Never store derived numbers (totals, streaks, forecast); compute them in `Logic/` from stored entities.
- Exactly one active craft. Replacing archives the old one.
- Timer state = timestamps (startedAt, pausedAt, accumulated pause), never an in-memory counter. Drive the timer UI from `TimelineView`.
- Design tokens live in `DesignSystem/`; no hard-coded colours in feature views. Values are in the Visual system section of the spec.
- SunView is one vector view with states happy / focus / wink / sleepy / celebrate, built from the geometry in the spec.
- Respect Reduce Motion, Dynamic Type and VoiceOver on every screen.
- Copy uses British spelling as in the designs ("practise", "colour").

## Workflow

- Work in the phases in `KICKOFF_PROMPT.md`; finish, build and test each phase before the next.
- Build: `xcodebuild -scheme LongGame -destination 'platform=iOS Simulator,name=iPhone 16' build`
- Test: same with `test`. Every function in `Logic/` gets unit tests, especially the forecast and streaks.
- Commit after each working step with a clear message.
