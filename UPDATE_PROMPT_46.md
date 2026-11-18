# Update prompt 46 for Claude Code: Write to us, in Settings

Paste everything below the line into your Claude Code session in this folder.

---

Add a way to email us from Settings. Please read `design/redesign/Settings.dc.html` (the new **Help** group above the footer). Stay on the `redesign` branch.

**1. The row**
- A new **Help** group, after Your game and before the footer, with one row:
  - an envelope icon (`envelope`) in ember on a peach tile (#FFF1DA, radius 8, 32 pt);
  - **Write to us**;
  - the subtitle "yes@wehavesun.com · questions, ideas, bugs";
  - a chevron.
- Keep the address in one constant (`Support.email = "yes@wehavesun.com"`) so it's easy to change.
- Mac and iPad Settings get the same row.

**2. What a tap does**
- **iPhone and iPad:**
  - If the device can send mail (`MFMailComposeViewController.canSendMail()`), open the Mail compose sheet with:
    - the address filled in;
    - the subject "Long Game";
    - a short body: two empty lines, then a quiet footer "—", "Long Game 1.0 (42) · iOS 26.1 · iPhone 16". Use the real app version, build, iOS version and device model, so bug reports come with context. No other data.
  - Otherwise, try a `mailto:` URL with the same subject and body (this opens Gmail or another mail app if the person set one as default).
  - If neither works, copy the address to the clipboard and show the app's toast: "Email address copied". A soft haptic.
- **Mac:** open the `mailto:` URL. If no mail app answers, copy the address and show the same toast.
- After Mail closes, nothing else happens: no "thank you" screen.

**3. Accessibility and text**
- VoiceOver for the row: "Write to us, yes@wehavesun.com, button".
- After copying, post the announcement "Email address copied".
- All new text goes in the String Catalog, with British spelling.

**4. Tests**
- A small pure function that builds the footer line from the version and device values.
- The fallback order: Mail sheet, then `mailto:`, then copy. Put the decision behind a protocol so it can be tested without a device.

This needs nothing from my Apple Developer account.

When you're done:
- build and run all the tests;
- update `docs/SPEC.md` (Settings) and `docs/AUDIT.md`;
- tell me how to test both paths in the Simulator. The Simulator has no Mail account, so it will show the copy path.
