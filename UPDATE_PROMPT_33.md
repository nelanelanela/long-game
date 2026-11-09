# Update prompt 33 for Claude Code: the Saved moment on the new sunrise

Paste everything below the line into your Claude Code session in this folder.

---

The Timer's **Saved** moment (`SavedScene` in `LongGame/Features/Timer/TimerView.swift`) still draws the old violet `TimerSky`. Prompt 32 didn't cover it. Please read `design/redesign/TimerSaved.dc.html` and `design/redesign/TimerSavedCovered.dc.html`, then move it onto the new scene. Stay on the `redesign` branch.

**1. The scene continues from the session**
- The Saved moment uses the same layers as the running Timer (`TimerSunriseSky`, `TimerSunriseLand`, the glow, the sea and fills), not a new background.
- Use today's progress **after** saving: `p = TimerSunrise.progress(doneSaved: plan.doneSaved + this session, running: 0, target: plan.target)`. So the sky, sea and text colours are what the Timer would show with this session counted, and the sun sits at that sunrise height (centre y = 470 − 245p in the 844-pt layout). At p = 1 it's fully up.
- The water rule stays: the sea and the fills are opaque and in front of the sun, the burst and the glow at every frame.

**2. The animation (1.2 s, then dismiss at 1.4 s as now)**
- The sun shows the celebrate face, with `idle: false`, and jumps 36 pt up and back (`sin(q·π)`, q = 0…1 over 1.2 s).
- The glow behind it swells by up to 25% with the jump.
- `SaveBurst` stays as it is (eight mini suns and twelve petals), centred on the sun's current position instead of the old fixed 29% height. Anything below the horizon is hidden by the sea.
- The text fades in from 0.3 to 0.8 s.
- Success haptic and the "Session saved" announcement as now.
- Reduce Motion: no jump and no burst. The scene and text appear with a 0.3 s fade.

**3. Text, under the sea, centred at the Timer's text position**
- **Saved** (sheet title size, bold).
- "+40 m · today 1 h 05" (muted): the session's length and today's new total.
- One line in the gold/ember accent:
  - "40 m left of today's stretch", or
  - "Today's stretch covered." when this save reaches it.
- Colours mix with the sky exactly like the running Timer: white over the night and dawn, navy over the day; the accent mixes #FFD66B → ember.
- VoiceOver: one element, "Session saved. 40 minutes added. Today's stretch covered." (the last sentence only when it applies).

**4. Clean up**
- Delete `TimerSky.swift`. `SavedScene` was its last user.
- Search for any other place that still uses the old violet/plum colours (0x3A2F6B, 0x5E3A72, 0x7B4378, 0x5A3B72, 0x2C3466, 0x6E3D74) and tell me what you find before changing anything outside the Timer.
- Add the new strings to the String Catalog, with British spelling.

**5. Checks**
- Previews of the Saved moment at p = 0.2, 0.62 and 1, and with Reduce Motion on.
- A test that `p` after saving includes the session just saved, and that the "covered" line appears only when this save reaches the stretch.

This needs nothing from my Apple Developer account.

When you're done:
- build and run all the tests;
- update `docs/SPEC.md` (the Finish → Save row in "Animation: the sun's hour") and `docs/AUDIT.md`;
- tell me how to see the Saved moment in the Simulator, both before and after the stretch is covered.
