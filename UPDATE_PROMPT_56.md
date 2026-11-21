# Update prompt 56 for Claude Code: one clearer line on the weather invite

Paste everything below the line into your Claude Code session in this folder.

---

On the **Bring the weather in?** sheet (update 53, part 7), the first row's title "Only in the landscape" reads like landscape orientation. Please change it. Read `design/redesign/WeatherInvite.dc.html` again from disk. Stay on the `redesign` branch.

- Row 1 title: **Only the scenery changes** (was "Only in the landscape").
- Row 1 text stays: "The sun's height and the sky still show your progress."
- Make the same change anywhere else this row appears, for example in Settings under the Weather in the scene switch, if it's reused there.
- Update the String Catalog (remove the old string), `docs/SPEC.md` and the accessibility UI test's expected reading order for this sheet.

The board now also shows Home · Today dimmed behind the sheet. That's only so the mock-up reads right; the app already shows the sheet over Home, so nothing changes there.

This needs nothing from my Apple Developer account. Build, run the tests, and commit with a clear message.
