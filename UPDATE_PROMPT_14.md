# Update prompt 14 for Claude Code: Liquid Glass tabs and buttons

Paste everything below the line into your Claude Code session in this folder.

---

On iOS 26 and later, Long Game's tabs and buttons should use Liquid Glass. Please read the new section **"Liquid Glass (iOS 26 and later)"** in `docs/SPEC.md` (under Visual system) and `design/LiquidGlass.dc.html`. Then implement it.

**Ground rules**
- Use only Apple's system glass APIs: `glassEffect`, `GlassEffectContainer`, `glassEffectID`, and `.buttonStyle(.glass)` / `.glassProminent`. Never build a home-made blur.
- Our minimum is iOS 17, so put every glass API behind `if #available(iOS 26, *)`.
- On iOS 17–25 the app must look exactly as it does now. Do this with small shared styles in `DesignSystem/`, so the feature views don't change per OS:
  - `LGPrimaryButtonStyle`
  - `LGSecondaryButtonStyle`
  - `LGIconButton`
  - `LGSegmentedControl`
- Glass goes on controls only. The sun, sea, numbers, cards, calendar, charts and sheet contents stay flat. Never put glass on glass.

**1. Segmented control**
- Build one `LGSegmentedControl` and use it for:
  - Home: Today / This week / The long game;
  - History: Calendar / Growth;
  - Your year: Sunrise / Evening / Photos, if that screen exists yet.
- On iOS 26 and later:
  - the track is a glass capsule;
  - the selected tab is a brighter, interactive glass lens, using `glassEffectID` in a `GlassEffectContainer`;
  - the lens morphs and stretches to the tapped tab.
- On older iOS, keep today's look.
- VoiceOver: keep it a tab list ("Today, tab, 1 of 3, selected").

**2. Buttons**
- **Primary** (Start session, Save, Share, Start playing and the like): a 56 pt capsule, `.glassProminent` tinted with the ink colour, white text.
- **Secondary** (Add past hours, Discard, Keep playing and the like): a 48 pt capsule, `.glass`, navy text.
- **Toolbar icons** (History, +, Settings, back, the Timer close button): 44 pt glass circles.
- **Timer:**
  - Pause and Resume: clear glass;
  - Finish: `.glassProminent` tinted white, with navy text;
  - the today's-stretch strip: clear glass with a 22 pt radius.

**3. Background**
- Home and History get the soft warm wash at the top (#FFF0D6 fading into the background) so the glass has something to catch.
- The header and tabs float as a glass layer while the content scrolls under them.
- Add the colour as a token in `DesignSystem/`.

**4. Accessibility**
- Check Reduce Transparency, Increase Contrast, Reduce Motion (the lens moves without stretching), Dynamic Type up to XXXL, and VoiceOver.
- Text contrast must stay at 4.5:1 or better.

**5. Checks**
- Add previews for each style on iOS 26 and on iOS 17, in light conditions and over the Timer's night sky.
- Build and run on an iOS 26 Simulator and an iOS 17 Simulator, and confirm the iOS 17 version looks unchanged.
- Run all the tests and update `docs/AUDIT.md`.

When you're done, tell me how to compare the two looks in the Simulator. This needs nothing from my Apple Developer account. It does need Xcode 26: if my Xcode is older, stop and tell me.
