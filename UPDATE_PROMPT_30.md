# Update prompt 30 for Claude Code: launch screen and the opening sunrise

Paste everything below the line into your Claude Code session in this folder.

---

We're adding a launch screen and a short sunrise when the app opens. Please read these parts of `docs/SPEC.md`:
- the new section **"21 · Launch screen and the opening sunrise"**;
- "4 · Home", for where the sun sits on the Today arc;
- the water rule in "Shared hero details".

Also read `design/Launch.dc.html`. Then implement the following. Work in two parts. After each part, build, run the tests, tell me how to see it in the Simulator, and wait for my OK before the next.

**The spirit:** a small, calm sunrise, under a second, that never gets in the way. No text, no sound, no haptic.

**Part 1 · The launch screen (still)**
- Add `LaunchScreen.storyboard` and point `UILaunchStoryboardName` at it in `project.yml`. Remove any `UILaunchScreen` dictionary that's there now.
- Draw the night frame from the spec and the design:
  - navy sky #16244A with the nine faint stars in the top half;
  - the night sea (fill #22306A, pale wave #2E3C7A, wave line #3E4C8A) pinned to the bottom, with the waterline at 56% of the screen height;
  - the sleeping sun (closed eyes, cheeks, no rays), about 96 pt wide, centred, with its lower part under the water.
- Export the sun, the sea and the stars as vector PDF assets with "Preserve Vector Data" on. Put the colours in the asset catalogue as named colours. Use Auto Layout constraints so it fits every iPhone and iPad size and both orientations. The sea always spans the full width.
- Nothing gold on or in the water. The sea is opaque and sits in front of the sun.
- No text, logo or wordmark.
- Tell me how to check it, including how to clear the launch-screen cache in the Simulator (iOS caches it, so changes can look stuck).

**Part 2 · The opening sunrise (in the app)**
- Add `Features/Launch/OpeningSunriseView.swift`, shown above the root view on a cold start only.
- Its first frame must match the storyboard exactly, so the hand-over from the still image can't be seen. Reuse `SunView` (sleepy, then happy, with rays) and the shared sea view. Don't copy their drawing code.
- Timings:
  - **0–0.6 s:**
    - the sky goes from navy through dusk (#2A2F6B → #6E3D74 → #F2A07A) to morning (#FFE3B0 → #FFF1DA → #FAF8F4);
    - the stars fade;
    - the sun rises, and its rays unfold (scale 0 → 1) with a soft glow;
    - the water turns from night blue to day blue (#D3DEF4, wave line #16244A).
  - **0.6–0.8 s:** the sun opens its eyes and smiles, then glides into its spot on Today's arc with `matchedGeometryEffect` as Home fades in. Then remove the overlay.
- Put the new colours in `DesignSystem/` as tokens.
- When it plays:
  - Cold start only. Returning from the background shows the app as it was.
  - A tap anywhere jumps to the end.
  - Skip it entirely when the app is opened from a widget, the Live Activity, a notification or a URL.
  - Use the short version (a 0.3 s cross-fade from the night frame to Home) in these cases:
    - a session is running;
    - Reduce Motion is on;
    - VoiceOver is running.
  - Before onboarding, end on Welcome instead of Home.
  - Dark mode: stop the sky at dusk and cross-fade into Home in dark.
- The overlay is hidden from VoiceOver. Move focus to Home's first element when it's gone.
- iPad uses the same view with the sea at full width. The Mac has no system launch screen, so its first window opens on the night frame and plays the sunrise.
- Don't delay loading. Load SwiftData and start the iCloud check while the sunrise plays, and never make it wait for them.
- Add SwiftUI previews of the night frame, the dusk frame and the morning frame.
- Add a debug option, **Play opening sunrise**, that replays it without restarting.

**Tests**
- Put the "which version plays" decision in a pure function in `Logic/`, for example `openingStyle(coldStart:, openedFrom:, sessionRunning:, reduceMotion:, voiceOver:, onboarded:, dark:)`.
- Test every case above: warm start, deep links, a running session, Reduce Motion, VoiceOver, before onboarding and dark mode.

This needs nothing from my Apple Developer account.

When you're done:
- build and run all the tests;
- update `docs/AUDIT.md`;
- tell me how to see the full sunrise, the short version and the dark version in the Simulator.
