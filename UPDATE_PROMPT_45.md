# Update prompt 45 for Claude Code: dark mode, the night look

Paste everything below the line into your Claude Code session in this folder.

---

Long Game gets a dark look for practising in the evening. Please read `design/redesign/DarkMode.dc.html`: the colour table, the rules and three screens (Home · Today, History · Calendar, Settings). This is a large change, so work on a separate branch `dark-mode` from `redesign`, in the parts below, and keep the light look pixel-for-pixel as it is today.

## 1 · Colours
- Give every colour in `DesignSystem/Colors.swift` a dark value (asset catalogue colours or a light/dark initialiser, whichever the file already favours):

| Token | Light | Dark |
| --- | --- | --- |
| background | #FAF7F1 | #0B1029 |
| card | #FFFFFF | #172044 |
| ink (text) | #16244A | #F4EFE6 |
| inkMuted | #5E6782 | #A9B1C9 |
| primary button fill / label | #16244A / white | #FFD66B / #16244A |
| accent text (ember) | #B4561A | #FFB877 |
| segmentTrack | #EFE2CF | #262F57 |
| hairline | #ECE7DE | #222B52 |
| calendar rest dot | #C5D0EC | #3D4D93 |
| peach wash / peach tiles | #FFF1DA | #2A2440 |

- Cards lose their drop shadow in dark and get a 0.5 pt inner hairline (white 8%) instead.
- The sun, the calendar's four level colours and the session pictures don't change.
- Search the feature views for any colour that isn't a token (hex values, `.white`, `.black`) and tell me what you find before changing them.

## 2 · The scene in dark
- **Home, all tabs:** the night sky and night land (`SkyView(tone: .night)`, `LandView(tone: .night)`), whatever the progress. The sun's height, its glow and the lit arc carry the progress:
  - an empty day is the sun resting on the horizon with no lit arc;
  - the glow grows with progress, from 35% to 100%.
- **The Timer:** the same sunrise, but in dark it stops at the dawn colours. Map today's progress so that p = 1 shows what p = 0.55 shows in light, and the text stays white throughout. Paused and Saved follow.
- **Onboarding, the sheets' small scenes, the future self and tip jar:** dawn sky and night land.
- **Launch:** unchanged (already night). The opening sunrise ends on the dark Home, so its last phase fades to night colours instead of dawn. Check that the hand-over is still seamless.
- The water rule holds: the sea is opaque and in front of the sun.

## 3 · The setting
- Settings gets an **Appearance** group at the top with one row, **Look**: a segmented control with Automatic, Light and Dark. Automatic is the default and follows the iPhone.
- Store the choice in `Settings`, and apply it with `preferredColorScheme` at the root, so sheets and full-screen covers follow.

## 4 · What stays in its own look
- Year cards and the milestone card: the look is chosen when sharing, whatever the app's appearance.
- The app icon, and its Dark and Tinted variants, as they are.
- Widgets, the Live Activity and the Watch: widgets follow the system (night sky and land in dark); the Live Activity and the Watch are already dark.

## 5 · Glass and contrast
- Liquid Glass controls (iOS 26) pick up the dark material by themselves; check the tabs and icon pairs over the night sky.
- Text contrast is 4.5:1 or better everywhere. The gold primary button carries navy text. Check the muted text on cards.
- Increase Contrast and Reduce Transparency keep working in both looks.

## 6 · Checks
- Previews of every screen in both looks.
- Snapshot or preview comparisons that the light look hasn't changed.
- Tests for the Timer's dark mapping and the appearance setting.
- Walk through the whole app in the Simulator in dark: onboarding, Home (empty, in progress, covered), Timer (start, paused, saved), History, Your year, Settings, Catch up, the tip jar.

This needs nothing from my Apple Developer account.

When you're done:
- build and run all the tests;
- update `docs/SPEC.md` (Visual system: the dark values and rules) and `docs/AUDIT.md`;
- tell me how to switch looks in the Simulator, and list anything you weren't sure about so I can decide.
