# Update prompt 15 for Claude Code: the sun laughs when tapped

Before you paste this: put the laugh recordings into the new `Sounds/giggles/` folder in this project, in any format.

Paste everything below the line into your Claude Code session in this folder.

---

We're adding a small secret: tapping the sun makes it laugh like a baby. Please read the new section **"18 · The sun laughs when tapped"** in `docs/SPEC.md` and `design/SunGiggle.dc.html`. Its CSS keyframes show the motion. Then implement it.

**1. The sounds**
- Use the recordings in `Sounds/giggles/`. They're real laughs from my daughter, so treat them with care and never upload them anywhere.
- For each recording:
  - trim it to one clean laugh of about 1 second (1.5 s at most), with a short fade-out;
  - match the loudness across all the clips;
  - convert it with macOS's built-in `afconvert` (no new tools) to AAC `.m4a`;
  - save it as `LongGame/Resources/Sounds/giggle-1.m4a`, `giggle-2.m4a` and so on.
- Keep the longest, biggest laugh as the one for the five-tap laugh.
- Show me the list of clips with their lengths before you continue.
- Leave the originals in `Sounds/giggles/`, and make sure they aren't added to the app target.

**2. The sound player** (`DesignSystem/` or a small `Sound/` folder)
- Write a `GiggleSoundPlayer` that:
  - preloads the clips with `AVAudioPlayer`;
  - picks one at random, never the same twice in a row;
  - plays at volume 0.7;
  - never plays two at once.
- Use an `AVAudioSession` with category `.ambient`, so the sound:
  - is silent when the Ring/Silent switch is on silent;
  - mixes with other audio and never stops or ducks the user's music.
  - Skip the sound when `secondaryAudioShouldBeSilencedHint` is true.
- Add the Settings switch **Giggle sound** (on by default) in a small "Sounds" group. When it's off, don't touch the audio session at all.

**3. The animation: a baby's laugh**
- Add two faces to `SunView`:
  - **gasp:** wide eyes with highlights and a round "o" mouth;
  - **baby laugh:** eyes as happy upward crescents ^ ^, a big open mouth with a pink tongue and round cheeks.
- Reuse the happy face for the end.
- Build the sequence from the spec's timing table:
  - the gasp (stretch up);
  - the belly laugh: tipped back 5°, with five quick squash-and-stretch bounces, each smaller, rays jiggling along and four sparkles;
  - a contented settle with one tiny hiccup.
- Use `keyframeAnimator`. Don't use timers for state.
- The sun's position on the gauge or arc must not change. The sea and its mask stay in front at every frame.
- Haptics: soft at the gasp, then light on the first three bounces, each softer. Only when system haptics are on.
- Tapping again:
  - A tap during the laugh adds two more bounces instead of restarting.
  - Only start a new laugh sound once the current one has finished.
  - Five taps within 2 s give the long belly laugh (eight bounces, the longest clip) and one full spin of the rays.
  - Then a 3 s rest when taps only get the wink.

**4. Where it works**
- It works on Home (all three tabs), the intro pages, the future-self sheet and the tip jar.
- On the Timer, a tap only gets a soft wink, with no sound and no wiggle.
- Nothing happens in widgets, the Watch, the Live Activity or the year card image.

**5. Accessibility**
- With Reduce Motion: the baby-laugh face for 0.8 s, with the haptic and sound but no movement.
- VoiceOver: add the custom action "Tickle the sun".
- All new text goes in the String Catalog.

**6. Tests**
- The tap logic: extra bounces on a repeat tap, no overlapping sounds, the 5-taps-in-2-s long laugh, the 3 s rest, and never the same clip twice in a row.
- The rule that the setting being off means no audio session.
- Previews of every frame of the sequence.

When you're done:
- build and run all the tests;
- update `docs/AUDIT.md`;
- tell me how to try it.

The Simulator plays sound through the Mac, but the Ring/Silent switch can only be tested on a real iPhone. This needs nothing from my Apple Developer account.
