# Update prompt 52 for Claude Code: more beautiful, more random clouds

Paste everything below the line into your Claude Code session in this folder.

---

The clouds in weather in the scene (update 49) are three copies of the same three-oval shape. Please replace them with natural, varied clouds. Read `design/redesign/HomeCloudy.dc.html` (Home on a cloudy morning) and the Cloud card on `design/redesign/SunMoods.dc.html`. Stay on the `redesign` branch. Only the cloud layer changes; rain, wind, mist and snow stay as they are.

## What a cloudy sky looks like
- **Two depths:**
  - **Far:** 2 or 3 small, flat clouds low in the sky, between 66% and 84% of the way down to the horizon, each 14–24% of the scene's width. They're fainter (about 60%), softer, and their undersides are warm (#EDDCD3) from the low sun.
  - **Near:** 1 to 3 larger clouds higher up, between 30% and 55% of the way down, each 24–40% of the width. Stronger (about 92%), cooler undersides (#DCDDEC).
- **Wisps:** 1 or 2 thin, long strokes high in the sky (6–30% down), 25–45% of the width, white at about 70% and very soft, with a shorter, fainter line just under each.
- Far clouds are drawn first, then near ones, then wisps.

## How each cloud is made
Every cloud is different, built from a seeded random generator (reuse the mulberry32 helper from the star field):
- **A row of 7 to 11 puffs** (circles) along a flat base line. Each puff's size follows two soft humps at random places along the cloud (one taller than the other), so the top is uneven, like a real cumulus. The puffs near the ends are smaller.
- **A few small puffs on top** of the two humps, about 60% as many as the first row, for texture.
- **A flat, soft base:** a wide, thin ellipse along the base line, and the bottom 20% fades out (a gradient mask), so there's no hard edge.
- **Shading:** a vertical gradient over the whole cloud: white at the top, warm white at 55%, #EBEAF2 at 85%, and the underside colour at the bottom. That gives them volume even on the cream sky.
- **Soft edges:** a blur of about 0.6 pt for near clouds and 1.4 pt for far ones.
- Draw each cloud as one path (union of the puffs and the base) in a `Canvas` layer with the blur and the gradient, not as separate shapes, so overlapping puffs don't show seams.

## Rules
- **The sun is never covered:** keep every cloud's and wisp's box at least 1.3 × the sun's ray radius from the sun's centre, wherever the sun is on its arc. If one would touch, slide it sideways away from the sun, and lift it a little; if it still touches, leave it out.
- **Random but steady:** seed the generator from the day (for example the date's day number), so the sky is different each day but doesn't jump when Home opens again.
- **Movement:** near clouds drift slowly side to side (about 28 pt over 40 s, ease in and out); far clouds drift the other way, slower (16 pt over 60 s). With Reduce Motion, they're still.
- **Dark look:** the same shapes in the moonlit pale blue already used (`LGColor.moonCloud`), at 70% strength, with no warm undersides.
- Keep the redraw at twice a second for the cloud layer, as now. Render the cloud shapes once into a cached image per day and only move them, so the blur isn't recalculated each frame.

## Tests
- The generator gives the same clouds for the same seed, and different ones for different seeds.
- Counts and size ranges stay within the limits above.
- No cloud or wisp touches the sun, for sun positions along the whole arc (morning to evening) and three different seeds.

This needs nothing from my Apple Developer account. Build, run the tests, and send me a screenshot of Home with the cloud layer forced (Settings › Debug only), on three different days.
