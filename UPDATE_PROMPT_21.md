# Update prompt 21 for Claude Code: lighter onboarding, iCloud instead of Sign in with Apple, no stretch banner

Paste everything below the line into your Claude Code session in this folder. Do it in three parts, and check each part in the Simulator before the next.

---

The main flow has been consolidated, so please re-read `docs/SPEC.md`. The parts that changed:
- "Screens";
- 0 Welcome, including Welcome back;
- 0a–0c;
- steps 1, 2, 3, 3b and the new **3c Keep your game safe**;
- "Accounts, sync and notifications";
- the Settings line;
- "Today's stretch on the Timer";
- the Liquid Glass table.

The `design/` files with the same names are the reference. The new ones are `WelcomeBack`, `ICloud`, `HomeToday`, `YourYear` and `FinishSheet`. The "details" boards (TodayStretch, OnboardingLight and the others) explain each feature.

**Part 1 · Lighter onboarding** (text and layout only)
- Use the exact new copy from the spec on Welcome, the three intro pages, and steps 1, 2, 3 and 3b. Each screen has one title and at most one short line.
- Welcome: remove the "I already have an account" button.
- Step 1 "What's your game?": suggestions as chips under small group labels, with no subtitle.
- Step 2: a big − / + year stepper with "A rough guess is fine."
- Step 3: title "Hours a week, each year", no subtitle. "Your starting score" sits under the card.
- Step 3b, during onboarding:
  - title "Your weekly pace", with one line under it;
  - no hint line;
  - remove the quick-pick chips under the pace stepper, both in onboarding and when it's opened from This week;
  - replace the Until / About / In a year card with one quiet line: "About 1 h 43 m a day · until Nov 2027".
  - Opened from This week, it keeps the title "Your pace for the year" and the **Save** button.
- The step dots now show 5 steps.
- Update the String Catalog and remove strings that are no longer used.

**Part 2 · iCloud alone, no Sign in with Apple**
- Remove Sign in with Apple completely:
  - the code and any `AuthenticationServices` usage;
  - the entitlement;
  - its Settings rows;
  - its strings and tests.
  - Tell me if anything in my Apple Developer account should be cleaned up too.
- **Step 3c "Keep your game safe"** (the new last onboarding step):
  - a card with the iCloud icon, **Save to iCloud**, its line, and a switch that is on by default;
  - the privacy line under the card;
  - **Start playing** saves the choice and opens Home on The long game, once.
  - If `CKContainer.default().accountStatus()` isn't `.available`, the switch is off and disabled, and the card shows "Sign in to iCloud in the Settings app to keep a copy."
- **Sync:**
  - Use the SwiftData + CloudKit private database (`ModelConfiguration(cloudKitDatabase:)`), only when `Settings.iCloudEnabled` is true. Otherwise the store is local only.
  - Switching the setting rebuilds the model container safely, without losing data.
  - Keep "last edit wins per session" and "a running timer is device-local".
- **Settings:** replace any account rows with an **iCloud** group:
  - the **Save to iCloud** switch;
  - a status line: "Up to date", "Syncing…", "Last synced 10:42", or the sign-in hint;
  - **Delete iCloud copy**, with a confirmation, that removes only the iCloud data and leaves the data on this device.
- **Welcome back** (`design/WelcomeBack.dc.html`): on first launch, check iCloud quietly for an existing Long Game, for at most 3 s. If one is found, show "Welcome back · We found your game in iCloud · Piano · 3,294 hours" with:
  - **Continue my game:** restore it and open Home;
  - **Start a new game:** normal onboarding, with the iCloud game archived, not deleted.
- **Ask me first:** adding the iCloud / CloudKit capability and container (for example `iCloud.com.wehavesun.LongGame`) needs my Apple Developer account. Stop and tell me exactly what to click before you change signing or capabilities. Until then, keep everything working locally behind the setting.
- **Tests:**
  - the setting off means a local-only store;
  - the account-status states;
  - "Delete iCloud copy" leaves the local data;
  - the Welcome back decision when a game is found, not found, or the check times out.

**Part 3 · No stretch banner on the session screen**
- Remove the today's-stretch strip from the Timer, and its Liquid Glass style.
- Keep only:
  - the sun's single wink;
  - the quiet gold line "Today's stretch covered" under "Next ray in" when the stretch is covered during the session;
  - the line in the Finish sheet.
- Remove the now-unused strip views, strings and tests, and update the previews.

When all three parts are done:
- build and run all the tests;
- update `docs/AUDIT.md`;
- tell me how to try the new onboarding, the iCloud switch (on a real iPhone signed in to iCloud, since the Simulator can sign in to iCloud too but sync is slower), and Welcome back (delete and reinstall the app).
