# Update prompt 50 for Claude Code: everything ships on 1 December

Paste everything below the line into your Claude Code session in this folder.

---

I've decided to release everything on 1 December: the redesign and every update up to 49, including the ones we had planned for later (quicker logging, feeling progress, dark mode, Write to us, Then and now, The sun remembers, letters, the keepsake poster, weather in the scene). Nothing is held back for a later version.

Please get the `redesign` branch ready to ship. Work in the order below, build and test after each part, and commit in small steps. Stop and ask me before anything that needs my Apple Developer account or App Store Connect; for each of those, tell me in plain words what to click and where.

## 1 · Finish what's open
- Finish update 49's weather in the scene, including the onboarding step. WeatherKit is already switched on in my Apple Developer account, so go ahead. Setup is now **7 steps**; the design boards for all seven show seven dots (`design/redesign/Craft.dc.html` … `Notifications.dc.html`, `OnboardingWeather.dc.html`).
- Go through `docs/AUDIT.md` and list every item still marked 🟡 or open, from every update. For each one, either finish it or tell me why it can wait. I know of these:
  - See then and now on the milestone celebration should sit above Share this moment (update 42's milestone share card);
  - the poster is offered "at every 1,000 hours", but celebrations exist only at 1,000, 5,000 and 10,000. Add the celebration at every 1,000 hours (2,000, 3,000, 4,000, 6,000 … 9,000), so letters and posters have their moment;
  - anything from updates 43 to 46 that was built on another branch and hasn't reached `redesign`.
- Show me the list before you start on it.

## 2 · What I have to do myself (prepare it, then wait for me)
Write these as one short checklist, in the order I should do them, with the exact names of the buttons:
- **WeatherKit:** I've already switched it on in my Apple Developer account, so don't wait for me on that. Tell me how to confirm it works (a real weather fetch in a signed build on my iPhone; it can take a little while after switching on), and whether anything else is needed, such as the provisioning profile refreshing.
- **iCloud:** the store has new things in it (letters, and anything else added since the last build that used iCloud). Tell me whether the CloudKit schema needs deploying to Production before release, and how.
- **Controls, Shortcuts and the Watch:** any capability or identifier updates 43 and 44 need.
- **The privacy policy** at wehavesun.com/long-game/privacy: give me the exact sentences to add for approximate location and Apple Weather, and check the rest of the policy still matches what the app does (letters, photos, the view counts, the export).
- **App Store privacy answers:** tell me what to choose for location now. Don't change anything in App Store Connect yourself.
- **The App Store page:** the description, What's New, keywords and screenshots. Tell me which screenshots no longer match the app.

## 3 · A full check of the whole app
- Run all unit tests and the accessibility UI tests from update 47. Add the new screens to the screen list:
  - the seventh setup step;
  - Then and now, and its photo picker;
  - Home with a memory card;
  - the letter: write, sealed, delivered, Your letters;
  - the poster sheet;
  - Home with each weather layer.
- Run the four audit passes again (default, largest text, dark, Increase Contrast). Fix what's found, and list any design change for me instead of making it.
- Walk every new screen in the dark look.
- Check every new string is in the String Catalog with British spelling, and that nothing is left in English only where the app is translated.
- Check that every debug option, launch argument and sample-data switch is compiled out of Release builds.
- Check the privacy manifest (`PrivacyInfo.xcprivacy`) lists what the app now uses, including approximate location.
- Start from a copy of a store made by the version on `main`, and confirm it opens in the new version with nothing lost (sessions, photos, estimates, settings). Add a migration test if there isn't one.
- Check a fresh install with everything refused (notifications, location, iCloud off): the app must work fully.
- Measure the launch time and the size of the app, and tell me both.

## 4 · On my iPhone
Give me one checklist, about 30 minutes, for my own phone and Watch. One line each: what to do and what I should see, hear or feel. Cover:
- a whole session from Begin to Save, with the Live Activity;
- the control in Control Centre and the Action Button shortcut;
- Add time on the Watch;
- the haptics;
- weather in the scene, with the real weather;
- iCloud sync between two devices, including a letter;
- VoiceOver on Home and the timer;
- the tip jar in the sandbox.

## 5 · The release itself
- Set the version to 1.0 and a fresh build number (ask me if 1.0 was ever uploaded before).
- Update `docs/SPEC.md`, `docs/AUDIT.md` and the README so they describe the app as it ships.
- When everything above is green, merge `redesign` into `main` and tag it `v1.0`. Ask me before pushing.
- Then walk me through archiving and uploading from Xcode, step by step. Signing is mine to do.
- Remind me to choose **Manually release this version** in App Store Connect, so the app goes live on 1 December and not on the day it's approved.

## 6 · The calendar
Today is 14 November. Tell me honestly whether all of this fits, and propose dates working back from 1 December:
- the last day for new code;
- the day to upload the build and send it for review (leave room for one rejection and a second review);
- what you would cut first if time runs short, and what that would cost.

When you're done with each part, tell me in plain words what's finished, what's waiting for me, and what's next.
