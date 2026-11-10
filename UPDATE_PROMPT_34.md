# Update prompt 34 for Claude Code: a transparent glass top bar on Home, with the sky running up behind it

Paste everything below the line into your Claude Code session in this folder.

---

On the phone's Home, the top bar (craft name, History, Settings and the Today | This week | The long game tabs) should float on the scene, not sit on its own band. Today there's a visible division on Today and This week: the warm wash ends and the hero's sky starts under the tabs, and on iOS 26 the bar adds its own edge effect. Please make the bar transparent and let the scene continue up behind it on every tab. Stay on the `redesign` branch.

**1. The sky runs up behind the bar on every tab**
- In `GaugeHero`, `extendsSky` currently only draws the extended sky when `onDark` (The long game). Extend it to every tab in the phone's single column (`columnPage`):
  - Today and This week: the hero's **day** sky (and its glow) drawn from the top of the screen down to the sea, using `skyExtension` the same way as the long game.
  - Today with nothing played yet: the empty day's **dawn** sky, extended the same way.
  - The long game: unchanged.
- When the sky is extended, `SunriseHero` doesn't draw its own sky (as now for the long game), so there is exactly one continuous sky with no seam.
- Home doesn't draw the warm wash (`lgWarmScreen`) behind the bar any more. Keep the plain background below the hero for the content.
- Check that the horizon, the glow position and the water rule are unchanged on each tab: the sea and its fill stay opaque and in front of the sun.

**2. The bar itself is transparent**
- `lgTopBar` on Home: no background, no material and no divider, on every tab and every iOS version.
- iOS 26: keep `safeAreaBar`, but hide the top scroll edge effect on Home (`.scrollEdgeEffectHidden(true, for: .top)`), so there is no band or blur line under the bar.
- iOS 17–25: the `safeAreaInset` fallback uses `Color.clear` on every tab (today only the long game is clear).
- Only Home changes. Other screens that use `lgTopBar` keep their current bar.

**3. The controls are glass**
- iOS 26: History and Settings stay glass circles (`LGIconButton`), placed together in one `GlassEffectContainer` so they read as a pair. The tabs keep their glass track and lens (`glassTabs`). Tint the track very lightly with `segmentTrack` (about 35%) so it stays warm on the day sky and doesn't disappear.
- iOS 17–25: the icons stay plain. The tabs' flat track becomes `segmentTrack` at 85% with `.ultraThinMaterial` behind it, so the sky shows through softly.
- The craft name has no background. On Today, This week and the empty day it stays navy; on The long game it stays white (as now).

**4. Scrolling**
- When the page scrolls, the content passes under the transparent bar. Make sure the craft name and the glass controls stay readable over the cards: if the title overlaps content after scrolling more than the hero's height, fade the title to 0 over the next 24 pt (the glass controls stay). Scrolling back up brings it back.
- Reduce Transparency: the glass becomes the opaque fallback, and the title never fades.

**5. Design reference**
- The designs `design/redesign/HomeToday.dc.html`, `HomeWeek.dc.html`, `HomeEmpty.dc.html` and `HomeLong.dc.html` show the scene under the title and tabs. Follow the spec above where they differ in the bar's details.

**6. Checks**
- Previews of Home on Today, This week, the empty day and The long game, on iOS 26 and iOS 17, at rest and scrolled, at the smallest and largest Dynamic Type.
- Check on an iPhone 16 Simulator that there's no visible line, band or colour change between the status bar, the bar and the hero on any tab.
- iPad, the iPhone Duo open and Mac layouts are unchanged.

This needs nothing from my Apple Developer account.

When you're done:
- build and run all the tests;
- update `docs/SPEC.md` (Home's header) and `docs/AUDIT.md`;
- tell me how to see each tab at rest and scrolled in the Simulator.
