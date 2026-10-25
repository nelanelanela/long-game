# Long Game

Free iPhone app that tracks the hours you put into one craft on the way to 10,000.
Product spec: `docs/SPEC.md`. Screen designs: `design/`.

## Open and run

1. Double-click `LongGame.xcodeproj` (Xcode 16 or newer).
2. Pick an iPhone simulator at the top and press ▶︎.
3. To see the app full of sample data (debug builds only): Product ▸ Scheme ▸ Edit Scheme ▸ Run ▸
   Arguments ▸ add `-demoData`. Remove it to start fresh.

If you change `project.yml` (adding targets or settings), regenerate the project with `xcodegen generate`.

## Tests

```bash
xcodebuild -scheme LongGame -destination 'platform=iOS Simulator,name=iPhone 16' test
```

All the calculations (baseline, totals, pace, streaks, forecast, timer, milestones, reminders, CSV) live in
`LongGame/Logic/` and are covered by `LongGameTests/`.

## App icon

`swift Tools/MakeIcon.swift LongGame/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png`
redraws the icon from the same sun geometry as the app.
