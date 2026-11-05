# Update prompt 16 for Claude Code: scrub the forecast

Paste everything below the line into your Claude Code session in this folder.

---

The Growth chart can now open full screen and be scrubbed with a finger, with a light tap at each milestone. Please read these parts of `docs/SPEC.md`:
- the new section **"19 · Scrub the forecast — full-screen Growth chart"**;
- the new bullet in "6 · History — Growth";
- `scrubHintSeen` in Settings.

Also read `design/GrowthScrub.dc.html`. Then implement it.

**1. Logic** (pure functions in `Logic/`, with tests)
- `milestoneDates`: for 1,000, 2,500, 5,000, 7,500 and 10,000 hours, return either:
  - the day the running total first reached it, flagged as an estimate when it falls within the onboarding estimate (from before tracking began); or
  - the forecast month when it's still ahead, using the current forecast and the "What if I practise more?" extra hours.
- `curvePoint(at date)`: the hours at any date on the past line or the forecast, for snapping the scrub dot.
- `crossedMilestone(from:to:)`: which milestone, if any, lies between two scrub positions in either direction, including Today.
- **Tests:**
  - milestones reached by the onboarding estimate, by logged hours, and still ahead;
  - a milestone exactly on Today;
  - scrubbing left and right;
  - a forecast "Not within 30 years" (show no future dates beyond it);
  - the slider's extra hours.

**2. Opening and closing**
- Add a small expand button (a 36 pt circle in the chart card's top right) to the Growth chart card. It and a tap on the chart both open a full-screen cover, with matched geometry over 0.4 s.
- Close with ✕ or a swipe down.
- Support portrait, landscape and wide windows (iPhone Duo open, iPad).

**3. The full-screen chart**
- Reuse the card's Swift Charts code, with the same colours and parts, larger, and y labels at 0 / 2.5k / 5k / 7.5k / 10k.
- Draw the milestone dots: filled navy when reached, outlined orange when ahead. The sun marks 10,000.
- Draw-in on open, with the timings from the spec. With Reduce Motion, use a 0.2 s fade instead.
- The hint capsule "Drag along the line" disappears for good after the first scrub (`scrubHintSeen`).

**4. Scrubbing**
- Use `chartXSelection(value:)`. Dragging starts straight away, with no long press.
- A navy vertical line and a white dot with a navy ring snap to the curve.
- The headline and the floating label show exactly the texts in the spec for past, future and milestone points. The label flips side so it's never off screen or under the finger.
- After the finger lifts, keep the point for 1.5 s, then fade back to the idle headline.
- Haptics:
  - crossing a milestone: a light impact, plus a 0.4 s gold ring around its dot;
  - crossing Today and reaching either end: a selection tick;
  - nothing else;
  - only when system haptics are on.
  - Use `sensoryFeedback` keyed on the milestone index, so a tap never repeats while the finger rests on a milestone.

**5. Accessibility**
- An Audio Graph via `accessibilityChartDescriptor`.
- An adjustable action that steps through Start → each milestone → Today → Finish line, reading the headline text.
- The close button reads "Close chart".
- Dynamic Type for the headline and label.
- All new text goes in the String Catalog, with British spelling, and dates formatted for the user's locale.

**6. Checks**
- Add previews in portrait, landscape and wide windows, scrubbed at a past milestone, Today and a future milestone.
- Try it with a forecast that is "Not within 30 years".
- Build, run all the tests and update `docs/AUDIT.md`.

When you're done, tell me how to try it in the Simulator. The Simulator has no haptics, so feeling the milestone taps needs a real iPhone. This needs nothing from my Apple Developer account.
