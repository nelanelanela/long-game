# Update prompt 43 for Claude Code: quicker logging — Undo, forgot to stop, controls, Watch add

Paste everything below the line into your Claude Code session in this folder.

---

Four small additions that save a step or fix a slip. Please read `design/redesign/QuickerLogging.dc.html`, which shows all four with their rules. Stay on the `redesign` branch, and build and test after each part. If a part turns out to need something from my Apple Developer account, stop and ask before doing it.

## 1 · Undo after saving
- The "added" toast on Home ("40 m added") gets an **Undo** button inside it: gold text on a slightly lighter pill, 44 pt touch target.
- It appears after a timer session is saved, after Add past hours, and after Catch up.
- It stays for 6 seconds. With VoiceOver running it stays until focus moves away, and the announcement is "40 minutes added. Undo, button."
- **Undo** deletes exactly what that save created (one session, or all the sessions Catch up added), with its note and photo, then the toast reads "Removed." for 2 seconds. Totals, the icon stage, widgets and notifications recompute as for any deletion.
- Not offered when the save opens a milestone celebration. The session can still be edited in History.
- Tests:
  - Undo removes only the sessions from that save;
  - Catch up's Undo removes all of its sessions;
  - no Undo after a milestone.

## 2 · Forgot to stop?
- In `Logic/`, add a pure function for the person's **usual session**: the median length of their last 20 timer sessions (not manual or catch-up ones). It needs at least 5; otherwise there is no usual.
- The Finish sheet shows a quiet card (peach #FFF1DA, radius 18) under the length when the session is **at least twice the usual and over 90 minutes**:
  - "A long one. Did the timer keep running?"
  - "Your sessions are usually about 45 m." (the usual, rounded to 5 minutes)
  - two choices side by side: **Keep 3 h 12** (selected by default) and **Use 45 m**.
- Nothing changes unless the person taps. **Use 45 m** sets the length to the usual; the stepper still adjusts it afterwards, and choosing Keep puts the measured time back.
- The card never appears for shorter sessions or without a usual. The 4-hour "Still practising?" notification stays as it is.
- VoiceOver reads the card as one element, then the two buttons with their selected state.
- Tests:
  - the usual (fewer than 5 sessions, odd and even counts, manual sessions ignored);
  - the two thresholds;
  - Use and Keep.

## 3 · Begin without opening the app
- **App Intents:** `BeginSessionIntent` (starts the timer for the current craft and its Live Activity; make it a `LiveActivityIntent` so it can start the activity from the background) and `PauseResumeSessionIntent`. Reuse the intents the Live Activity buttons already use where they exist, and keep all timer changes going through `TimerStore`.
- **Control** (iOS 18 and later, behind `if #available`): one `ControlWidgetToggle` in the widget extension, "Long Game".
  - Idle: the sun, "Begin". A tap begins a session.
  - Playing: the craft's name and the running clock, tinted gold. A tap pauses; a tap again resumes.
  - It works in Control Centre and on the Lock Screen.
- **Shortcuts:** an `AppShortcutsProvider` with "Begin a session" and "Pause session", so they appear for the Action Button, Siri and Spotlight. Phrases: "Begin a session in Long Game", "Start practising in Long Game", "Pause my Long Game session".
- Finishing isn't offered here. It stays on the Live Activity and in the app, where the note and photo are.
- With no craft set up yet, the control and shortcuts open the app instead.
- Starting this way never shows a permission prompt.
- Tests for the intents' effect on the timer state (begin when idle, begin when already running does nothing, pause and resume).

## 4 · Add time on the Watch
- A **+** button on the Watch app's main screen opens **Add time**:
  - the amount in large gold numbers ("30 m"), changed with the Digital Crown in steps of 5 minutes (5 minutes to 8 hours), with a haptic click per step;
  - the caption "today · turn the Crown";
  - three quick picks: 15 m, 30 m, 1 h;
  - **Add 30 m** (the button names the amount).
- It saves hours added for today (source: manual), sent to the iPhone through the same queue as a session finished on the Watch, with its own id so it is never saved twice.
- After adding: a success haptic, back to the main screen, and "30 m added" with **Undo** for 6 seconds.
- Keep the phone's daily limit: if today would pass 12 hours in total, the button is disabled and reads "That's more than a day holds".
- VoiceOver: the amount is an adjustable element ("30 minutes, adjustable").

## Text and docs
- All new text goes in the String Catalogs (iPhone, Watch, widgets), with British spelling.
- Update `docs/SPEC.md` (Home's toast, the Finish sheet, a new "Controls and shortcuts" section, the Watch) and `docs/AUDIT.md`.

When you're done:
- build and run all the tests;
- tell me how to try each one in the Simulator:
  - Undo;
  - a long session (a debug way to fake 3 hours);
  - the control in Control Centre;
  - Add time on the Watch.
