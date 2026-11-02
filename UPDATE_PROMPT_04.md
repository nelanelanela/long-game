# Update prompt 04 for Claude Code

Paste everything below the line into your Claude Code session in this folder.

---

Home has a livelier hero and there's a new sheet. Please re-read `docs/SPEC.md` (sections "4 · Home / Progress" and "13 · Meet your future self") and the files `design/Home.dc.html` and the new `design/FutureSelf.dc.html` (their CSS keyframes are the reference for the timings). Then:

**1. Animated Home hero**
- A soft warm glow behind the sun.
- The sea is an opaque shape with the navy wave as its top edge and a soft blue-to-background vertical gradient, so the sun is never visible through the water. The sea and navy wave drift right together, the pale wave drifts left, each as a seamless loop. Small gold glints sparkle on the water under the sun, but there's no glow in the water: nothing of the sun may show below the waterline.
- The sun breathes, its rays turn slowly, and every 7 seconds it opens both eyes for a short peek.
- **The water must completely cover the lower part of the sun.** Follow the "Water must cover the sun" rule in the spec:
  - Draw the sea as one closed, fully opaque shape whose top edge is exactly the navy wave path.
  - Put it in front of the sun.
  - Also mask the sun to the area above the wave path.
  - No transparency or gradient-with-alpha in the sea fill itself.
  - Check it in a SwiftUI preview frozen at several wave phases and at 100% and 0% progress, and confirm no yellow shows below the waterline.
- Use the timings in the spec table. Pause everything when Home isn't on screen. With Reduce Motion, show the still version.

**2. "Meet your future self" row and sheet**
- Add the row under the stats on Home (small risen-sun icon, title, subtitle, chevron). It opens the new sheet.
- The sheet has the risen sun over the animated sea (the sun rises into place when it opens), the title and the two paragraphs from the spec, and a progress track from today's total to the forecast finish date.
- It also has the small "Hours aren't a guarantee…" note and a **Keep playing** button.
- Show the sheet once automatically the first time Home appears after onboarding. Store that in Settings, e.g. `futureSelfShown`.
- Put all the text in the String Catalog.

When you're done: build, run the tests, and tell me how to see both in the Simulator. Add a debug option to show the future-self sheet again.
