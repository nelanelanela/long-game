# Accessibility report — Long Game

**Status (5 November 2026):** items 2–9 below are implemented (see `docs/AUDIT.md`, section Accessibility). Still open: dark mode (#6, design job), Accessibility Inspector audit and real-device VoiceOver testing.

Date: 5 November 2026. Method: static read of the Swift code, `docs/SPEC.md` and the design tokens, plus computed contrast ratios. **Not yet done:** running the app with VoiceOver, Voice Control, Larger Text or Accessibility Inspector on a device. Items marked *(verify)* need that.

## Summary

The app is in good shape for an indie project. VoiceOver is clearly designed in (about 46 labels, 43 trait calls, 4 adjustable/custom actions, a chart Audio Graph, two spoken announcements). Reduce Motion is handled on the main animated screens. Text styles scale with Dynamic Type, and the muted greys were already darkened to pass 4.5:1.

The gaps are mostly in places the spec promised but code or scope hasn't reached: the watch and widgets, tiny tap targets, Larger Text sizes, and colour-only meaning in the calendar.

## What is already solid

| Area | Evidence |
|---|---|
| Text scaling | Every `lgText` style uses `@ScaledMetric`; big numbers use `minimumScaleFactor(0.4)` + `lineLimit(1)`. |
| VoiceOver on the hero screens | Timer, Growth chart (`accessibilityChartDescriptor`, adjustable action), sun ("Tickle the sun" custom action), ray announcements, Year card as one spoken summary. |
| Reduce Motion | Honoured in SunriseHero, Home, Timer (19 checks), Milestone, Tip screens, Photo viewer, Growth scrub, Year. |
| Contrast of body text | ink on background 14.3:1; inkMuted 5.3:1; gaugeLabel 4.57:1; finishLabel 5.35:1; danger 5.78:1. |
| Tap targets on icon buttons | Growth full-screen and photo remove buttons draw a small circle but pad to a 44 pt hit area. |
| Calendar days | Each day reads "Thursday 22 October, 2 hours" and future days are hidden from VoiceOver. |

## Findings, most important first

### 1. Apple Watch, widgets and complications (corrected: mostly fine)
**Correction:** the first version of this report said these had no accessibility code. That was wrong: I only searched the extension folders. The pictures live in `Shared/WidgetViews.swift` and `WatchShared/WatchViews.swift`, which already label the widgets, complications, watch pages and timer. What was missing was the Live Activity's running/paused state and the Dynamic Island's compact and minimal labels, now added. Real VoiceOver on a device is still to be checked.

### 2. Dynamic Type stops at XXXL for everyone (High)
`LongGameApp.swift:34` caps the whole app at `.xxxLarge`. People who turn on the accessibility sizes (AX1–AX5, the ones low-vision users rely on) get no benefit. The spec says "up to XXXL", so this is by design, but it's the most impactful change available.
**Propose:** raise the cap to `.accessibility3` app-wide, then fix screens that break. Design previews at AX3 already exist for FutureSelfSheet and IntroView, so the groundwork is there. Switch fixed `HStack`s to `ViewThatFits` or `AnyLayout` on `dynamicTypeSize.isAccessibilitySize`. Update the spec line.

### 3. Calendar day cells are 14 × 14 pt tap targets (High)
`CalendarTab.swift:22` (`cell = 14`, `gap = 3`) and the cells use `onTapGesture`. Apple's minimum is 44 pt; this is hard for anyone with tremor or low dexterity. VoiceOver works, but Switch Control and Voice Control see an untitled gesture area.
**Propose:** (a) keep the 14 pt look but add a larger invisible hit area per column/row, or (b) make the cell scale with Dynamic Type and offer a "Larger cells / list view" at accessibility sizes. Also replace `onTapGesture` with a real `Button` (`.buttonStyle(.plain)`) so it gets the button trait, focus ring and Voice Control name for free.

### 4. Calendar levels rely on colour (Medium)
The four practice colours differ from each other by only 1.26–1.53:1 in contrast and the lightest is 1.18:1 against the page; level 1 vs "rest" is 1.09:1. The spec says levels "also differ in lightness", but neighbouring steps are close, and nothing reads `accessibilityDifferentiateWithoutColor` (0 uses in the app).
**Propose:** when Differentiate Without Colour is on, overlay a small pattern or tiny dot count (1–4 dots, or a thicker bottom bar) in each cell, and add the same marks to the legend. Also give the legend swatches the same treatment. Also consider a 1 pt outline on rest and level-1 cells so they meet the 3:1 non-text rule on the cream background.

### 5. Text-on-colour contrast misses 4.5:1 in a few places (Medium)
- White on the darkest practice colour `#EE6420`: **3.24:1**. Navy on it passes (4.68:1). Make sure nothing puts white text there.
- `forecast` orange `#EE6420` as *text* on the page background: **3.06:1**. Fine for lines and graphics (≥3:1), not for words. Check any forecast label or "finish" caption using it.
- `inkMuted` on the pale sea (`#D3DEF4`): **4.15:1**, just under. Appears where caption text sits over the sunrise hero. *(verify which labels)*
- ~~Timer strip caption contrast~~ The strip was removed in update 21.

### 6. No dark mode, and Increase Contrast / Reduce Transparency are not read (Medium)
`LongGameApp.swift:33` forces `.preferredColorScheme(.light)`. Some people with light sensitivity or migraines need dark appearance; "Smart Invert" also behaves badly on forced-light apps unless images are marked `accessibilityIgnoresInvertColors()` (0 uses; matters for photos and the sun).
There is no use of `accessibilityReduceTransparency` or `colorSchemeContrast`. The spec relies on iOS 26 glass adapting itself, which is true for system glass, but the pre-26 path (`white.opacity(0.08)` strip in `Glass.swift:74`, translucent buttons at 12%) does not adapt.
**Propose:** (a) add `.accessibilityIgnoresInvertColors()` to user photos and SunView now (cheap); (b) make `.translucent` and the glass-strip fallback solid when Reduce Transparency is on; (c) treat full dark mode as its own piece of design work, not a quick fix.

### 7. Animations without a Reduce Motion check (Low–Medium)
Files that animate with no `accessibilityReduceMotion`: `SunView.swift` (face crossfade, 0.18 s; harmless), `TimerSky.swift` (0.5 s sky change on pause; harmless), `HistoryView.swift` (tab slide), `CatchUpSheet.swift`, `OnboardingFlow.swift` and `IntroView.swift` (page transitions/slides, 3 each). The intro and onboarding transitions are the ones most likely to be a vestibular trigger.
**Propose:** one small `lgAnimation()` helper that returns `nil` when Reduce Motion is on (or a cross-fade), and use it in those six files. Add a unit-free manual check to the checklist.

### 8. Non-scaling icon sizes (Low)
About 20 icons use `.font(.system(size: 11–22))` (chevrons in Settings, Home, Year, Calendar, Archived crafts, the camera in NotePhotoRow). They stay small when text grows, so at large text sizes the chevrons look tiny next to big labels. Year card (`YearCardView`) is intentionally fixed because it renders to an image; leave it.
**Propose:** put a `LGIcon` style (size via `@ScaledMetric`, `relativeTo: .footnote`) in `DesignSystem/` and use it for those chevrons; no change to the look at default size.

### 9. Smaller VoiceOver improvements (Low)
- Announcements exist for ray lit and scrubbing only. Add `AccessibilityNotification.Announcement` for: session saved, paused/resumed, milestone reached (Milestone celebration is a full-screen moment but silent to VoiceOver unless it grabs focus), tip thanks.
- Move VoiceOver focus (`AccessibilityFocusState` or `.screenChanged`) to the title when onboarding steps, the Finish sheet and the celebration appear.
- `PhotoViewer` double-tap zoom (`onTapGesture(count: 2)`): confirm there is an `accessibilityZoomAction`.
- No `accessibilityInputLabels` for Voice Control: short names for "Pause", "Finish", "Minimise", "Open chart full screen" ("Expand chart") help people who speak the control name.
- Mark titles with `.isHeader` on every screen (done on Session form and Yearly hours; spot-check the rest) so the Headings rotor works.
- The timer's "This session" label is re-rendered every second; check VoiceOver doesn't re-announce it. *(verify)*

### 10. Hit targets worth a quick look (Low)
`TipSunIcon` is 40 × 40, the Growth scrub close button is 44 pt after padding (good), the Timer/Session/Year/Onboarding header spacers use 34 × 44 (good).

## Proposed change list (ordered)

1. Add labels/hiding for widgets, complications, Live Activity and the watch. *(fixes #1)*
2. Replace calendar `onTapGesture` with `Button` and enlarge the hit area. *(#3)*
3. Add `accessibilityIgnoresInvertColors()` to SunView and photos; add Reduce Transparency fallbacks. *(#6)*
4. Add an `lgAnimation()` Reduce-Motion helper and use it in the six files. *(#7)*
5. Add Differentiate Without Colour marks to the calendar and legend. *(#4)*
6. Check the four contrast items in #5 on real screens and darken or switch to navy text where needed.
7. Add `LGIcon` scaled icon style. *(#8)*
8. Add the extra announcements, focus moves and Voice Control names. *(#9)*
9. Raise the Dynamic Type cap to AX3 with adaptive layouts, then update the spec. *(#2 — largest piece; do it as its own phase)*
10. Decide separately whether to design a dark appearance. *(#6)*

## Manual test checklist (to run before release)

- VoiceOver: complete onboarding, start/pause/finish a timer, add hours, open the calendar, scrub the Growth chart, share Year, tip jar, watch and widgets.
- Larger Text at XXXL and AX3: every screen, check nothing is cut off and the sun/sea still covers correctly.
- Reduce Motion, Reduce Transparency, Increase Contrast, Differentiate Without Colour, Smart Invert, Bold Text, Button Shapes: each on, walk the main flow.
- Voice Control: say "Show numbers" on Home, Timer and Calendar and check every control gets a number.
- Run Xcode's Accessibility Inspector audit on each screen for contrast and hit-region warnings.
