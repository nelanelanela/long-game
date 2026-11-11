# Update prompt 39 for Claude Code: a slower opening sunrise

Paste everything below the line into your Claude Code session in this folder.

---

The opening sunrise (spec section 21, `Logic/OpeningSunrise.swift`) plays in about 1 second, which is too fast to enjoy. Please slow it to about 2.2 seconds, keeping the same steps, curves and order. Stay on the `redesign` branch.

**1. The new timings** (`OpeningTimeline`)

| Phase | Now | New |
| --- | --- | --- |
| Night held still (`OpeningCenter.lead`) | 0.4 s | 0.4 s (unchanged) |
| Sunrise: sky and land fade to dawn, the sun rises 120 pt | 0–0.5 s | 0–1.1 s |
| The sleeping sun wakes (rays light up, the "z" goes) | 0.25–0.42 s | 0.55–0.92 s |
| Good morning: eyes open… | 0.5–0.54 s | 1.1–1.18 s |
| …and close again | 0.61–0.65 s | 1.32–1.4 s |
| Settle: the sun glides and shrinks onto Today's arc | 0.65–1 s | 1.4–2.2 s |
| The scene fades out and Home shows underneath | 0.75–1 s | 1.62–2.2 s |

- Set `sunrise = 1.1`, `glideStart = 1.4` and `total = 2.2`. `boardTime(_:)` already maps the board's percentages onto those three phases, so the wake, eye and fade moments follow by themselves. Check they land on the values in the table.
- Keep every curve: ease-in-out for the fades, `cubic-bezier(.45,0,.25,1)` for the rise and the glide.
- The short version for Reduce Motion and VoiceOver stays a 0.3 s cross-fade.
- A tap anywhere still skips straight to Home. The safety timer in `AppRoot` (`duration + lead`) follows `total` automatically.
- Home must be ready under the fade as now (no flash, the sun hands over to Home's own sun).

**2. Words and docs**
- Update the comments in `OpeningSunrise.swift` (the table of board times) and `docs/SPEC.md` section 21: the sunrise is 0–1.1 s, good morning 1.1–1.4 s, settle 1.4–2.2 s. Replace "The whole opening is never longer than about 1 second" with "The whole opening takes about 2 seconds, and a tap skips it."
- The orange note next to the Launch board in the design says "about 1 second"; it has been updated to the new timings.

**3. Tests**
- Update the `OpeningTimeline` tests to the new times:
  - the night frame at 0;
  - fully awake by 0.92 s;
  - eyes fully open at 1.2 s and closed at 1.4 s;
  - the glide half done at about 1.8 s;
  - nothing of the scene left at 2.2 s.
- Check on a real device or a Simulator that the first frame still matches the launch screen exactly.

This needs nothing from my Apple Developer account.

When you're done:
- build and run all the tests;
- update `docs/AUDIT.md`;
- tell me how to replay the opening without restarting the app (the debug Replay option).
