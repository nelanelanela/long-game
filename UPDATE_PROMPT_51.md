# Update prompt 51 for Claude Code: the chosen tab must show in the dark look

Paste everything below the line into your Claude Code session in this folder.

---

On my iPhone (iOS 26, dark look), Home's tabs Today | This week | The long game don't show which one is chosen: the glass lens under "This week" is almost the same dark blue as the track, and all three names are white. Please fix it everywhere `LGSegmentedControl` is used (Home, History's Calendar | Growth, Your year's looks, the poster's Paper and Look), on the `redesign` branch. Read the updated tabs on `design/redesign/DarkMode.dc.html` and its new **Chosen tab** row in the colour table.

**What it should look like in the dark look** (and on any dark sky, `lgOnDark`)
- **The chosen tab:** a solid warm light pill, #F4EEE4, with the name in navy #16244A, semibold, and a soft shadow (black at 35%, radius 4, y 1). Add it to `Colors.swift` as `LGColor.segmentChosen` (light #FFFFFF, dark #F4EEE4).
- **The other tabs:** white names at 78%, medium weight.
- **The track:** as now.
- **The light look stays as it is.**

**iOS 26 glass**
- Keep the glass track, but in the dark look and on dark skies draw the chosen tab as the solid `segmentChosen` pill instead of the clear glass lens, so it can't disappear into the sky. Keep the pill's slide between tabs with `matchedGeometryEffect` (no slide with Reduce Motion).
- With Increase Contrast, add a 1 pt navy outline at 30% around the pill.

**Check**
- The chosen name on the pill and the other names on the track are at least 4.5:1, and the pill against the track at least 3:1. Tell me the measured numbers.
- Screenshots of Home on each tab in the dark look, the dusk sky and the night sky, and of History and Your year in dark, on iOS 26 and on iOS 17/18 (flat tabs).
- Re-run the accessibility audit's contrast pass in dark.
- VoiceOver still reads "This week, tab, 2 of 3, selected".

This needs nothing from my Apple Developer account. Build, run the tests, and commit with a clear message.
