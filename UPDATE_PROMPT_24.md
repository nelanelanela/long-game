# Update prompt 24 for Claude Code: "to the moon", not a resting place

Paste everything below the line into your Claude Code session in this folder. Everything Claude Code needs is written out here.

(This replaces an earlier version of prompt 24 that swapped the moon for a flag. If you already ran that version, this one puts the moon back.)

---

Today's stretch should be about moving forward, never about resting. **Keep the moon**, but change the words around it. Make the changes everywhere they appear: the Home **Today** tab, VoiceOver, the String Catalog, previews and tests. Re-read `docs/SPEC.md` section "4c · Today" and `design/HomeToday.dc.html` from disk; both were just updated.

**1. The picture**
- Keep the small **pale-blue moon** (#C9D3EC) on the horizon at the right end of the arc.
- If it was replaced by a gold flag, put the moon back.
- The sun walks the arc towards the moon. Reaching the moon means today's stretch is done.

**2. The words** (update the String Catalog keys and values; remove the old strings)

| Where | Old | New |
| --- | --- | --- |
| Today, quiet line | 40 m to today's resting place (or "to today's goal") | 40 m to the moon |
| Today, when covered | (any "resting place" wording) | You reached the moon. |
| VoiceOver, Today | …of the way to today's resting place… | …of the way to the moon… |
| Not a practice day: big text | Rest day | Free day |
| …under it | The sun's taking it easy too | Not one of your usual days |
| …quiet line | Playing anyway? Every minute still counts. | Playing anyway brings your future a little closer. |
| …after playing on that day | a rest-day bonus | a step ahead |
| VoiceOver, that day | Rest day. The sun is resting on the horizon. | Free day, no stretch today. Playing anyway brings your future closer. |

- On a free day when you play anyway, the sun moves along the arc as if the stretch were 30 minutes, instead of staying on the horizon.
- Rename code identifiers so nothing says "resting" or "goal" for the stretch:
  - for example, `restingPlace` or `todayGoal` → `moon`;
  - the `TodayStretch` state `.restDay` → `.freeDay`;
  - update the tests to match.
- The calendar's "Rest" legend and its rest-day colour stay as they are: they describe past days.

**3. Checks**
- Search the whole project, case-insensitively, for "resting", "today's goal", "flag" and "taking it easy". Confirm nothing is left in code, strings, previews or tests, apart from the calendar's rest days.
- Update the previews of the Today tab: in progress, covered, week covered, free day, and free day while playing.
- Build and run the tests.
- List the files you changed.
