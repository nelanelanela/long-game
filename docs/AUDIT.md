# Audit: app vs `docs/SPEC.md` and `design/`

Source of truth: the spec. ✅ done · 🟡 partly done · ❌ missing.
Updated after update prompt 20 (the app icon that grows). Earlier: update prompt 16 (scrub the forecast). Earlier: update prompt 14 (Liquid Glass). Earlier: update prompt 13 (your year card). Earlier: update prompt 12 (a note and a photo). Earlier: update prompt 11 (Today's stretch, no glints on the water). Earlier: update prompt 09 (your pace for the year, Home tabs, widgets, Apple Watch). Every row shows its final status, with what changed in the Note column.
Updated after the fixes: every row below shows its final status, with what changed in the Note column. Decisions for you, the things I could not do and how to check each flow are at the bottom.

## Accessibility (update prompt 17 and the accessibility pass before it)

Report: `docs/ACCESSIBILITY_REPORT.md`. Done:

- **Calendar shapes** (`DesignSystem/CalendarLevelMark.swift`): rest dot, thin bar, taller bar, rounded square, circle, in the spec's sizes and colours. Used in the History grid, its legend (and the photo-dot legend) and the year card's strip. Photo dot in the centre, navy selection ring kept, 1 pt darker outline on level 1 and the rest dot with Increase Contrast. Previews: levels, greyscale, Increase Contrast, AX5 legend.
- **The sun in words** (`Logic/SunWords.swift`): `sunPositionWords(fraction:)` and `SunSpeech` (This week, The long game, Today, Timer, calendar day). Each Home sun is one element: label = words, `accessibilityValue` = numbers; on This week it is adjustable (swipe reads "Monday, 1 hour 10 minutes", "Saturday, not yet").
- **Timer:** the sun reads "Session … rays lit … Total …"; a lit ray posts a queued, low-priority "Ray 6 lit" only while VoiceOver is on; pause, resume and save are announced.
- **Calendar days** read "Thursday 22 October. 2 hours, a good day. Has a photo."; they are real buttons with a larger touch area and the selected trait.
- **Non-colour cues:** forecast is dashed (already); the Growth tab now has a "Played / Forecast" legend in words; reached/covered states already say so in words; the stretch arc's travelled part is 3 pt over a 2 pt dotted track (already). Changed: calendar levels (colour only before), "No note" grey (2:1 → 4.4:1), note placeholder (3.3:1 → 5.1:1), forecast words on the chart chip (3.1:1 → 5:1), year-card label (4.0:1 → 4.8:1), Timer strip caption (65% → 80% white).
- **Other:** Dynamic Type up to AX5; Reduce Motion on every page and tab change (`lgAnimation`); Reduce Transparency and Increase Contrast make the translucent buttons and glass strip firmer; Button Shapes underline plain text buttons; photos and the sun ignore Smart Invert; chevrons scale with text; headings on every screen; photo viewer has a Zoom action.

Not done or not testable here:

- **Accessibility Inspector audit** (Home three tabs, Timer, History, Finish sheet): it is a Mac app that needs to be driven by hand, so I could not run it. I checked Home and History at AX5 in the Simulator by screenshot and fixed what I saw (tab names cut off, calendar labels overlapping the grid, legend breaking mid-word). Please run the audit once.
- Real VoiceOver speech, Voice Control and the queued ray announcement: need a real iPhone or hands-on Simulator use.
- Strings: the spoken sentences are one `String(localized:)` each, with the plural parts ("3 days", "1 hour") taken from the existing pluralised catalog entries rather than new catalog variations. The catalog is English only.
- Dark appearance: not started (a design job of its own).

## App icon (update prompts 20 and 25)

| Requirement | Status | Where | Note |
| --- | --- | --- | --- |
| Eleven icons (Start, then 1,000 … 10,000) in the spec's geometry | ✅ | `Tools/MakeIcon.swift`, `Assets.xcassets/AppIcon*.appiconset` | One `drawIcon(hours:look:)`; number drawn as outlines. The sun is drawn from the same numbers as SunView |
| Dark and Tinted for every set | ✅ | same | Dark reuses the artwork; Tinted is greyscale |
| Alternate sets listed in `project.yml` | ✅ | `project.yml` | `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` |
| `IconStage.for(totalHours:)` and `IconPlan` | ✅ | `Logic/IconStage.swift` | Tests in `IconStageTests.swift` |
| 1,000, 5,000 and 10,000 change the icon after the celebration's main button | ✅ | `HomeView.celebrationDone` | 2,500 and 7,500 celebrate but never change it themselves; jumps go to the highest stage |
| Other thousands change the icon once the sheet or timer has closed | ✅ | `HomeView.sheetClosed`, `syncIconQuietly` | Uses each sheet's `onDismiss`; Watch / Live Activity saves wait for the next active Home |
| `IconStage` is a count of thousands; old stored value treated as unknown | ✅ | `Logic/IconStage.swift`, `Models.swift` | No migration |
| Quiet lowering on launch / foreground, never during a session | ✅ | `HomeView.syncIconQuietly` | Replace my craft resets at once (`OneCraftSheet`) |
| Settings switch "App icon grows with you" | ✅ | `SettingsView.iconCard` | Standard Toggle, so VoiceOver and Dynamic Type work |
| Previews of all eleven stages, Dark and Tinted | 🟡 | `DesignSystem/IconStageView.swift` | Built; not opened in the Xcode canvas from here |
| Real alternate-icon switching on a device | ❌ | | Not run on a real iPhone; see "how to check" in the hand-over |

## Data and maths

| Requirement | Status | Where | Note |
| --- | --- | --- | --- |
| Four entities Craft, YearEstimate, Session (timer/manual/catchUp), Settings | ✅ | `Models/Models.swift` | Settings is `AppSettings`. `syncEnabled` exists but the toggle only wrote UserDefaults |
| Totals always derived, never stored | ✅ | `Logic/Summary.swift`, `Logic/Basics.swift` | |
| Baseline, logged, total | ✅ | `Logic/Basics.swift` | |
| Progress capped at 100%, keeps counting | ✅ | `Totals.progress/percent` | |
| This week, Pace (12 weeks, blended with latest estimate) | ✅ | `WeekMath`, `Pace` | |
| One active craft; archived crafts read-only | ✅ | `AppRoot`, `OneCraftSheet`, `ArchivedCraftsView` | |
| "Logged hours" only from after onboarding | ✅ | `SessionFormView` | Fixed: the add-hours calendar now starts on the onboarding day, so nothing is counted twice |
| Settings: `weeklyTargetHours`, `targetSetAt`, `targetEndsAt`, `lastHomeTab`; `TargetPeriod` history (hours, start, end) | ✅ | `Models/Models.swift`, `TargetSaving` | Also `targetPromptShownAt`, so the new-year sheet opens once. A new target moves the old one into `TargetPeriod`; past weeks use the target of their last day (`TargetHistory`) |
| The 12 months run from the day the target is set | ✅ | `WeeklyTarget.endDate` | Counted from the start of that day, so it ends at midnight 12 months later |
| Forecast uses the target for those 12 months only when the recent pace is within 25% of it | ✅ | `WeeklyTarget.forecastWindow`, `ForecastEngine.monthlyRate` | Mid line only; the low/high band is unchanged. The Growth tab and its what-if use it too |
| The SwiftData database stays where it always was | ✅ | `CloudSync.configuration` | Fixed in Part 4: once the app had an App Group, SwiftData's default moved the database into the group's folder, which would have left saved data behind. It is pinned to the app's own folder and `StoreLocationTests` guards it |

## Onboarding

| Requirement | Status | Where | Note |
| --- | --- | --- | --- |
| Welcome: sunrise gradient, sun, one line, Get started only (no sign-in button) | ✅ | `WelcomeView` | Update 21 |
| Welcome back from iCloud: looks quietly for a game for at most 3 s on a first launch; Continue my game / Start a new game (the iCloud game is archived, not deleted) | 🟡 | `AppRoot`, `WelcomeBackView`, `WelcomeBack` (Logic) | Decision logic and timing are unit-tested. The real restore needs a second device or a reinstall with your iCloud, not tried here |
| Your craft: search, five groups, custom name 2–40 | ✅ | `CraftStepView`, `CraftSuggestions` | |
| When did you start: stepper, default year − 3, 1940…now | ✅ | `StartYearView` | |
| Current year skips step 3 | ✅ | `StartYearView`, `YearlyHoursView` | Decided: no skip. Step 3 shows one slider for this year; set it to 0 if starting from scratch. Spec updated |
| Hours per week: one slider per year 0–40, live estimate, Continue | ✅ | `YearlyHoursView` | Design file says max 30; spec says 40, code follows spec. The button now says Continue |
| Step dots show 5 steps | ✅ | `LGStepBar`, `OnboardingHeader` | Update 21 |
| Lighter copy: one title and at most one short line on Welcome, the intro pages and steps 1, 2, 3, 3b; chips under group labels; big − / + year stepper; "Your starting score" under the card | ✅ | `WelcomeView`, `IntroView`, `CraftStepView`, `StartYearView`, `YearlyHoursView` | Update 21. Unused strings removed from the catalog |
| Step 4 "Your weekly pace": one line, big − / + stepper 1–40 by 0.5, no hint line, no quick-pick chips, one quiet line "About 1 h 43 m a day · until Nov 2027", Continue. From This week it keeps "Your pace for the year" and Save | ✅ | `WeeklyTargetView`, `OnboardingFlow` | Update 21. The quick-pick chips remain only on the catch-up average stepper |
| Step 5 "Keep your game safe": iCloud card with the switch on by default, privacy line, Start playing saves everything and opens Home on The long game once. Without an iCloud account the switch is off and disabled with the sign-in line | ✅ | `ICloudStepView`, `OnboardingFlow`, `ICloudSwitchState` | Update 21. The signed-out look was seen in the Simulator (no iCloud account there) |
| Edit from Home: Save restarts the 12 months today | ✅ | `WeeklyTargetView`, `TargetSaving` | |
| Reminder 14 days before the end; "A new year of pace" sheet once, old value filled in | ✅ | `TargetCycle`, `TargetRow`, `HomeView` | After the end date the reminder stays in the target row until a new target is set. A game with no target yet gets the same sheet once, titled "Your pace for the year" |

## The sun giggles when tapped (update prompt 15)

| Requirement | Status | Where | Note |
| --- | --- | --- | --- |
| Seven recordings trimmed to the loudest laugh, evened to the same loudness, 10 ms fade-in and a 0.18 s fade-out, AAC `.m4a` made with `afconvert` | ✅ | `LongGame/Resources/Sounds/giggle-1.m4a` … `giggle-7.m4a` | Six are 1.2 s. `giggle-3` (your longest, 1.5 s) is kept for the five-tap laugh and is never picked for a normal giggle. Your originals stay in `Sounds/giggles/sun_laughs/`, outside the app target and never uploaded |
| `GiggleSoundPlayer`: preloads the clips, random pick that is never the same twice in a row, volume 0.7, one clip at a time, `.ambient` session, skips when `secondaryAudioShouldBeSilencedHint` | ✅ | `Sound/GiggleSoundPlayer.swift`, `GiggleClipPicker` | The sound starts 0.05 s after the tap |
| Settings → Sounds → Giggle sound, on by default; when off the audio session is never touched and no clip is loaded | ✅ | `SettingsView.soundsCard`, `AppSettings.giggleSound`, test `withTheSettingOffTheAudioSessionIsNeverTouched` | The session is set up the first time the sun is shown with the switch on, so the first tap starts instantly |
| Laughing face (eyes > <, open mouth, small pink tongue, deeper cheeks #F48FA8) and a surprised face | ✅ | `SunView` (`SunFace.laughing`, `.surprised`) | Previews: 'Sun faces' |
| The sequence: squash 107% × 92% and 6 pt down with the surprised face, laugh with the wiggle −8°, +7°, −5°, +3°, −1° and hops of 6 and 5 pt, rays to 108% and back, four sparkles, spring back (response 0.35, damping 0.6), 0.2 s wink | ✅ | `Logic/SunGiggle.swift` (`GiggleMotion.pose`) | A pure function of time, tested at each stop. Never more than 6 pt or 8° |
| Driven by time, not timers: the sun redraws only from the first to the last moment of a giggle | ✅ | `GiggleSchedule` (a `TimelineSchedule`), `GigglingSun` | **Different from the prompt:** I used a `TimelineView` with the pose worked out from timestamps instead of `phaseAnimator` or `keyframeAnimator`, because it can be tested exactly and follows the project rule that animations come from timestamps. There are no timers either way |
| The sun's place on the gauge or arc does not change; the sea and its mask stay in front | ✅ | `SunriseCanvas`: the giggle moves the sun inside the masked layer | Preview 'Giggle · every frame' |
| Haptics: soft at 0, light at 0.25 s and 0.45 s, only when system haptics are on | ✅ | `GigglingSun` (`sensoryFeedback`) | Cannot be felt in the Simulator |
| A tap during a giggle restarts the animation; a new sound starts only when the clip has finished | ✅ | `GiggleTaps` | Tested |
| Five taps in 2 s: the big laugh (longest clip, one full spin of the rays), then taps are ignored while it lasts and only wink for 3 s | ✅ | `GiggleTaps`, `GiggleMotion` (kind `.big`) | The fifth tap may cut a normal clip short, so there are never two sounds at once |
| Works on Home (all three tabs), the intro pages and the future-self sheet | ✅ | `SunriseHero` | The sun's tap target is the whole sun, at least 44 pt, and never below the waterline |
| Tip jar | ⚠️ | n/a | There is no tip jar screen in the app yet (only `TipStore`), so there was nothing to add the giggle to. It will work with `SunriseHero` when it exists |
| The Timer: a tap gets only a soft wink, no sound, no wiggle, no haptic, no audio session | ✅ | `TimerView` (`tapWink`) |  |
| Not in widgets, the Watch, the Live Activity or the year card image | ✅ | They use `SunView` or `SunriseCanvas` without a giggle | |
| Reduce Motion: the laughing face for 0.8 s with haptic and sound, nothing moves | ✅ | `GiggleMotion.pose(reduceMotion: true)` | Tested |
| VoiceOver: the custom action 'Tickle the sun' | ✅ | `SunriseHero`, `TimerView` | Not run with VoiceOver |
| Tests: tap logic, no overlapping sound, five taps in 2 s, 3 s rest, never the same clip, setting off means no session, schedule, controller | ✅ | `LongGameTests/SunGiggleTests.swift` |  |
| Previews of the sequence | ✅ | `SunriseHero.swift`: 'Giggle · every frame', 'Giggle · big laugh and Reduce Motion' |  |

Not seen or heard on a device: the Ring/Silent switch (only a real iPhone can test it), the haptics, and VoiceOver.

## Scrub the forecast (update prompt 16)

| Requirement | Status | Where | Note |
| --- | --- | --- | --- |
| `milestoneDates`: 1,000 / 2,500 / 5,000 / 7,500 / 10,000 h as the day first reached (estimate flag inside the onboarding estimate) or the forecast month; none beyond 30 years | ✅ | `Logic/GrowthScrub.swift` | Uses the forecast with the 'What if I practise more?' extra hours |
| `curvePoint(at:)`, `crossedMilestone(from:to:)` (either direction, Today included) | ✅ | `GrowthScrub` | Arriving on a milestone counts, leaving one does not |
| A tap never repeats while the finger rests on a milestone | ✅ | `GrowthScrub.Tracker` | Moving well away (2% of the line) re-arms it |
| Texts for past, future and milestone points; idle headline as on the card | ✅ | `ScrubText` | Dates and numbers formatted for the user's locale (the example in the spec uses British English) |
| Tests: reached by estimate, by logged hours, still ahead; exactly on Today; left and right; 'Not within 30 years'; the slider's extra hours | ✅ | `LongGameTests/GrowthScrubTests.swift` | 379 tests pass |
| Expand button (36 pt circle) and a tap on the chart open a full-screen cover; zoom transition; close with the X or a swipe down on the top of the screen | ✅ | `GrowthTab`, `GrowthScrubView` | The zoom is iOS 18 and later; on iOS 17 the cover slides up. The swipe down works on the header and headline, because the chart belongs to the scrubbing finger |
| Same chart code as the card, bigger, y labels 0 / 2.5k / 5k / 7.5k / 10k; milestone dots (navy filled when reached, orange outline ahead); the sun at 10,000 | ✅ | `GrowthChartView` | One view for both styles |
| Draw-in 0.8 s, 0.5 s, 0.3 s and a bouncing sun; Reduce Motion: a 0.2 s fade | ✅ | `GrowthScrubView.drawIn` |  |
| Scrub with `chartXSelection`, a navy line and a white dot with a navy ring snapped to the curve; floating label that flips side; point kept 1.5 s after the finger lifts | ✅ | `GrowthScrubView`, `GrowthChartView` | Seen working on the iOS 18.2 Simulator with a drag |
| Hint 'Drag along the line' goes away for good after the first scrub | ✅ | `AppSettings.scrubHintSeen` |  |
| Haptics: light impact at a milestone with a 0.4 s gold ring; selection tick at Today and both ends | ✅ | `sensoryFeedback` keyed on the milestone index | Cannot be felt in the Simulator |
| VoiceOver: Audio Graph, adjustable action through Start, milestones, Today, Finish line, 'Close chart' | ✅ | `GrowthChartDescriptor`, `ScrubText.stops` | The Audio Graph and the stepping were not run with VoiceOver |
| Previews: portrait, landscape, wide; scrubbed at a past milestone, Today and a future milestone; 'Not within 30 years' | ✅ | `GrowthScrubView.swift` |  |

Not seen: landscape and wide windows on a device, the zoom transition on iOS 26.

## Liquid Glass (update prompt 14)

| Requirement | Status | Where | Note |
| --- | --- | --- | --- |
| Only Apple's glass APIs, every one behind `if #available(iOS 26, *)`; iOS 17-25 unchanged | ✅ | `DesignSystem/Glass.swift`, `Components.swift` | glassEffect, GlassEffectContainer, glassEffectID. The shared styles pick the look, so feature views do not change per OS. `lgFlat` forces the old look on a newer system, for previews |
| Segmented control: glass capsule track, brighter interactive lens that morphs; Reduce Motion: no stretching; VoiceOver tab list | ✅ | `LGSegmentedControl` | Used for Home and History, and Your year. The tab-bar trait is on every OS |
| Primary button: 56 pt ink-tinted glass capsule, white text | ✅ | `LGButtonStyle.primary` | Uses glassEffect with an ink tint rather than `.glassProminent`, so every call site stays `.lg(.primary)` |
| Secondary button: 48 pt clear glass capsule, navy text (Add past hours, Discard) | ✅ | `LGButtonStyle.quiet` | New kind, a plain text button before iOS 26. 'Keep playing' stays a primary button as before |
| Toolbar icons: 44 pt glass circles | ✅ | `LGIconButton` | Home's History icon now uses it too |
| Timer: Pause and Resume clear glass; Finish bright glass with navy text; stretch strip removed in update 21 | ✅ | `LGButtonStyle` | `lgGlassStrip` deleted with the strip |
| Warm wash #FFF0D6 at the top of Home and History | ✅ | `LGColor.warmWash`, `lgWarmScreen` | iOS 26 only, so iOS 17-25 looks the same |
| Header floats while content scrolls under it | ✅ | `lgTopBar` | Uses the system's soft scroll edge (`safeAreaBar`) on iOS 26. Home's tabs scroll with the page, as before, so only the header floats |
| Previews of each style, glass and flat, light and over the night sky | ✅ | `DesignSystem/GlassPreviews.swift` |  |

**Not verified:** the iOS 26+ glass look has not been seen. The iOS 27 Simulator here would not run any app (even Settings hung), so it compiles for iOS 27 but I could not look at it. The old look was run on the iOS 18.2 Simulator (no iOS 17 runtime is installed) and all 351 tests pass there. Reduce Transparency, Increase Contrast, Dynamic Type XXXL and the 4.5:1 contrast check on glass still need a look on a working iOS 26+ Simulator or device.

## Your year card (update prompt 13)

| Requirement | Status | Where | Note |
| --- | --- | --- | --- |
| `YearSummary`: hours, days of practice, Rhythm, most played month, total at year end, percent, calendar levels, 'since' date, photos newest first | ✅ | `Logic/YearSummary.swift` | Pure, nothing stored. Rhythm is the middle of the practice days per week over complete weeks inside the year (and after the game began) |
| Which year: the current one, the one that just ended from 1 to 15 January; rows hidden under 4 weeks of data | ✅ | `YearSummary.defaultYear`, `hasEnoughData` | Four weeks = 28 days since the start of the year or the game, with something logged |
| Tests: hours and days, Rhythm, months and ties, 1-15 Jan, onboarding in the year, under 4 weeks, Sunday or Monday, 31 December midnight, rendering sizes | ✅ | `LongGameTests/YearSummaryTests.swift` | 351 tests pass |
| Entry rows: History -> Growth all year; The long game tab 1 Dec - 15 Jan | ✅ | `GrowthTab`, `HomeView` | Quiet rows, no notification or pop-up |
| Your year screen: back chevron, title menu to pick a year, Sunrise / Evening / Photos, scaled preview, Show hours, Share | ✅ | `Features/Year/YearScreen.swift` | Photos only with at least 6 photo sessions in the year. Long-press a photo tile to swap it |
| Cards at 360 pt, fixed text sizes: Sunrise and Evening 9:16, Photos square; the still happy sun, year strip, three stats, footer; nothing gold on the water | ✅ | `Features/Year/YearCardView.swift`, `SunriseCanvas` | Reuses the sun, sea and calendar colours; the sea gained a palette so Evening can have its own |
| Sharing: ImageRenderer at 3x (1080 x 1920 or 1080 x 1080), PNG through ShareLink, always the chosen look | ✅ | `YearCardRender` | No new permission. Tested sizes and that light and dark system settings give the same picture |
| VoiceOver: preview is one element with a spoken summary; screen supports Dynamic Type | ✅ | `YearCardText.spoken` |  |
| Numbers and month names follow the user's locale; previews of all three cards with hours shown and hidden | ✅ | `YearCardText`, `YearCardView` previews | The rest of the app's copy is English |
| Debug option: fill a sample year (and remove it) | ✅ | Settings, Debug only | About 60% of this year's days so far, six with a made-up photo |

Not seen on a device: the share sheet (Instagram Stories and so on).

## A note and a photo (update prompt 12)

| Requirement | Status | Where | Note |
| --- | --- | --- | --- |
| `Session.photo` (external storage) and a `hasPhoto` flag; existing sessions keep working | ✅ | `Models/Models.swift` | Adding optional attributes is a lightweight automatic migration, so no versioned schema was needed. `hasPhoto` lets lists and the calendar avoid loading images |
| Photo saved as JPEG, longest side 2048 px, quality 0.8, no metadata; never enlarged | ✅ | `Logic/PhotoProcessing.swift` | Tested with a picture carrying GPS and camera details |
| Thumbnails made on the fly, cached in memory, not stored | ✅ | `Features/Photos/PhotoThumb.swift` |  |
| Note limit 500 characters | ✅ | `SessionRules` | Was 280 |
| Finish sheet row: 64 pt dashed camera square and soft note field; nothing focused or opened by itself | ✅ | `NotePhotoRow`, `FinishSheet` | Take photo, Choose from library (PhotosPicker, no permission). Take photo is hidden where there is no camera (the Simulator). Camera permission is asked by the system on first use |
| `NSCameraUsageDescription` | ✅ | `project.yml` | 'Take a photo of what you made, if you like.' |
| Edit later: same two fields in the session editor | ✅ | `SessionFormView` | Also reached from the History day card |
| Calendar: white 4 pt dot on days with a photo; second legend line only once there is a photo | ✅ | `CalendarTab` |  |
| Day card: 56 pt thumbnail and note per session; 'No note' in light grey | ✅ | `CalendarTab.sessionRow` | A manual session's note is its title as before |
| Full-screen viewer: close, date and 'Evening · 1 h 15', pinch zoom, note, strip of thumbnails, swipe across all days newest last, ... menu (Change photo, Edit note, Remove photo with confirmation); cross-fade with Reduce Motion | ✅ | `PhotoViewer` | VoiceOver: swipe up or down on the photo to move between photos, thumbnails are buttons |
| CSV export has notes, escaped, and no photos; Delete all data removes photos; deleting a session deletes its photo | ✅ | `CSVExport`, `SettingsView.deleteAll` | Delete all now deletes sessions one by one so every photo file goes |
| CloudKit: photos sync only when sync is on | ✅ |  | Automatic with external storage; cannot be tried without your Apple Developer account |
| Tests | ✅ | `LongGameTests/NotePhotoTests.swift` | Size limit, JPEG, stripped details, note limit, CSV escaping, photo days, deleting a session |

Not seen on a device: the camera, and the viewer's gestures. Check them by hand (below).

## Today's stretch (update prompt 11)

| Requirement | Status | Where | Note |
| --- | --- | --- | --- |
| No gold glints on or in the water, anywhere | ✅ | `SunriseHero`, `SunriseMotion` | Layer order glow, sun, sea fill, pale wave, navy line. The widgets and Watch draw their own sea and have no glints |
| Practice days: practised on the weekday in at least 2 of the last 4 full weeks; under 2 full weeks of history, or none qualify, every day counts | ✅ | `Stretch.practiceDays` | A full week is a finished week that began on or after the first logged day |
| Stretch states stretch, covered, freeDay, weekCovered, noTarget; stretch = (target - hours before today) / practice days left, nearest 5 min, at least 15 | ✅ | `StretchState`, `Stretch.todayStretch` | Nothing stored. `StretchPlan` is the fixed part, so today's own sessions never move it. Target from the TargetPeriod history |
| Done today = every session that starts today plus the running timer | ✅ | `StretchSource.runningSeconds` | A timer started before midnight counts towards the day it started |
| Tests for rounding, minimum, short yesterday, today's sessions, rest days, week covered, no history, Sunday vs Monday, midnight, time zone | ✅ | `LongGameTests/TodayStretchTests.swift` | 308 tests pass |
| Home third tab Today / This week / The long game; opens on Today, after onboarding on The long game once | ✅ | `HomeView`, `HomeTab`, `AppSettings.lastHomeTab` | A value saved by an older version (This week) also opens on Today. With no target, Today shows This week instead |
| Arc, gold travelled line, moon; sun glides between arc and scale in 0.6 s (Reduce Motion: no glide) | ✅ | `GaugeHero`, `StretchArt` | Same sun and sea components and water rule |
| Big number, 'of today's ...', one quiet line, exact texts for every state; VoiceOver reads the picture as one element | ✅ | `TodayContent`, `StretchText` |  |
| Duo wide layout has the third tab | ✅ | `HomeView.widePage` | Checked in code and the build; not seen on a Duo-shaped simulator |
| No strip on the Timer (update 21). When covered mid-session the sun winks once and a quiet gold line 'Today's stretch covered' shows under 'Next ray in'; never interrupts | ✅ | `TimerView` | Driven by the timer's own TimelineView. No sheet, alert, sound or extra haptic. `StretchStrip.swift`, its strings and glass style are deleted. Checked by build and tests; I did not get to look at the Timer in the Simulator after the change |
| Finish sheet line 'Today's stretch covered.' | ✅ | `FinishSheet` | Only if this session covered it; follows the trimmed time |
| Live Activity, widgets, Watch unchanged | ✅ |  | They show This week or The long game as before |
| Debug options for hours this week before today and a rest day | ✅ | Settings, Debug only |  |
| New text in the String Catalog | ✅ | `Localizable.xcstrings` |  |

## Home

| Requirement | Status | Where | Note |
| --- | --- | --- | --- |
| No cards; segmented control This week \| The long game under the header | ✅ | `HomeView`, `LGSegmentedControl` | Changed after your note: Home opens on The long game right after onboarding (once), and on This week at every launch after that. The tab you tap is not remembered (`HomeView.chooseOpeningTab`) |
| Craft name with History and + stays on top as a bar | ✅ | `HomeView.columnPage` | The header is pinned and the page scrolls under it. On a wide window the left pane never scrolls, so it was already fixed |
| Sun as a gauge: vertical scale, navy pill at the sun's height, dashed gold line | ✅ | `GaugeHero`, `GaugeGeometry` | Scale labels use #68718C instead of the design's #8A93AB (2.9:1) to reach 4.5:1 |
| Sun's centre linear from the horizon to the top tick; above 100% it stays up with open eyes | ✅ | `GaugeGeometry.centreY`, `HomeGauge.reachedTop` | Matches the design's heights (6.5 of 12 h at 146 pt, 3,294 h at 175 pt) |
| This week scale 0 → target (ticks 0, half, target); long game 0 → 10,000 (every 2,500) | ✅ | `HomeGauge` | With no target yet, this week's scale uses the recent pace rounded |
| Tab switch: sun glides 0.6 s, labels cross-fade | ✅ | `GaugeHero` (animatable), `HomeView.selectTab` | Checked frame by frame. With Reduce Motion the sun jumps and only the labels fade |
| This week: "6.5 h", "of 12 h this week · 54%", 7 day bars, target row | ✅ | `CountingWeek`, `DayBarsRow`, `TargetRow` | The percentage is never 100% before the target is met |
| Day bar tap opens that day in History | ✅ | `DayBarsRow`, `HistoryView(day:)`, `CalendarTab` | Days still to come are not buttons |
| Target row: "5.5 h to go · 3 days left" / "Target reached · +1.5 h", "Your pace for the year…", opens the target screen | ✅ | `TargetRow`, `WeekTarget` | |
| The long game: total, "of 10,000 hours · N%", Pace / By Nov 2027 / Finish line, Meet your future self row | ✅ | `CountingTotal`, `HomeView` | "By …" is the target times the share of the year left; "–" with no target. The row has no sun icon, as in the design |
| Recent rows removed from Home | ✅ | `HomeView` | Sessions live in History and on the day bars |
| Opaque sea always covers the lower sun; animation and Reduce Motion kept | ✅ | `SunriseCanvas`, `SeaFill`, `AboveWater` | Pixel tests at 8 heights, 3 widths and every wave phase |
| Start session / Add past hours; "Back to session" or "Resume" | ✅ | `HomeView` | Your checklist says "Resume" while running; the spec says "Back to session" |
| Header: craft name, History, + and Settings | ✅ | `HomeView`, `HistoryView` | Changed after your note: the Settings gear is in the Home bar too (History still has its own gear) |
| No info icon, About, Line of the day | ✅ | | `design/About.dc.html` is still in the folder (not in the app) |

## History

| Requirement | Status | Where | Note |
| --- | --- | --- | --- |
| Calendar: 53 weeks, blue rest, four levels, tap a day, edit/delete | ✅ | `CalendarTab`, `Practice.swift` | |
| Rhythm, Steady for, Active days; no streaks; no icon by Rhythm | ✅ | `CalendarTab`, `Practice.swift` | `README.md` and `CLAUDE.md` said "streaks": reworded |
| Growth: past, dashed forecast, band, sun, "Finish line · 10,000 h", no legend, no weekly card | ✅ | `GrowthTab` | |
| Forecast per "Forecast algorithm" (30 y limit, blended pace) | ✅ | `Logic/Forecast.swift` | |
| "after YYYY" for a scenario that misses 30 years | ✅ | `ForecastText.range` | Fixed: "Likely between 2034 and after 2056" |
| "Not within 30 years" text | ✅ | `ForecastText.range` | |
| What-if slider live, not saved | ✅ | `GrowthTab` | |

## Timer

| Requirement | Status | Where | Note |
| --- | --- | --- | --- |
| Timestamp-based, survives closing | ✅ | `TimerState`, `TimerStore` | |
| Live Activity + Dynamic Island with Pause/Resume and Finish | ✅ | `LongGameWidgets` | Fixed: lock-screen buttons now have VoiceOver labels (Pause/Resume, Finish). Not testable in the Simulator |
| Finish sheet: duration ±5 min, note, Save, Discard | ✅ | `FinishSheet` | |
| 4 h notification, 12 h auto-pause | ✅ | `Notifications`, `TimerState` | |
| Total in gold with one decimal, counting up | ✅ | `TimerView` | |
| "This session" + clock + caption "Next ray in m:ss" only | ✅ | `TimerView`, `SunHour.caption` | |
| Animation table rows | ✅ | `TimerView`, `SunView`, `TimerSky` | Breathing, halo, motes, turning, rays, wink, sky, golden hour, pause, resume, finish all present |
| Hour bounce + sparkle ring | ✅ | `TimerMoments`, `TimerView` | |
| No quote | ✅ | | |
| Reduce Motion | ✅ | `TimerView`, `HomeView` | Fixed: the "Saved" burst and jump, and the Home count-up, now respect Reduce Motion |
| Text contrast ≥ 4.5:1 on the timer sky | ✅ | `TimerSky`, `TimerView` | Fixed: the sky now ends in plum (#7B4378, as dark as the design's #6E3D74) and secondary text is 80% white: 4.9:1 or better everywhere |
| VoiceOver "N of 12 rays lit, M minutes…" with correct plural | ✅ | `TimerView`, `TimerLogic` | Fixed: "1 minute into this hour" |

## Other flows

| Requirement | Status | Where | Note |
| --- | --- | --- | --- |
| Add past hours: day, hours 0–12, minutes by 5, note 280, "Add N hours", no future, ≤ 24 h a day | ✅ | `SessionFormView` | Date picker lower bound fixed (see above) |
| One craft sheet and confirmation and archiving | ✅ | `OneCraftSheet` | Spec Screen 0 says Welcome shows "after Replace my craft"; Screen 8 says it opens step 1. Decided: Welcome shows again; code and spec updated |
| Welcome back: 7-day rule, once per 7 days, week sliders, average slider, even split, "Added after a break" | ✅ | `CatchUp.swift`, `CatchUpSheet` | |
| Welcome back copy | ✅ | `CatchUpSheet` | Fixed: copy says "practise" in all three places; the sun has open eyes |

## Accounts, sync, notifications, settings

| Requirement | Status | Where | Note |
| --- | --- | --- | --- |
| Works with no account | ✅ | | |
| Sign in with Apple | ✅ removed | | Update 21: code, `AuthenticationServices`, entitlement, Settings rows and strings are gone. There was no test for it |
| Save to iCloud: SwiftData + CloudKit private database only when the setting is on, otherwise a local-only store; switching reopens the same database file without losing data; last edit wins per session; running timer is device-local | 🟡 | `CloudSync.swift` (`StoreHost`), `LongGameApp` | Store choice and switching are unit-tested with in-memory stores. Real syncing between devices needs a real iPhone signed in to iCloud, not tried here |
| Settings → iCloud group: switch, status line (Up to date / Syncing… / Last synced 10:42 / sign-in hint), Delete iCloud copy with confirmation that leaves this device's data | 🟡 | `SettingsView`, `ICloudMonitor`, `SyncStatus` | Logic tested; "Delete iCloud copy" turns sync off first, then removes the CloudKit zone. The zone delete itself needs a real iCloud to try |
| Export CSV, Delete all data | ✅ | `SettingsView` | |
| YearEstimates editable; archived crafts listed | ✅ | `EstimatesEditorView`, `ArchivedCraftsView` | |
| Settings reachable | ✅ | `HomeView`, `HistoryView` | The gear in the Home bar, and the gear in History |
| Notifications off by default, asked after first saved session | ✅ | `HomeView`, `Notifications` | |
| Daily reminder | ✅ | `NotificationPlanner` | |
| Rhythm nudge (no streak notification) | ✅ | `ReminderPlanner` | |
| Long session | ✅ | `Notifications` | |
| Milestone notification | ✅ | `Milestones.nextCrossing`, `Notifications`, `HomeView` | Added: while a session runs, a notification is planned for the moment its hours carry the total over the next milestone; pausing or finishing cancels it |
| Milestones 100…10,000, each once | ✅ | `Milestones`, `HomeView` | |

## Look and copy

| Requirement | Status | Where | Note |
| --- | --- | --- | --- |
| Flat cards, no shadows | ✅ | `LGCardModifier` | |
| Tokens and sizes from Visual system | ✅ | `Colors`, `Typography` | |
| SF Pro only; no serif/Newsreader | ✅ | | |
| Every string in the String Catalog | ✅ | `Localizable.xcstrings`, `project.yml` | Fixed: 83 missing strings added, 3 stale ones removed; `SWIFT_EMIT_LOC_STRINGS` turned on so Xcode keeps it in step |
| Pluralised number+word labels | ✅ | `Labels.swift` | The rays VoiceOver line is now pluralised too |
| Dynamic Type up to XXXL | ✅ | | Checked at the largest accessibility size on Home, History and Settings. Text wraps and numbers scale down; the stats tiles got a little extra side padding |
| VoiceOver labels on icon buttons and charts | ✅ | | Lock-screen buttons labelled |
| Reduce Motion everywhere | ✅ | | See Timer |
| Minimum 44 pt touch target | 🟡 | `CalendarTab` | The 14 pt calendar squares are smaller by design; the day still opens from a tap |

## Widgets

| Requirement | Status | Where | Note |
| --- | --- | --- | --- |
| Small: sun over the sea at the right height, "6.5 h / of 12 h this week"; App Intent choice This week / The long game | ✅ | `SunWidget`, `SmallSunWidgetView`, `ChooseViewIntent` | Checked on a Simulator Home Screen (it showed "3 h", then "4 h" after saving an hour). The Edit Widget choice itself was not tapped |
| Medium: this-week scene, two bars (gold, navy), "Today 1 h 30 m" | ✅ | `OverviewWidget`, `MediumSunWidgetView` | Drawn and compared with the design; the long-game bar opens the long game tab |
| Lock Screen circular, rectangular, inline | ✅ | `CircularSunWidgetView`, `RectangularSunWidgetView`, `InlineSunWidgetView` | Drawn in tests; not seen on a real Lock Screen. They follow the Lock Screen tint |
| Opaque sea covers the sun at every height | ✅ | `WidgetPictureTests` | Both sizes, three widths |
| Shared App Group data | ✅ | `WidgetSnapshot`, `WidgetBridge` | The app mirrors only what is stored (no totals); the widgets compute with the same Logic |
| Deep link into Home on the matching tab | ✅ | `WidgetLink`, `HomeView.onOpenURL`, `project.yml` | `longgame://home/week` and `longgame://home/longGame`; checked in the Simulator |
| Reload when a session is saved, at midnight, at the start of each week | ✅ | `WidgetBridge.publish`, `WidgetModel.timelineDates` | |

## Apple Watch

| Requirement | Status | Where | Note |
| --- | --- | --- | --- |
| Two swipeable pages (This week with Start, The long game): sun, scale, big number | ✅ | `WatchHomePage`, `WatchScene`, `WatchRoot` | Drawn and compared with the design; not run on a watch (no watchOS Simulator is installed) |
| Timer: focus sun with lit rays, clock, total and next ray, Pause/Resume, Finish | ✅ | `WatchTimerView`, `WatchRoot` | "3,294.7 h · next ray 2:42" matches the design |
| Haptic when a ray lights | 🟡 | `WatchRoot` (`WKInterfaceDevice`) | Plays while the app is on screen. The watch stops the app when the wrist drops, so no tap in the background |
| Finished screen | ✅ | `WatchFinishedView` | Under a minute nothing is saved |
| Complications: circular, rectangular, corner, inline | ✅ | `LongGameWatchWidgets` | Built; not seen on a watch face |
| One session at a time across phone and watch | ✅ | `TimerUpdate`, `TimerStore.applyRemote`, `WatchStore`, `WatchBridge` | The newest change wins; the watch's Start becomes the phone's "Back to session" and its Live Activity |
| Saved sessions | ✅ | `FinishedSession`, `WatchBridge.save`, `PendingSessions` | See Decisions: sent over WatchConnectivity, saved once on the phone (same id) |
| Phone out of reach: watch keeps the session and sends it later | ✅ | `WatchConnection.send`, `PendingSessions` | Queued by the system; it still counts on the watch until the phone has it |
| "Set up Long Game on your iPhone first." | ✅ | `WatchSetupView` | |

## Edge cases

| Requirement | Status | Where |
| --- | --- | --- |
| Time-zone/clock change during a timer | ✅ | `TimerState` (absolute timestamps) |
| Session crossing midnight counts on its start day | ✅ | `Practice.dailySeconds` |
| Editing estimates later, no repeat celebrations | ✅ | `EstimatesEditorView` |
| Deleting a day's only session turns it back to rest | ✅ | `PracticeDaysTests` |
| Passing 10,000 h | ✅ | `Totals`, `SunriseScene` |
| Far-back start year: "Set all to" | ✅ | `YearlyHoursView` |

## Tests

| Requirement | Status | Where |
| --- | --- | --- |
| Baseline, pace, forecast | ✅ | `LogicTests` |
| Rhythm, Steady for | ✅ | `RhythmTests` |
| Catch-up gap, week blocks, even split, once-a-week rule | ✅ | `CatchUpTests` |
| 24 h day limit | ✅ | `SummaryTests.dayLimit` |
| Pluralisation | ✅ | `LabelTests` |
| Milestone notification timing, "after YYYY" text, comma grouping | ✅ | `AuditTests` |
| 12-month window, TargetPeriod history, end-of-year reminder and sheet, forecast rule, week row text | ✅ | `WeeklyTargetTests` |
| Gauge mapping, ticks, day bars, year outlook; sea covers the sun at every height | ✅ | `HomeGaugeTests`, `SunriseTests` |
| Widget numbers, timeline dates, deep links, shared snapshot, widget pictures | ✅ | `WidgetTests` |
| Phone-watch messages, newest timer wins, pending sessions, saving once, watch screens and sea | ✅ | `WatchTests` |
| The database stays in the app's folder | ✅ | `StoreLocationTests` |

## Decisions for you

1. ~~"I already have an account" on Welcome.~~ Decided in update 21: no account at all. iCloud saving replaces it, and Welcome back offers the game it finds. See the iCloud rows above.
2. ~~Starting this year skips step 3?~~ Decided: no skip. Step 3 shows one slider for this year, and the spec now says so.
3. ~~Welcome after "Switch to a new game"?~~ Decided: show Welcome again. App and spec (Screen 8) updated.
4. ~~Settings entry.~~ Decided: the gear is in the Home bar (next to History and +). History keeps its own gear; say if you'd rather remove it.

5. **Pace and the 25% rule.** I compared the target with the Home **Pace** stat (the recent pace, blended with your estimate early on). Tell me if you meant the forecast pace.
6. **"In a year" on the target screen** shows what a target *would* do (finish date with 12 months on that rate), even when your pace is too far from it for Home's forecast to use it. A bold target can therefore show an earlier finish there than on Home.
7. **Watch data: WatchConnectivity, not a CloudKit database on the watch.** The spec says the watch uses "the shared CloudKit store". That would need its own iCloud setup on the watch and sync switched on, so instead the phone stays the one store: it sends the watch its stored data, and a session finished on the watch travels to the phone (queued, saved once). iCloud sync of the phone's database is untouched. Say if you want the CloudKit route later.
8. **Apple Developer account, once you build to real devices.** The App Group `group.com.wehavesun.LongGame.shared` is in the app, the widgets and both watch targets. The watch app is `com.wehavesun.LongGame.watchkitapp` and its complications `…watchkitapp.Widgets`. I did not touch your account: with automatic signing Xcode should offer to register these when you build to a device.
9. **Two sessions in one folder.** A second Claude session (iPhone Duo) edited this folder at the same time, so some changes are mixed (see the commit messages). Using separate worktrees avoids it.

## Where the spec and a design file disagree (the spec won)

| Where | Design says | Spec says | App does |
| --- | --- | --- | --- |
| Hours per week, each year | Slider 0–30 | 0–40 | 0–40 |
| Welcome back | "Did you keep playing since then?" | "Did you practise since then?" | Spec |
| Add past hours | Typed numbers for hours and minutes | Hours 0–12, minutes in 5s | Pickers, per spec |
| Calendar Rhythm | Median of the last 8 weeks, current week counted for Steady for | 8 complete weeks plus the current week | Spec. An unfinished current week never ends a run |
| Timer sky | Ends at #6E3D74 | Navy to violet to rose | Ends in plum for contrast (4.5:1) |
| Home button while a timer runs | n/a | "Back to session" (your checklist says "Resume") | Spec |

Also: the spec's Forecast section says the Growth card "still shows the real value" of the yearly trend, but Screen 6 removes the weekly-rate card, so nothing on screen shows it any more.

## Not done or not testable here

- Live Activity and Dynamic Island: built, but the Simulator cannot show them; check on a device.
- iCloud sync between devices, Welcome back from a real iCloud game and the CloudKit zone delete: need a real iPhone signed in to iCloud (the Simulator has no iCloud account unless you sign one in). Also, before a TestFlight or App Store build, the CloudKit schema must be deployed to Production in the CloudKit Dashboard.
- The Apple Watch app and complications: no watchOS Simulator is installed here (downloading one is several GB), so they are compiled for the watch simulator SDK and checked through shared code, tests and drawn pictures, but never run. Pairing, WatchConnectivity delivery, haptics and the watch face need a real watch or the watchOS Simulator.
- Lock Screen and medium widgets on a real device, and the Edit Widget choice.
- Real notification delivery (daily, rhythm nudge, long session, milestone): scheduled in code and unit-tested, but not seen arriving.
- The 14 pt calendar squares are smaller than 44 pt by design. Each day is still a single tap target with a VoiceOver label.
- `design/About.dc.html` is still in the folder (the app has no About screen). Delete it if you do not want it.

## How to check the main flows in the Simulator

Run with `-demoData` for sample data.

- **Today's stretch:** Home opens on Today. In Settings, Debug only, set 'Hours this week before today' (0 for a fresh week, a few hours for a short week, your target or more for 'This week is covered') and switch 'Today is a rest day' on or off, then go back to Home. Start a session to watch the Timer strip fill. With a stretch of 15 minutes, a 15 minute session shows the gold covered state, the wink and the Finish line.
- **The sun giggles:** tap the sun on Home (any tab), on an intro page or in 'Meet your future self'. Tap it five times quickly for the big laugh with the spinning rays; for the next 3 seconds taps only get a wink. On the Timer a tap only winks. Settings -> Giggle sound turns the laugh off. The Simulator plays the sound through your Mac (keep the volume up); the Ring/Silent switch and the haptics need a real iPhone.
- **Scrub the forecast:** Run with `-demoData`, open History (calendar icon), Growth, tap the chart or the small expand button. Drag a finger along the line; the hint disappears for good after the first drag. The Simulator has no haptics, so the taps need a real iPhone.
- **Compare the two looks (Liquid Glass):** run the LongGame scheme on an iOS 26 or later Simulator for the glass look, and on an iOS 18 Simulator (or any version before 26) for the flat look. In Xcode, open `GlassPreviews.swift` and its canvas: each preview shows glass on the left and the old flat look on the right.
- **Your year card:** Settings -> Debug only -> 'Fill a sample year'; back on Home go to History (calendar icon) -> Growth, scroll to the bottom row 'Your 2026'. Try the three looks and the Show hours switch, long-press a tile on Photos, then Share (Save Image, Messages). 'Remove the sample year' undoes it.
- **Note and photo:** Start a session, Finish: the dashed square and the note field sit above Save; pick a photo from the library, Save. History: the day shows a white dot, the day card a 56 pt thumbnail; tap it for the viewer. Tap the row for the editor.
- **Home:** three tabs. This week: the sun at this week's height on the scale, day bars (tap one), the target row. The long game: total, three stats, Meet your future self.
- **Your pace for the year:** the target row on This week (or step 4 of onboarding). Settings → Debug only → "Year of pace ends in 10 days" / "ended yesterday" shows the reminder and the new-year sheet.
- **Widgets:** long-press the Home Screen → Edit → Add Widget → Long Game. Save a session and the widget redraws.
- **Apple Watch:** open `LongGame.xcodeproj`, run the LongGame scheme on an iPhone paired with a watch (or the watchOS Simulator), then the LongGameWatch scheme target on the watch.
- **Settings:** the gear at the top right of Home (or History → gear).
- **Hour steppers (− and +):** Onboarding: Get started → pick a craft → pick a start year → step 3 has one stepper row per year (tap − or +, hold for 0.4 s to repeat, tap the number to type it; changing a year shows "Use N h for the years after YYYY"). Continue gives Your pace for the year, a big stepper in half hours with quick picks. Later: Home → This week → the target row. In Settings, Your estimates uses the same rows. The Simulator has no haptics. Previews of both components (default, AX5, flat look, night sky) are at the bottom of `HoursStepper.swift`. VoiceOver: swipe up/down on a stepper to change it. Growth's "What if I practise more?" is still a slider on purpose.
- **New onboarding (update 21):** delete the app from the Simulator (long-press → Remove App), run it again: Welcome → three intro pages → 1 game → 2 year → 3 hours → 4 weekly pace → 5 Keep your game safe → Start playing.
- **iCloud switch:** step 5 and Settings → iCloud. On a real iPhone signed in to iCloud the switch is on and you can turn it off and on; the status line shows Syncing… then Up to date. With no iCloud account (the Simulator by default) the switch is off and disabled.
- **Welcome back from iCloud:** with iCloud saving on and some hours saved, delete the app and install it again on the same Apple Account: after Welcome appears, "Welcome back · We found your game in iCloud" replaces it within 3 seconds.
- **Welcome back (after a break):** Settings → Debug only → set the days with the stepper (7–27 gives one − / + row per week, 28+ gives one big stepper for the average) → "Show Welcome back on Home". It takes you back to Home with the sheet open.
- **Hour bounce:** Settings → Debug only → "Jump total to just under a whole hour" → Start session. About 20 seconds later the sun bounces and a ring of sparkles shimmers.
- **Milestone notification:** same jump, but choose a total just under a milestone first (for example edit estimates in Settings → Your estimates so the total is near 100, 500, 1,000…), allow notifications, start a session and lock the phone.
- **Reduce Motion:** Settings app → Accessibility → Motion → Reduce Motion, then save a session.
- **Largest text:** Settings app → Accessibility → Display & Text Size → Larger Text.
