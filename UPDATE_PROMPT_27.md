# Update prompt 27 for Claude Code: a readable key for the Growth chart

Paste everything below the line into your Claude Code session in this folder. Everything Claude Code needs is written out here. If prompt 26 hasn't been run yet, run it first.

---

The labels drawn next to the forecast lines on the Growth chart can't be read when the two lines are close together. Move them into a key, and rename the second line. Re-read `docs/SPEC.md` ("6 · History — Growth", "19" and "Forecast algorithm") and `design/Growth.dc.html` and `design/GrowthScrub.dc.html` from disk; they were just updated.

**1. No text on the chart lines**
- Remove the "Your pace" and "Recent pace" labels, and any other text that sits on or next to the forecast lines, from the Growth card and the full-screen chart.
- Keep the "Finish line · 10,000 h" label, the axis labels, "Today" and the sun.

**2. A key, separate from the chart**
- Growth card: under the chart, above a hairline, two rows at 12 pt.
- Full-screen chart: between the headline and the chart, at 13 pt.
- Each row has:
  - a short sample of its line, 26 pt wide, drawn with the same stroke as the chart;
  - the name;
  - the numbers on the right, in #5E6782 with tabular figures.

| Line sample | Name | Numbers |
| --- | --- | --- |
| dashed orange (#EE6420, dash 6–5) | **Your chosen pace** (semibold, #C2531A) | 12 h a week · Nov 2035 |
| dotted grey (#9AA1B5, dash 1–6, round caps) | **Your actual pace** (semibold, #5E6782) | 9.5 h a week · 2039 |

- The numbers are live:
  - the chosen pace plus any What-if extra, and its finish month;
  - the actual pace, and its finish year, or "after YYYY" beyond 30 years.
- The key is one VoiceOver element: "Your chosen pace, 12 hours a week, finishes around November 2035. Your actual pace, 9.5 hours a week, finishes around 2039."
- At accessibility text sizes, the numbers wrap under the name.

**3. Wording**
- "Recent pace" becomes **"Your actual pace"** everywhere:
  - the headline line "At your actual pace: around 2039";
  - "You're already playing at this pace" when it's equal or faster;
  - VoiceOver, strings and code names (for example `recentPace` → `actualPace`).
- Don't call it "rhythm": Rhythm already means practice days per week in History.

**4. Checks**
- Add previews where the two lines almost overlap (actual pace 11.5, chosen 12) and far apart (4 and 12), at default size and at AX5.
- Build and run the tests.
- List the files you changed.
