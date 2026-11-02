# Update prompt 06 for Claude Code

Paste everything below the line into your Claude Code session in this folder. It covers everything in update prompts 04 and 05 plus the latest text and water fixes, so you only need this one.

---

The design and spec have been updated. Please re-read `docs/SPEC.md` (sections "0a–0c · How the game works", "4 · Home / Progress" and "13 · Meet your future self"). Also read these files in `design/`: `Welcome`, `Intro1`, `Intro2`, `Intro3`, `Home` and `FutureSelf` (`.dc.html`). Their CSS keyframes are the reference for the animation timings. Then implement the following.

**1. Onboarding intro: "How the game works"**
- **Pages:** add three swipeable pages between Welcome and "What's your game?". Get started on Welcome now opens them.
- **Controls:** each page has a back chevron, **Skip** (goes straight to "What's your game?"), an illustration, a title, a short paragraph, page dots and one primary button. Use the exact titles, text and buttons from the spec table.
- **Illustrations:**
  - Page 0a: the sun high above the sea, with a dashed gold "Finish line · 10,000 hours" line above it.
  - Page 0b: the sun just rising out of the sea, with a white chip "Your starting score · 3,208 h" (show the real estimate once known).
  - Page 0c: the sun with 8 of 12 rays lit and a navy chip "+1 h today".
- **When they show:** only in first onboarding, not after "Switch to a new game".

**2. Animated Home hero**
- A soft warm glow behind the sun.
- The sea and its navy wave line drift right together, and the pale wave drifts left, each as a seamless loop. Four small gold glints sparkle on the water.
- The sun breathes, its rays turn slowly, and every 7 seconds it opens both eyes for a short peek.
- Use the timings in the spec table. Pause the animation when Home isn't on screen.
- Reuse the same sun and sea components on the intro pages and the future-self sheet.

**3. The water must completely cover the sun (strict rule)**
- Layer order, back to front: glow → sun → sea fill → pale wave → navy wave line → glints.
- The sea is one closed, fully opaque `Shape` whose top edge is exactly the navy wave path. Use the same phase, moved by the same offset.
- Also mask the sun to the area above the wave path, so nothing of it can show between the crests.
- No transparency, glow or alpha gradient inside the sea. The fade into the background at the bottom goes on top of the sea.
- Check it in SwiftUI previews frozen at several wave phases, at 0% and 100% progress and at large Dynamic Type, on Home, the intro pages and the future-self sheet. Confirm no yellow shows below the waterline anywhere.

**4. "Meet your future self" row and sheet**
- **Row:** on Home, under the stats, add a small risen-sun icon, "Meet your future self", "Where 10,000 hours can take you" and a chevron. It opens the sheet.
- **Sheet:** the sun rising into place over the animated sea, the title "Meet your future self" and these two paragraphs:
  - "Long Game is a projection of you into the future. Every hour you add brings that person a little closer."
  - "Dreaming of turning your passion into a career? 10,000 hours is where that starts to become realistic, whenever you begin. In a well-known study of musicians, what set the professionals apart wasn't talent but the hours they had put in. And you're not starting from zero: every hour you've already practised counts."
- Below them, a progress track from today's total to the forecast finish date, the note "Hours aren't a guarantee, but they're the part you control." and a **Keep playing** button.
- Show the sheet once automatically the first time Home appears after onboarding (store it in Settings, e.g. `futureSelfShown`).

**General**
- All text goes in the String Catalog.
- Support Reduce Motion (show the still versions), VoiceOver ("Page 1 of 3", labels on the illustrations) and Dynamic Type (the intro text scrolls if needed).
- If prompts 04 or 05 were already applied, update what's there to match this prompt rather than duplicating anything.

When you're done: build, run the tests, and tell me what changed and how to see each part in the Simulator. Add debug options to reset onboarding and to show the future-self sheet again.
