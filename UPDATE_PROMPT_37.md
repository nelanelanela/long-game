# Update prompt 37 for Claude Code: natural stars

Paste everything below the line into your Claude Code session in this folder.

---

The stars in `SkyView` (`LongGame/DesignSystem/Scene.swift`, `drawStars`) come from a modulo formula, so they sit on a visible grid and only come in two sizes. Please replace them with a natural star field, like a dark sky over the Alentejo. `design/redesign/Sky.dc.html` has the exact rule. Stay on the `redesign` branch.

**1. The rule** (put it in `Logic/StarField.swift` as a pure function returning stars with x, y, radius and class, so it can be tested and shared)
- **Seed:** `(round(w) × 73856093) XOR (round(h) × 19349663)`, as UInt32. Use the same mulberry32 generator as the design, so every sky size gets its own stars that never move or change between launches.
- **Area:** stars live above `top = h × horizon × 0.9`.
- **Count:** `n = clamp(round(w × top / 1500), 14, 170)`.
- **Position:**
  - 32% of stars fall in a soft Milky Way band, along the line from (0.08w, 0.02·top) to (0.98w, 0.97·top), offset by a gaussian of σ ≈ 0.1 × min(w, top). The gaussian is the average of three uniform numbers, as in the design.
  - The rest are uniform.
  - Reject points outside the area.
  - Thin towards the horizon: reject with probability `(y / top)² × 0.7`.
- **Brightness classes**, by a uniform `u`:

| `u` | Radius | Colour | Opacity |
| --- | --- | --- | --- |
| < 0.62 | 0.45 | white | 0.45 |
| < 0.88 | 0.65 | white | 0.70 |
| < 0.97 | 0.90 | white | 0.90 |
| otherwise | 1.30 | warm #FFF4D6 | 1.00 |

  Each radius is jittered by ×0.85–1.15. Multiply the opacities by 1 on night, 0.45 on dawn, 0 on day.
- **Draw order:** the stars, then the moon, as now.

**2. Everywhere stars appear**
- `SkyView` uses it on every screen: launch, Welcome, the empty day, The long game, the Timer, the year cards, widgets, the Live Activity, the Watch and the Mac.
- `Tools/MakeLaunchAssets.swift` uses the same function (or a copy of it) and regenerates the launch screen's night sky bitmaps, so the still launch frame matches the first animated frame exactly.
- The app icon keeps its five hand-placed stars.
- Session pictures keep their own seeded stars.

**3. Checks**
- Tests:
  - the same size always gives the same stars;
  - different sizes give different ones;
  - no star is below `top`;
  - roughly 62/26/9/3% across the classes over a large sample;
  - fewer stars in the bottom fifth than in the top fifth.
- Previews of the night and dawn skies at phone, widget and Watch sizes.

This needs nothing from my Apple Developer account.

When you're done:
- build and run all the tests;
- update `docs/SPEC.md` (the scene section) and `docs/AUDIT.md`;
- tell me where to compare the launch frame and Home's long game sky in the Simulator.
