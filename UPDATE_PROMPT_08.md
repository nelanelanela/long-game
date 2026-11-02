# Update prompt 08 for Claude Code: Live Activity design

Paste everything below the line into your Claude Code session in this folder.

---

The Live Activity now has a proper design. Please read `docs/SPEC.md` section "Live Activity" (under Timer) and `design/LiveActivity.dc.html`, then update the Live Activity extension to match.

**Lock Screen**
- **Running:** a navy card with the focus sun showing this hour's lit rays, "Piano", the session clock counting up, and "3,294.7 h · next ray in 2:42". Pause and Finish buttons sit on the right, with a row of 12 thin segments underneath (gold = lit rays).
- **Paused:** the sleepy sun with dimmed rays, "Piano · Paused", the frozen dimmed clock, Resume (gold) and Finish.

**Dynamic Island**
- **Compact:** a small sun with lit rays on the left, and the clock in gold on the right.
- **Minimal:** just the small sun.
- **Expanded:** the focus sun, "Piano · this session" with the clock, Pause and Finish. Along the bottom, "3,294.7 of 10,000 h" in gold and "Next ray in 2:42".

**How it works**
- Draw the sun with the shared sun drawing (no face in compact and minimal) and the colours from the spec.
- The clock ticks by itself (`Text(timerInterval:)`). Only push updates when a ray lights, on pause/resume and on finish.
- Pause, Resume and Finish run as App Intents, without opening the app. Tapping elsewhere opens the Timer.
- End the activity when the session is saved or discarded, and after 12 h at the latest.
- Use `ActivityPreviews` (or `#Preview` for the widget) for all five presentations, so I can check them in Xcode.

When you're done: build, run the tests, and tell me how to see the Live Activity in the Simulator (lock the Simulator with ⌘L while a session runs).
