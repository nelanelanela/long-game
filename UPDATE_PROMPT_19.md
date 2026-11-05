# Update prompt 19 for Claude Code: make the sun laugh like a baby

Only use this if you already ran prompt 15 (the giggle). If you haven't, just run prompt 15: it already includes this.

Paste everything below the line into your Claude Code session in this folder.

---

The sun's tap animation has been redesigned to look like a baby laughing. Please re-read section **"18 · The sun laughs when tapped"** in `docs/SPEC.md` and `design/SunGiggle.dc.html`. Its CSS keyframes show the new motion. Then update what prompt 15 built.

**Faces**
- Replace the > < laughing face with the **baby laugh**: eyes as happy upward crescents ^ ^ (6 pt stroke), a big open mouth with a pink tongue, and round cheeks (r 11, #F48FA8).
- Add the **gasp** face: wide eyes with highlights and a round "o" mouth.
- Remove the wink at the end. The sequence ends on the happy face with eyes closed.

**Motion** (follow the spec's timing table exactly)
1. **Gasp** (0–0.10 s): stretch to 94% × 108%, up 4 pt.
2. **Belly laugh** (0.10–0.90 s):
   - tilt back 5°;
   - five bounces of 0.16 s, each a little smaller: squash 106% × 94%, down 3 pt, then stretch 97% × 104%, up 5 pt;
   - rays jiggling with the bounces;
   - four sparkles.
3. **Contented** (0.90–1.25 s): spring back, one tiny 2 pt hiccup at 1.05 s, and the blush fades.
- Replace the old side-to-side wiggle completely. The sun now moves at most 6 pt and tilts at most 5°.

**Feel and sound**
- The laugh sound now starts at 0.10 s, after the gasp.
- Haptics: soft at the gasp, then light on the first three bounces (0.12, 0.28 and 0.44 s), each softer.

**Tapping again**
- A tap during the laugh now adds two more bounces instead of restarting.
- Five taps within 2 s give the long belly laugh: eight bounces, the longest clip and one spin of the rays.
- Then the 3 s rest, as before.

**Reduce Motion:** the baby-laugh face for 0.8 s, with haptic and sound but no movement.

**Checks**
- Update the previews (one per phase) and the tests for the new repeat-tap rule.
- Confirm the sea still covers the sun at every frame.

When you're done, build, run the tests and tell me how to try it.
