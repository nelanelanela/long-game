# Update prompt 18 for Claude Code: − and + instead of sliders

Paste everything below the line into your Claude Code session in this folder.

---

Choosing hours with sliders is fiddly, so every hours picker becomes a stepper with − and + buttons. Please read these parts of `docs/SPEC.md`:
- the new section **"Steppers for choosing hours"**;
- the updated steps 2, 3 and 3b;
- Catch-up screens 11 and 12.

Also read `design/Steppers.dc.html`. Then implement the following.

**1. Two shared components in `DesignSystem/`**
- `HoursStepperRow`:
  - a label (with an optional sub-line) on the left, then a 36 pt round − button, the value, and a 36 pt + button;
  - each button has at least a 44 pt touch area;
  - an `isHighlighted` style puts #FFF3D6 behind the value.
- `HoursBigStepper`:
  - 56 pt − and + buttons either side of the big number and the unit under it, with optional quick-pick chips (used only on Catch-up screen 12).
- Both components share the same behaviour:
  - **Tap:** one step, with a selection haptic.
  - **Hold:** after 0.4 s, repeat 6 steps a second; after 1.5 s, 12 a second; stop when released. Drive this from the press state, not a stray timer that can keep running.
  - **At a limit:** a rigid haptic. The button turns pale and does nothing, but stays focusable.
  - **Tap the number:** open the small entry sheet with the label, the value, "0 to 40", **Done** and a number pad (a decimal pad for 0.5 steps). Snap out-of-range values to the limit; empty means unchanged.
  - **VoiceOver:** one adjustable element per stepper ("2023, 10 hours a week"), with the buttons hidden from VoiceOver. It says "Minimum" or "Maximum" at the limits.
  - **Dynamic Type:** at accessibility sizes, the label moves above the − value + group.
  - **iOS 26+:** the round buttons use the Liquid Glass styles from `DesignSystem/` if they exist yet. Otherwise use the flat fills from the spec.

**2. Replace the sliders**
- Step 2's current-year row and step 3's yearly rows: use `HoursStepperRow` with steps of 1 h, from 0 to 40.
  - Highlight the year being changed.
  - After a change to a year that has later years, show "Use N h for the years after YYYY". It copies that value to every later year.
- Step 3b, Your pace for the year:
  - use `HoursBigStepper` with steps of 0.5 h, from 1 to 40;
  - no quick-pick chips;
  - add the hint line from the spec.
- Catch-up screen 11: one `HoursStepperRow` per week block, with steps of 1 h from 0 to 40.
- Catch-up screen 12: `HoursBigStepper` with steps of 1 h from 0 to 40, and quick picks "Your usual · N", 0, 5 and 10.
- Keep the "What if I practise more?" slider on Growth as it is.
- Remove any slider code that is no longer used.

**3. Tests**
- The step maths for both step sizes, with clamping at each limit.
- The typed-value parsing: empty, out of range, and a decimal comma or point depending on the locale.
- The hold-to-repeat speeds, with an injected clock.
- "Use N h for the years after" copying to the later years only.
- Quick picks setting the value.

**4. Checks**
- Add previews of both components at default size and at AX5, at both limits, and over the Timer's night sky if a stepper appears there later.
- Build, run all the tests and update `docs/AUDIT.md`.

When you're done, tell me how to try each screen in the Simulator: onboarding, the pace screen from This week, and the Catch-up screens through the debug option. This needs nothing from my Apple Developer account.
