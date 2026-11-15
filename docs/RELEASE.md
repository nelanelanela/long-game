# Long Game 1.0 · release on 1 December 2026

Written 15 November 2026 (update 50). Version 1.0, iPhone, iPad, Apple Watch and Mac.

## Your checklist (part 2), in this order

Nothing here has been done for you; each step is yours.

1. **WeatherKit: does it work on your iPhone?**
   - In Xcode, choose your iPhone at the top, then **Product › Run**. If Xcode shows a red line under **Signing & Capabilities** about WeatherKit, click **Try Again** (it fetches a profile that includes WeatherKit).
   - On the phone: **Settings** (in the app) › **Weather in the scene** › on › **Allow While Using App**.
   - In Xcode's console (bottom right), look for **"Weather fetched: …"**. That line means WeatherKit answered. A clear sky draws nothing on purpose, so the line is the proof, not the picture.
   - If you see **"Weather fetch failed"** with *"WDSJWTAuthenticator"* or *"401"*, the service isn't ready for your App ID yet. It can take up to an hour after switching it on. Wait, then run again. Nothing else is needed.
2. **iCloud: deploy the schema to Production. Yes, this is needed before release.** The store gained the Letter table and new fields (photo view counts, look, weather, memories, Then and now). The App Store app talks to Production, and Production only knows what you deploy.
   - First fill Development: run from Xcode on a device signed in to iCloud, with **Save to iCloud** on. Write and seal one letter, open a photo, and change **Look** once. Wait a minute.
   - Go to **icloud.developer.apple.com** › **CloudKit Database** › the container **iCloud.com.wehavesun.LongGame** › make sure **Development** is chosen at the top › **Schema** › **Record Types**. Check that **CD_Letter** is there.
   - In the left column, at the bottom, click **Deploy Schema Changes…**, read the list (it should only *add* things), then **Deploy**.
3. **Controls, Shortcuts and the Watch: nothing to switch on.** The Control Centre control, the Action Button shortcut and the Watch's Add time are App Intents, which need no capability. The widgets and the Watch already share the app group `group.com.wehavesun.LongGame.shared`. Automatic signing in Xcode covers them.
4. **Privacy policy** (wehavesun.com/long-game/privacy). Add:
   > **Weather.** If you turn on "Weather in the scene", Long Game uses your device's approximate location to ask Apple Weather for the current weather, a few times a day at most, while the app is open. Long Game doesn't store your location or send it anywhere else. Apple's privacy policy applies to Apple Weather. You can turn this off at any time in the app's Settings, and location access in iPhone Settings.
   >
   > **Letters to your future self** are kept with the rest of your game: on your device, and in your own iCloud if you turn on Save to iCloud. We never see them. A sealed letter's words are left out of the export until it opens.

   Check that the rest still says: no account and no sign-in; no analytics, ads or tracking; sessions, notes and photos stay on the device and in your own iCloud; how many times a photo was opened is counted only on the device (for the weekly look-back); the export (Settings › Data & storage › Export sessions) is a file you choose to share; tips go through Apple, and we never see payment details.
5. **App Store privacy answers** (App Store Connect › your app › **App Privacy** › **Edit**):
   - **Data Types:** tick **Location › Coarse Location**.
   - For it: **App Functionality** only; **No, it's not linked to the user's identity**; **No, it's not used for tracking**.
   - Everything else stays as it was (if it was "Data Not Collected", it's now just Coarse Location).
   - Click **Publish**.
6. **The App Store page** (App Store Connect › your app › **iOS App 1.0**):
   - Screenshots: any taken before the redesign no longer match: the old Home, History, the old Settings and the timer. The app now has three Home tabs, the glass top bar, the dark look, Data & storage and the new celebration. The six that tell the story best: Home · Today (the sun up), the Timer's sunrise, Home · The long game, History · Calendar, Growth, and the milestone card. I can make them with the Simulator at the 6.9-inch size when you say so.
   - **Description**, **Keywords** and **Promotional Text:** drafts are at the end of this file.
   - **What's New:** only if 1.0 was uploaded before. For a first release the box isn't there.
   - Under **Version Release**, choose **Manually release this version**.

## On your iPhone and Watch, about 30 minutes (part 4)

One line each: what to do, then what you should see, hear or feel.

1. **Begin a session** on Home, then lock the phone. The Lock Screen shows the Live Activity with the sun and the time running.
2. **Long-press the Live Activity**, then open the app again. The timer is still running, with the same time.
3. **Finish, add a note and Save.** The sun rises with a burst, "Saved", a rising-three tap, then "40 m added · Undo" on Home.
4. **Tap Undo.** "Removed.", and the total goes back.
5. **Control Centre:** add the Long Game control (edit, +). Tap it: a session starts and the app shows the timer.
6. **Action Button:** Settings › Action Button › Shortcut › Long Game › Start a session. Press it: the same as 5.
7. **Watch: Add time.** Open Long Game on the Watch › Add time › turn the Crown to 30 m › Add. You feel ticks as the Crown turns, and the phone's Home shows the 30 m within a minute.
8. **Haptics:** tickle the sun on Home (a giggle and soft taps); drag along the full-screen Growth chart (a tap at each milestone).
9. **Weather:** Settings › Weather in the scene on. On a cloudy or rainy day the scene changes within a few seconds; VoiceOver adds "light rain" to the scene.
10. **iCloud, two devices:** on the iPad (or a second phone, same Apple Account, Save to iCloud on), add 20 m. Within a minute or two it's on the phone.
11. **A letter across devices:** write and seal a letter on the phone. On the iPad, The long game shows "A letter is waiting", never its words.
12. **VoiceOver on Home** (triple-click the side button if set up): swipe through. You hear the craft, the tabs, today's words, then Begin and Add past hours last.
13. **VoiceOver on the timer:** it says the time and "Pause or resume"; Finish opens the sheet with the time read first.
14. **Tip jar in the sandbox:** Settings › Support Long Game › a tip. The sandbox sheet asks for your Sandbox account (Settings › Developer › Sandbox Account) and says "[Environment: Sandbox]". Then Thank you, and Settings says "Thank you for your support".
15. **Dark look:** Control Centre › Dark Mode. Home becomes the night sky and the sun still shows today.
16. **App icon:** Settings › App icon grows with you. If you're past 1,000 hours, iOS says "You have changed the icon" once and the Home Screen icon shows the stage.
17. **Notifications:** Settings › Daily reminder on, set it 2 minutes ahead, lock the phone. The reminder arrives with the craft's name.
18. **iPad, landscape:** rotate. The sidebar layout with Home on the right.
19. **Mac:** open Long Game on the Mac. The sun is in the menu bar, the window opens on the sunrise, then Home with the same total as the phone (if iCloud is on).

## The calendar (part 6), honestly

Today is Sunday 15 November. It fits, with about four days to spare, provided the device checks don't turn up something big.

| Date | What |
|---|---|
| Mon 16 – Wed 18 Nov | I finish the full check (the audit passes at the largest text size, dark and Increase Contrast; the dark walk; launch time). You decide the design questions. |
| Wed 18 Nov | You: steps 1 and 2 of your checklist (WeatherKit, then the CloudKit schema). |
| **Thu 19 Nov** | **Last day for new code.** After this, only fixes. |
| Thu 19 – Fri 20 Nov | You: the 30-minute device check. I fix what it finds. Version 1.0 and the build number, docs, merge into `main` and tag `v1.0` (I ask before pushing). |
| **Sat 21 Nov** | **Archive, upload, and submit for review** with **Manually release this version**. |
| Mon 23 – Tue 24 Nov | Review usually answers within a day or two. |
| Wed 25 – Fri 27 Nov | Room for one rejection: fix, upload a new build, a second review. Thanksgiving (26–27 Nov) can slow Apple down. |
| Mon 30 Nov | Last moment to be approved and waiting. |
| **Tue 1 Dec** | You click **Release This Version**. |

**What to cut first if time runs short:**

1. **The Mac app.** Nobody has seen it running yet, and it's a separate review. Ship iPhone, iPad and Watch on 1 December and the Mac a week or two later. Cost: Mac users wait. Nothing changes for anyone else.
2. **Weather in the scene.** It's the only part that needs location, the privacy changes and WeatherKit working. Hiding it means removing setup step 7 and the Settings switch (an hour's work), and the privacy policy and App Store answers stay as they were. Cost: the quiet weather.
3. **The keepsake poster.** It's self-contained. Hiding it takes 15 minutes. Cost: one thing fewer to make at 1,000 hours.

## Drafts for the App Store page

**Promotional Text** (170 characters):
> Every hour you practise lifts the sun. A calm way to count the hours toward mastery of the one craft you love.

**Description:**
> Long Game counts the hours you spend on one craft, on the way to 10,000. Piano, drawing, climbing, code: whatever you keep coming back to.
>
> Every session lifts a small, smiling sun a little higher over the sea. Begin when you start and Finish when you stop. Add hours you played without the timer, and the years before you had the app.
>
> • Today, this week and the long game: what's left of today's stretch, your week's pace, and when you'll reach 10,000 hours.
> • A calendar of every day you played, and a Rhythm instead of streaks, so a day off never breaks anything.
> • Growth: your hours so far and where your chosen pace takes you. Drag along the line to feel each milestone.
> • Milestones every 1,000 hours, with a card to share and a poster to print.
> • Letters to your future self, opened by the sun when you get there.
> • Then and now: your first photo next to your latest.
> • A Live Activity, a Control Centre control, widgets, and Apple Watch.
> • A night look for evening practice, and the weather outside passing through the scene, if you like.
>
> Free, with no ads, no account and no tracking. Your game stays on your device and in your own iCloud.

**Keywords** (100 characters):
> practice,10000 hours,mastery,habit,timer,hobby,deliberate,skill,piano,guitar,drawing,journal,tracker
