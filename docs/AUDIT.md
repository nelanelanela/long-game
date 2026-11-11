# Audit: app vs `docs/SPEC.md` and `design/`

Source of truth: the spec. ✅ done · 🟡 partly done · ❌ missing.
Updated after update prompt 26 (a simple daily stretch, no 40 h cap, a forecast at the chosen pace, today's sessions). Earlier: update prompt 20 (the app icon that grows). Earlier: update prompt 16 (scrub the forecast). Earlier: update prompt 14 (Liquid Glass). Earlier: update prompt 13 (your year card). Earlier: update prompt 12 (a note and a photo). Earlier: update prompt 11 (Today's stretch, no glints on the water). Earlier: update prompt 09 (your pace for the year, Home tabs, widgets, Apple Watch). Every row shows its final status, with what changed in the Note column.
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

## A simple stretch, no 40 h cap, the chosen-pace forecast, today's sessions (update prompt 26)

| Requirement | Status | Where | Note |
| --- | --- | --- | --- |
| Stretch = weekly pace ÷ 7, nearest 5 min, same every day (7 h → 1 h, 12 h → 1 h 45, 3 h → 25 m) | ✅ | `Stretch.stretch(weeklyHours:)` | Never 0: a tiny pace gives 5 m. **100 h gives 855 m, not 857:** 857 is not a multiple of 5, so I followed the "nearest 5 minutes" rule. Tell me if you want 857 |
| Practice-day guessing, free day, "week covered", carry-over removed (logic, screens, strings, VoiceOver, debug switches, tests) | ✅ | `TodayStretch.swift`, `TodayContent`, `SunWords`, `DebugOptions`, `SettingsView` | The two Debug rows for the stretch are gone |
| `StretchState` has `.inProgress` and `.covered` | 🟡 | `StretchState` | Plus `.noTarget`, which Home needs to fall back to This week when no pace is set yet |
| Covered state, moon and "40 m to the moon" kept | ✅ | `TodayNumber`, `TodayQuietLine` | |
| Hours-per-week limits are 168 (yearly rows 0–168, pace 1–168 in halves, Catch-up 0–168); `YearEstimate` clamps to 0–168; entry sheet says "0 to 168" | ✅ | `WeeklyTarget.maxHours`, `HoursStepSpec`, `CatchUp.maxWeeklyHours`, `YearEstimate.clamped` | One constant. The 24 h limit for a single day is unchanged |
| Forecast = two straight lines from today: chosen pace (+ What-if extra) and recent pace; Low/Mid/High, trend, band and the 25% rule removed | ✅ | `ForecastEngine.line`, `Forecast`, `ProgressSummary` | With no pace chosen, the chosen line uses the recent pace |
| Chosen-pace date everywhere: Growth headline, Home Finish line, Meet your future self, Your year, scrubbing, Watch | ✅ | `forecast.chosen` | |
| Growth chart: dashed orange chosen line with the sun and "Your pace"; dotted grey (#9AA1B5, dash 1–6, round caps) recent line with "Recent pace"; no band, no legend | ✅ | `GrowthChartView` | The chart runs to the later of the two finish dates (30 years at most) |
| Headline, "At your recent pace: around 2039", "after YYYY", "You're already playing at this pace", "You crossed the finish line on 12 May 2035"; What-if text "On top of your chosen pace of 12 h a week." | ✅ | `ForecastText`, `GrowthTab` | |
| Full screen: same two lines, draw-in past → dashed → dotted → sun, future points read "At your chosen pace", VoiceOver describes both lines | ✅ | `GrowthScrubView`, `DrawProgress`, `GrowthChartDescriptor` | The draw-in is now driven frame by frame (it used to be a sliding mask). Reduce Motion: a 0.2 s fade |
| Today's sessions: header, one row per session that started today (oldest first), "Now · 12 m" with a pulsing dot first, tap to edit in the History sheet, hidden when empty, VoiceOver text | ✅ | `TodaySessionsView.swift`, `Logic/TodaySessions.swift`, `HomeView` | The whole Today page scrolls (hero included) with Start session and Add past hours pinned, as on the other tabs. A running row is not tappable |
| Previews with 0, 2 and 6 sessions plus a running timer, and AX5 | ✅ | `TodaySessionsView.swift` | |
| Tests | ✅ | `TodayStretchTests`, `HoursSteppingTests`, `WeeklyTargetTests`, `CatchUpTests`, `LogicTests`, `GrowthTests`, `TodaySessionsTests` | 476 tests pass |

Not seen: the Growth chart, its full-screen draw-in and the Today list at AX5 in the Simulator (only the Today tab with one session). Check them by hand (below).

## Today's stretch (update prompt 11)

| Requirement | Status | Where | Note |
| --- | --- | --- | --- |
| No gold glints on or in the water, anywhere | ✅ | `SunriseHero`, `SunriseMotion` | Layer order glow, sun, sea fill, pale wave, navy line. The widgets and Watch draw their own sea and have no glints |
| Practice days: practised on the weekday in at least 2 of the last 4 full weeks; under 2 full weeks of history, or none qualify, every day counts | ✅ | `Stretch.practiceDays` | A full week is a finished week that began on or after the first logged day |
| Stretch states stretch, covered, freeDay, weekCovered, noTarget; stretch = (target - hours before today) / practice days left, nearest 5 min, at least 15 — **replaced in update 26 by weekly pace ÷ 7** | ✅ | `StretchState`, `Stretch.todayStretch` | Nothing stored. `StretchPlan` is the fixed part, so today's own sessions never move it. Target from the TargetPeriod history |
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
| Growth: past, dashed chosen-pace line with the sun, dotted recent-pace line, "Finish line · 10,000 h", no band, no legend, no weekly card (update 26) | ✅ | `GrowthTab`, `GrowthChartView` | |
| Forecast per "Forecast algorithm" (30 y limit, blended pace) | ✅ | `Logic/Forecast.swift` | |
| "after YYYY" for a line that misses 30 years | ✅ | `ForecastText.headline`, `year`, `recentLine` | "At your recent pace: after 2056" |
| "Not within 30 years" text | ✅ | `ForecastText.headline` | The likely-range sentence is gone (update 26) |
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

## Mac app (update 28)

**Done**
- **Part 1, shared code:** target "LongGame Mac" (macOS 14+, bundle ID `com.wehavesun.LongGame`, the same as the iPhone's, which is what universal purchase needs). It compiles `Models/`, `Logic/`, `DesignSystem/`, `Features/` and the shared app files. iPhone-only code is behind `#if os(iOS)`: Live Activities (`LiveActivityManager` is a no-op stub on Mac), the Watch link (`WidgetBridge`), alternate icons (`AppIconManager` has a Mac twin in `LongGameMac/`), camera, haptics, Screen Time apps in Focus. UIKit images became `PlatformImage` (`DesignSystem/PlatformImage.swift`); iPhone-only modifiers have Mac stand-ins in `PlatformShims.swift`. The Mac test scheme runs the same `LongGameTests` (iCloud, Tip jar, Watch and store-location tests are skipped there).
- **Part 2, the window:** 1180 x 740 (minimum 900 x 600), hidden title bar, the iPad sidebar layout at Mac size (a plain sidebar, not `NavigationSplitView`: the iPad layout already did the job and the two stay identical), File/View/Session menus with the shortcuts.
- **Part 3, the menu bar:** `MenuBarExtra` in window style (`LongGameMac/MenuBarSun.swift`). The words come from `Logic/MenuBarText.swift`; the running clock is `Text(timerInterval:)`, never a counter. Settings -> Show in Dock (on by default, stored on this Mac only); off uses the accessory activation policy.
- **Part 4, one session everywhere:** `ActiveSession` is a new SwiftData model in the same store. When Save to iCloud is on, every timer change is written to it and every record that arrives from another device is turned into what this timer does (`Logic/ActiveSessionLogic.swift`, `App/ActiveSessionSyncer.swift`). The earlier start wins; the later device switches to it and shows "Started on <device>". Pause, resume and finish on either device reach the other. The Watch still talks to the iPhone through WatchConnectivity, and a change that comes from iCloud is passed on to it.
- **Images:** drop a picture (or a picture file from the Finder) on a session row or the Finish sheet's photo square (`DesignSystem/ImageDrop.swift`).
- **Dock icon:** with "App icon grows with you" on, the Dock icon is drawn for the current stage at launch and whenever the stage changes (`NSApp.applicationIconImage`).
- **Widgets:** target "LongGameMacWidgets" (the sun, and this week with the long game; no Lock Screen shapes). It builds, but it is not embedded in the Mac app yet (see below).
- **Tests:** `ActiveSessionTests` (earlier start wins, pause/resume/finish from the other device, stale records), `MenuBarTests` (menu bar text running, paused and idle, Dock default).

**Not checked, and why**
- I could not open the Mac app's window or menu bar on a screen here, so none of it has been seen running. Please run it (below) and look at the window, the menu bar sun and its popover. If the sun and the text do not show side by side in the menu bar, tell me.
- iCloud sync between a Mac and an iPhone cannot run until the steps below are done. The conflict rules are unit-tested; the sync itself has never run on two real devices.
- A session started on the Mac reaches an iPhone that is in the background only as fast as iCloud delivers it (usually seconds, sometimes longer); the Live Activity can only start while the iPhone app is open.
- A session started on a Mac that is asleep or offline has no record in iCloud until it is back online; if two sessions start in that time the earlier start still wins afterwards.
- Notifications: the same code as the iPhone (`Notifications.swift`) runs on Mac and is unit-tested, but I have not seen one arrive. macOS asks for permission the first time a session starts.
- Liquid Glass on macOS 26 is used through the shared button styles behind `if #available(iOS 26, macOS 26, *)`; not seen.
- Menu commands (Start session, Add past hours, the View shortcuts) open the window first if it was closed; not seen on screen.
- Accessibility: the same labels as the iPhone; the menu bar item and popover have their own labels. Keyboard: the menus carry every shortcut. I have not run VoiceOver or the Accessibility Inspector on the Mac.

## What to do in your Apple Developer account and App Store Connect for the Mac version

None of this has been done. Until you do it, the Mac app runs locally from Xcode with no iCloud, and the Mac widgets are not embedded.

1. **developer.apple.com -> Certificates, Identifiers & Profiles -> Identifiers**
   - Open the app ID `com.wehavesun.LongGame`. Under the **Mac** (macOS) platform, make sure it is enabled for both iOS and macOS (a universal app ID). If Xcode offers to register the Mac app for you when you choose your team in Signing, that does the same thing.
   - Tick **iCloud** and open Configure: choose the existing container `iCloud.com.wehavesun.LongGame` (the same one the iPhone uses). Do not make a new container.
   - Tick **App Groups** and choose `group.com.wehavesun.LongGame.shared`. On a Mac the group name for a sandboxed app is usually prefixed with your Team ID (for example `ABCDE12345.com.wehavesun.LongGame.shared`); Xcode shows the right name when you add the capability. Tell me what it says and I will change `WidgetSnapshot.groupID` for the Mac.
   - Add a second identifier for the Mac widgets, `com.wehavesun.LongGame.sunwidgets`, with the same App Group.
2. **In Xcode** (project -> target "LongGame Mac" -> Signing & Capabilities)
   - Choose your team (We Have Sun). Add **iCloud** (tick CloudKit and the same container), **App Groups** and **App Sandbox** (tick Outgoing Connections; File Access: User Selected File Read Only for the picture drop and the CSV import). Do the same for "LongGameMacWidgets" (App Sandbox and App Groups).
   - Stop here and tell me. I then turn on the `CLOUD_SYNC` flag for the Mac target, add the entitlements to `project.yml`, embed the widget extension in the Mac app, and check that it still builds. I will not touch signing before you say.
3. **CloudKit Dashboard** (icloud.developer.apple.com -> container `iCloud.com.wehavesun.LongGame`)
   - Run the Mac app (or the iPhone app) once from Xcode with iCloud on so the new `ActiveSession` record type appears in the **Development** environment.
   - Then **Deploy Schema Changes to Production**. Without this the running-session sync works in testing but not for App Store and TestFlight builds. This is the same step as for the other record types.
4. **App Store Connect**
   - Open the Long Game app record and choose to add the macOS platform (**+ next to the platform list -> macOS**). Using the same bundle ID gives you universal purchase: one purchase and one price for iPhone, iPad and Mac. The first macOS version number can match the iPhone's.
   - Fill in the Mac version page: screenshots (the Mac sizes are 1280 x 800 up to 2880 x 1800; at least one), description, keywords, and the Mac category (Productivity). The privacy answers are the same as the iPhone's.
   - The tip jar in-app purchases are shared by universal purchase; nothing to recreate.
   - Upload the Mac build from Xcode (Product -> Archive with "My Mac" as destination -> Distribute App -> App Store Connect). Mac apps are notarised automatically on upload.
5. **Signing for people outside the App Store** is not needed unless you want to hand out the Mac app yourself; say so and I will cover Developer ID and notarisation.

## How to run the Mac app from Xcode

Open `LongGame.xcodeproj`, choose the **LongGame Mac** scheme and the destination **My Mac**, press Run. Add `-demoData` under Product -> Scheme -> Edit Scheme -> Run -> Arguments for a sample Piano craft. The sun in the menu bar appears at the top right; click it for the popover. Settings (Cmd+,) has Show in Dock. Run the tests with Product -> Test on the same scheme.

## Not done or not testable here

- Live Activity and Dynamic Island: built, but the Simulator cannot show them; check on a device.
- iCloud sync between devices, Welcome back from a real iCloud game and the CloudKit zone delete: need a real iPhone signed in to iCloud (the Simulator has no iCloud account unless you sign one in). Also, before a TestFlight or App Store build, the CloudKit schema must be deployed to Production in the CloudKit Dashboard.
- The Apple Watch app and complications: no watchOS Simulator is installed here (downloading one is several GB), so they are compiled for the watch simulator SDK and checked through shared code, tests and drawn pictures, but never run. Pairing, WatchConnectivity delivery, haptics and the watch face need a real watch or the watchOS Simulator.
- Lock Screen and medium widgets on a real device, and the Edit Widget choice.
- Real notification delivery (daily, rhythm nudge, long session, milestone): scheduled in code and unit-tested, but not seen arriving.
- The 14 pt calendar squares are smaller than 44 pt by design. Each day is still a single tap target with a VoiceOver label.
- `design/About.dc.html` is still in the folder (the app has no About screen). Delete it if you do not want it.

## iPad (update 29)

**Done**
- The app is now universal (`TARGETED_DEVICE_FAMILY = 1,2`); `UIRequiresFullScreen` is removed, so Split View, Slide Over and Stage Manager work. An iPad turns freely on every screen (the iPhone is still held upright except on the timer).
- Layout is chosen from the window's real size (`Logic/WindowShape.swift`), never from the device: sidebar (regular width, wider than tall, at least 1000 pt), tall (regular width, at least 600 pt, taller than wide), the existing two-pane for in-between landscape windows, and the iPhone layouts under about 600 pt. Tests: `WindowShapeTests.swift`.
- Sidebar layout (`Features/Home/SidebarLayout.swift`, `HomeView.sidebarPage`): 260 pt sidebar, 28 pt title bar with the two capsule buttons, sun gauge and 64 pt total on the left, 340 pt card column on the right. Calendar, Growth, Your year and Settings open in the same pane. The code has no iPad-only calls except hover effects, so the Mac app can reuse it.
- Tall layout (`HomeView.tallPage`): floating tabs, 34 pt craft name, 220 pt sun, 72 pt total, two cards side by side, Meet your future self, two 56 pt buttons; content at most 760 pt wide.
- Timer: big iPad windows get the 340 pt sun, the gold 56 pt total and a 104 pt clock with 180 pt Pause/Finish; tall windows lay out like the iPhone timer and scale up 1.35 times.
- Home, the timer and sheets stay where they are while the window changes size: Home is one view that swaps layouts, and the timer and tab live in scene storage.
- Keyboard: ⌘N, Space (timer, not while the Finish sheet is up), ⌘L, ⌘1–⌘5, ⌘, through `App/LongGameCommands.swift` and the timer's own Space button, so holding ⌘ lists them.
- Pointer hover on the sidebar rows, capsules, cards and session rows. Dropping an image on a session row or the Finish sheet's photo square uses the same `PhotoProcessing.prepare` as the picker.

**Not checked, and why**
- Real landscape, Split View and Stage Manager: the iPad Simulator here runs in a windowed mode that won't rotate from code, so I checked the sidebar and tall layouts by laying the app out at 1194 × 834 and at the portrait size (`-debug.windowSize 1194x834`, debug builds only). Please try the real thing with the steps below.
- Pointer scrubbing on Growth uses the chart's own `chartXSelection`, which follows a pointer as well as a finger; not tried with a real pointer. Scribble: the note is a plain `TextField` with nothing blocking it; not tried with a real Pencil.
- Widgets: `SunWidgets.swift` offers small, medium and the Lock Screen sizes; iPad Home Screen also offers large and extra large, which I did not add. Live Activity: unchanged; it shows where iPadOS supports it.
- Tests: all 484 pass on iPhone 16. On the iPad Simulator the four `TipPurchaseTests` (App Store test sandbox) fail some runs and pass others, with different failures each time; nothing else fails.
- Changing the window size from the sidebar layout to another keeps the Play view (Today, This week, The long game) but not Calendar, Growth, Your year or Settings: those fall back to the Home tab.
- Settings is not a button in the tall layout (the spec lists only History and +); reach it from History's gear or ⌘,.
- App Store screenshots for iPad (13-inch, 12.9-inch) will be needed; nothing else in your Apple account.

## How to try the iPad layouts in the Simulator

Run the LongGame scheme on an iPad Pro 11-inch with `-demoData`.
- **Portrait (tall):** the default. Floating tabs on top, big sun, two cards, two buttons at the bottom.
- **Landscape (sidebar):** Simulator menu → Device → Rotate Left (⌘←). The sidebar appears.
- **Split View:** in the Simulator, open Long Game, drag up from the bottom edge for the Dock, press and hold another app's icon and drop it at the right or left edge. Drag the divider: half and a third are the iPhone layout, two thirds is the two-pane layout.
- **Slide Over:** the same, but drop the second app in the middle of the screen.
- **Stage Manager:** Control Centre (swipe down from the top right) → the Stage Manager button. Then drag the window's corner handle to resize: wider than about 1000 pt gives the sidebar, narrow gives the iPhone layout.
- **Keyboard:** press ⌘ to see the shortcuts (the Simulator's hardware keyboard must be on: I/O → Keyboard → Connect Hardware Keyboard). Space pauses the timer.
- **Pointer, drag and drop:** hover with the Mac mouse over rows; drag a picture from Photos (in Split View) onto a session row on Today, or onto the photo square in the Finish sheet.
- **Debug aid:** a debug build also accepts `-debug.windowSize 1194x834` to lay the app out at any size, shrunk to fit.

## Launch screen and opening sunrise (update 30)

- **Launch screen:** `LongGame/App/LaunchScreen.storyboard` (kept out of `Resources/` because the Mac target shares that folder). Vector PDFs and two named colours are in the asset catalogue; `Tools/MakeLaunchAssets.swift` redraws the PDFs. The sea strip is 1440 pt wide, centred, with a solid fill below it, so it spans every iPhone and iPad in both orientations.
- **Opening sunrise:** `Features/Launch/OpeningSunriseView.swift` plays over `AppRoot` on a cold start. The decision is the pure `openingStyle(...)` and the timings are `OpeningTimeline`, both in `Logic/OpeningSunrise.swift` with tests in `OpeningSunriseTests.swift`. Its first frame is the night frame, drawn before anything is decided; nothing waits for SwiftData or iCloud.
- **Sleeping face:** `SunView` has one extra face, `.asleep`, with exactly the launch screen's lines (the existing `.sleepy` has drooping lids, which would not match the still image).
- **Glide:** Home's `GaugeHero` reports where its sun sits on Today's arc (`OpeningCenter.sunTarget`) and the opening sun glides there by position, driven by the same timeline, instead of `matchedGeometryEffect` (which would need a shared namespace through Home).
- **Skipped when opened from:** a link, widget or Live Activity (`onOpenURL`) and a notification tap (the app delegate now answers notification taps with no other change in behaviour).
- **Dark mode:** the app is still forced light, so dark mode plays the sunrise up to dusk and cross-fades into the (light) Home. Home in dark does not exist yet.
- **Known gaps:** the opening is hidden from VoiceOver and a screen-changed notification is posted when it ends, so focus restarts at Home's top, but this has not been tried with VoiceOver on a device. Not hand-checked: landscape, the Mac window, and a notification cold start. The sun is not clipped at Home's waterline for the last frame of the glide.

## How to check the main flows in the Simulator

Run with `-demoData` for sample data.

- **Today's stretch (update 26):** Home opens on Today. The stretch is your weekly pace ÷ 7, the same every day (12 h a week gives "of today's 1 h 45"). Change the pace on This week → the target row and come back. Add past hours (or run a short session) for today: the sun climbs; once the stretch is covered the arc turns gold and it says "You reached the moon."
- **Today's sessions:** on Today, under "45 m to the moon", add a few sessions for today with Add past hours (with and without a note, one with a photo). Each shows as a row with its time range and duration. Tap a row to edit it. Start a timer and go back to Home: a "Now · 12 m" row with a pulsing dot comes first. With no sessions today the section is hidden. Largest text: Settings app → Accessibility → Display & Text Size → Larger Text.
- **No 40 h cap:** in onboarding step 3, the Hours steppers go up to 168; tap the number and type 200: it becomes 168. Your pace for the year also stops at 168 (in half hours).
- **Finish line at the chosen pace:** History → Growth. Dashed orange line "Your pace" ends at the small sun; dotted grey "Recent pace" is below it. The headline says "At your chosen pace, you'll finish around …" and the line under it gives the recent pace. Move the What-if slider: only the orange line and the date move. Tap the chart for full screen: the lines draw in one after another.
- **The sun giggles:** tap the sun on Home (any tab), on an intro page or in 'Meet your future self'. Tap it five times quickly for the big laugh with the spinning rays; for the next 3 seconds taps only get a wink. On the Timer a tap only winks. Settings -> Giggle sound turns the laugh off. The Simulator plays the sound through your Mac (keep the volume up); the Ring/Silent switch and the haptics need a real iPhone.
- **Scrub the forecast:** Run with `-demoData`, open History (calendar icon), Growth, tap the chart or the small expand button. Drag a finger along the line; the hint disappears for good after the first drag. The Simulator has no haptics, so the taps need a real iPhone.
- **Compare the two looks (Liquid Glass):** run the LongGame scheme on an iOS 26 or later Simulator for the glass look, and on an iOS 18 Simulator (or any version before 26) for the flat look. In Xcode, open `GlassPreviews.swift` and its canvas: each preview shows glass on the left and the old flat look on the right.
- **Your year card:** Settings -> Debug only -> 'Fill a sample year'; back on Home go to History (calendar icon) -> Growth, scroll to the bottom row 'Your 2026'. Try the three looks and the Show hours switch, long-press a tile on Photos, then Share (Save Image, Messages). 'Remove the sample year' undoes it.
- **Note and photo:** Start a session, Finish: the dashed square and the note field sit above Save; pick a photo from the library, Save. History: the day shows a white dot, the day card a 56 pt thumbnail; tap it for the viewer. Tap the row for the editor.
- **Home:** three tabs. This week: the sun at this week's height on the scale, day bars (tap one), the target row. The long game: total, three stats, Meet your future self.
- **Your pace for the year:** the target row on This week (or step 4 of onboarding). Settings → Debug only → "Year of pace ends in 10 days" / "ended yesterday" shows the reminder and the new-year sheet.
- **Widgets:** long-press the Home Screen → Edit → Add Widget → Long Game. Save a session and the widget redraws.
- **Apple Watch:** open `LongGame.xcodeproj`, run the LongGame scheme on an iPhone paired with a watch (or the watchOS Simulator), then the LongGameWatch scheme target on the watch.
- **Settings:** the gear at the top right of Home (or History → gear). Home's top bar has no + button any more (update 31): the phone header has History and Settings; the tall iPad page has History and Settings too.
- **Switch to a new game (update 31):** Home → gear → Settings → the practice card, under Archived crafts. It opens the One craft sheet (Keep playing / Switch to a new game with the confirmation). On iPad and Mac it is the same row in the sidebar's Settings. VoiceOver reads "Switch to a new game, button". Built and all tests pass on the iPhone and Mac schemes; not tried by hand in the Simulator yet.
- **Hour steppers (− and +):** Onboarding: Get started → pick a craft → pick a start year → step 3 has one stepper row per year (tap − or +, hold for 0.4 s to repeat, tap the number to type it; changing a year shows "Use N h for the years after YYYY"). Continue gives Your pace for the year, a big stepper in half hours with quick picks. Later: Home → This week → the target row. In Settings, Your estimates uses the same rows. The Simulator has no haptics. Previews of both components (default, AX5, flat look, night sky) are at the bottom of `HoursStepper.swift`. VoiceOver: swipe up/down on a stepper to change it. Growth's "What if I practise more?" is still a slider on purpose.
- **New onboarding (update 21):** delete the app from the Simulator (long-press → Remove App), run it again: Welcome → three intro pages → 1 game → 2 year → 3 hours → 4 weekly pace → 5 Keep your game safe → Start playing.
- **iCloud switch:** step 5 and Settings → iCloud. On a real iPhone signed in to iCloud the switch is on and you can turn it off and on; the status line shows Syncing… then Up to date. With no iCloud account (the Simulator by default) the switch is off and disabled.
- **Welcome back from iCloud:** with iCloud saving on and some hours saved, delete the app and install it again on the same Apple Account: after Welcome appears, "Welcome back · We found your game in iCloud" replaces it within 3 seconds.
- **Welcome back (after a break):** Settings → Debug only → set the days with the stepper (7–27 gives one − / + row per week, 28+ gives one big stepper for the average) → "Show Welcome back on Home". It takes you back to Home with the sheet open.
- **Hour bounce:** Settings → Debug only → "Jump total to just under a whole hour" → Start session. About 20 seconds later the sun bounces and a ring of sparkles shimmers.
- **Milestone notification:** same jump, but choose a total just under a milestone first (for example edit estimates in Settings → Your estimates so the total is near 100, 500, 1,000…), allow notifications, start a session and lock the phone.
- **Reduce Motion:** Settings app → Accessibility → Motion → Reduce Motion, then save a session.
- **Largest text:** Settings app → Accessibility → Display & Text Size → Larger Text.
- **Opening sunrise (update 30):** full version: Settings off, light mode, delete nothing; stop the app in Xcode and run it again (or Settings → Debug only → Play opening sunrise). Short version: turn Reduce Motion on (Settings app → Accessibility → Motion) and relaunch. A running session plays the full sunrise. Dark version: Simulator → Features → Toggle Appearance, then run again: it plays the same full sunrise (update 32 removed the dusk stop). Tap anywhere to skip it. Launch-screen cache: delete the app, or run `xcrun simctl erase all` with the Simulator closed.

## We Have Sun redesign (update 32)

All 13 parts are built on branch `redesign`. Built and tested on the iPhone, Watch, Widgets and Mac schemes; the only failing tests are the 4 StoreKit ones in `TipPurchaseTests`, which fail the same way before the redesign (they need the App Store test sandbox).

- **Launch animation:** Settings → Debug only → "Play opening sunrise", or stop the app in Xcode and run it again with Reduce Motion off. The sun glides into its place on Home. Reduce Motion plays the short version; tap to skip. Launch-screen cache: delete the app, or `xcrun simctl erase all` with the Simulator closed.
- **Timer sunrise:** Home → Start session. The sky follows TODAY's stretch: the first session starts in the dark, a later one picks up where the day left off, and once the stretch is covered the sun stays up. Pause sinks the sun and quiets the sky. To see the stages quickly use Settings → Debug only (the day-head setting) or run with env `LG_TIMER_PROGRESS=0.5`.
- **Session picture:** add any session (Add past hours). In Today's sessions, History and the edit form it has a picture drawn from the session (daypart, length, how far up the sun was). Tap the square in the edit form to open it large; Replace with a photo or Remove picture. Removing leaves a clock tile in Today's sessions and nothing in History.
- **Your photos screen:** Settings → iCloud & storage → Your photos. Needs real photos on sessions; delete-by-year is the red button on each year card and opens the action sheet. Default pictures → Clear empties only the drawn-picture cache.
- **Year cards:** a year nobody opened shows a random selection; after that the most viewed (a photo counts as viewed after 1 s on screen, once an hour). Long-press a tile to pin one.
- **Apple Watch:** run the LongGameWatch scheme. The session screen is the same sunrise (night → dawn → day by today's progress) with the clock, today's total line, a progress bar, Pause and Finish. Always On (wrist down in the Simulator: Features → Toggle Always On): sleepy sun, dimmed sky, buttons hidden, minutes only, once a minute. Reduce Motion: the sun moves in whole minutes. A longer haptic when the sun is fully up (real watch only). Not looked at on a watch Simulator by hand yet: the layout was only built and unit-tested.
- **Widgets and Live Activity:** new sky and land, sea in front of the sun, no animation. The Live Activity has the night land along its bottom edge. Not checked by hand on the Home Screen.
- **App icon:** same 11 stages in the new night-sky style, plus Dark and Tinted. Regenerate with `swift Tools/MakeIcon.swift LongGame/Resources/Assets.xcassets`. The icon set has to go up with the next build in App Store Connect (needs your Apple account; nothing was uploaded).
- **Not verified by hand yet:** Dynamic Type at the smallest and largest sizes on every changed screen, iPad and wide layouts, real photos on the year card, the Watch screens on a Simulator.

## Saved moment on the new sunrise (update 33)

- **See it:** run the LongGame scheme with `-demoData`, Begin a session, let it run for more than a minute (shorter ones can't be saved), Finish, Save. The sky, sea and text colours are what the Timer would show with the session counted, the sun jumps once with the burst, and "Saved", "+N m · today …" and the accent line fade in under the sea. Before the stretch is covered it says "N m left of today's stretch"; to see "Today's stretch covered." save a session that takes today past its stretch (Add past hours first so that today is nearly covered, then run a short timer or run a long one). Reduce Motion (Settings app → Accessibility → Motion) gives a plain fade.
- **Previews:** `TimerView.swift` has Saved previews at p 0.2, 0.62 and 1 and with Reduce Motion.
- **Removed:** `TimerSky.swift`. The old violet colours (0x3A2F6B, 0x5E3A72, 0x7B4378, 0x5A3B72, 0x2C3466, 0x6E3D74) are still in `Colors.swift` (`welcomeSky` 0x2C3466 and the dusk trio of `opening*` colours, 0x2A2F6B / 0x6E3D74) and in the `GlassPreviews.swift` preview background (0x3A2F6B). Nothing outside the Timer was changed; they may be dead code after the redesign, so say if you want them removed.
- **Not verified by hand:** the Saved moment was built, unit-tested (progress and the covered line) and read through, but not watched in the Simulator, which was too slow to wait out a 1-minute session reliably.

## Full-screen Growth chart was slow (found while doing update 33)

Years of daily sessions gave thousands of chart points (2,900 for 8 years), drawn as thousands of separate marks and redrawn on every frame of the draw-in, so opening it looked frozen. The chart now gets at most 180 points (`GrowthSeries.thinned`, first and last kept); the forecast and milestone logic still use the full history. Not timed on a device.


## Screen-by-screen check against `design/redesign/` (10 November 2026)

Every phone screen was opened in the Simulator (iPhone 17, iOS 27, so with the Liquid Glass controls) and compared with its board. Changed to match:

- **Shared:** cards have the soft shadow; the setup step bar is gold (22 × 4); "by We Have Sun" sits under the main button on the intro pages and steps 1–5; steps 2–4, Add past hours, catch-up and the full-screen chart have the peach wash; round − / + buttons are white with a soft shadow before iOS 26.
- **Welcome:** the tagline breaks after "App Store.".
- **Intro pages:** dots (18 / 6 pt) directly under the words; Skip in semibold.
- **1 · Your game:** Back button (to the intro), no sun in the corner, "What’s your game?", tighter pills (6 pt gaps), 12 pt group labels in the muted colour.
- **2 · Start year:** no card, the 68 pt year on the wash.
- **3 · Each year:** the card is as tall as its rows, the score sits right under it.
- **3b · Weekly pace:** the small scene (sun, dotted road, moon) and "Each day, a stretch from the sea to the moon."
- **3c · Keep your game safe / Welcome back (iCloud):** the new sky, dunes and sea instead of the old wavy sea; outlined blue cloud.
- **Home:** the button always says Begin; the long game stats are label over figure with hairlines and an ember finish line; "Meet your future self · Who you’re playing for" with its sun; the year row comes first; This week's day bars are gold in dashed outlines.
- **Meet your future self:** the track as on the board (today's dot at the start, labels right under it).
- **Finish sheet:** rebuilt: scene with the celebrating sun, − 42 m +, "this session", photo and note, Save, Discard.
- **Add past hours / Edit session:** rebuilt: Cancel, 76 pt time with the day under it, steppers for hours and minutes.
- **History:** small centred title; the calendar card without its "Last 12 months" line, M / W / F letters; stats as a hairline row above the day card; the day card shows "Evening · 1 h 15" with the note.
- **Growth:** the headline above the card (34 pt), gold area under the past line, thinner lines in the board's colours, no numbers on the hours axis, What-if without a card, Your year as a plain row.
- **Growth, full screen:** peach wash, key under the chart, 34 pt headline, ember milestone line.
- **Settings:** small centred title; "Free, with no ads. Tips keep it that way."
- **One craft, Welcome back after a break, Catch up (both), Tip jar, Thank you:** the scene on top and the boards' copy and sizes.
- Dates read "Thursday 5 November" (no comma).

Left as they are, on purpose:

- **No + in Home's header** (the boards still show it; update 31 removed it).
- **See-through dunes by day** (the boards' dunes are solid, but then they hide the low sun on the empty day).
- **Settings rows** (Week starts on, Rhythm nudge, estimates, export…) follow the spec, not the board's shorter list.
- **Add past hours keeps the photo square**, which the board leaves out.
- **Scale labels** on This week and The long game show every tick (the boards label only the ends and the middle).
- **Straight apostrophes** in older copy ("today's") were not all changed to curly ones.
- **The moon on Welcome** sits under the status bar's icons on phones with a Dynamic Island, as it does on the board.

Second pass, opened by hand in the simulator (10 November 2026): Welcome, the three intro pages, steps 1–5, Meet your future self, the three catch-up sheets, One craft, the full-screen Growth chart and the Sunrise, Evening and Photos year cards. All match their boards. Fixed on the way:

- **Full-screen Growth chart did not open.** The tap was registered but the chart never appeared; the Growth tab now reads its open flag, which brings it back.
- **Catch up, average step:** the quick-pick chips are centred.
- **Year cards:** the total reads "3,333 h" with a comma on every device (some regions wrote "3 333"); "Show hours" sits straight on the page.

- **Weekly pace:** the small sun rests on the left dune's ridge, in full view, and the dotted road starts from it. The board places it lower, where the dune would hide it; Natalia chose to show it.

Still not opened by hand: Welcome back (iCloud; needs an iCloud copy), Thank you (needs a tip through Xcode's StoreKit test), the photo viewer, Your photos, iPad, Mac, Watch, widgets and the Live Activity.

Tests: all pass except the 4 StoreKit ones in `TipPurchaseTests`, as before.

## Update 34: a transparent glass top bar on the phone's Home (10 November 2026)

| What | State | Where | Notes |
|---|---|---|---|
| One continuous sky from the top of the screen to the sea on every tab | ✅ | `GaugeHero` (`extendsSky`), `HomeView.columnPage` | Day sky and glow on Today and This week, dawn on the empty day and The long game. `SunriseHero` draws no sky of its own there. Seen on the iPhone 17 Simulator (iOS 27.2): no line, band or colour change on any tab |
| No warm wash behind the phone's bar | ✅ | `HomeView.columnPage` | Plain background under the page; iPad, Duo open and Mac keep the wash |
| Transparent bar, no scroll edge effect | ✅ | `lgTopBar(transparent:)` | iOS 26: `safeAreaBar` with `scrollEdgeEffectHidden(true, for: .top)`. Before: `safeAreaInset` on `Color.clear`. Other screens keep their bar |
| Glass controls | ✅ | `HomeView.headerButtons`, `LGSegmentedControl` (`lgOverSky`) | The two circles share a `GlassEffectContainer`; the track is tinted with `segmentTrack` at 35% on the day sky. Flat look: `segmentTrack` 85% over `.ultraThinMaterial` |
| Title fades after the hero has scrolled away | ✅ | `HomeView` (`titleOpacity`) | Over 24 pt; never with Reduce Transparency. Seen at the largest text size, where the page is long enough |

Different from the prompt, on purpose:

- **The craft name and tabs are white on the empty day**, not navy. The empty day's dark dawn sky now runs behind the bar, and navy on it could not be read.

Worth a look by Natalia:

- **Scrolling before the hero is gone.** The hero slides under the transparent bar as asked, so for a moment the scale, its pill and the sun sit behind the craft name and the clock. The title only fades once the whole hero has passed.
- **The clock and battery stay dark** on the dawn sky (the empty day and The long game), as they already did on The long game.

Not seen: the iOS 17–25 look (only the iOS 27.2 runtime is installed here), Reduce Transparency, the smallest text size, iPad, Duo open and Mac (their code paths are untouched).

Tests: all 609 pass on the iPhone 17 Simulator.

## Launch screen on the Launch board (10 November 2026)

Natalia's phone showed a bare yellow half-disc. The board's sleeping sun has more, and the launch screen and the app's first frame now both draw it:

- all 12 rays, faint (22%), lighting up as the sun rises;
- the soft gold halo behind the sun;
- the blue-grey "z" at its top right;
- the board's sleepy face (under the water, as on the board);
- the sun's centre exactly on the shoreline (it was 6 pt lower).

The still sun is now a 2x/3x bitmap like the sky, from `Tools/MakeLaunchAssets.swift`. Checked on the iPhone 18 Pro Simulator: the launch picture and the app's first frame match, and the sunrise goes on to Home.

Also fixed: Update 34's title fade kept its measurements in Home's own state, so every measurement made all of Home work itself out again. They now live in a small `BarFade` object that only the title reads.

Not fixed here: on the iPhone 17 Simulator the app sometimes stays on the night frame at full CPU. Another session is fixing that in `AppRoot` (Home's sun position making Home rebuild). Tests: all pass except the 4 StoreKit ones in `TipPurchaseTests`, as before.

## Updates 35 and 36: direct words on Today, a natural sample year, the year card's shapes (11 November 2026)

| Requirement | Status | Where | Note |
| --- | --- | --- | --- |
| Line under Today's number: "40 m to go" / "Done for today" / "25 m extra today" | ✅ | `StretchText.quietLine`, `TodayQuietLine` | Less than a full minute over is still "Done for today"; extra is whole minutes |
| Same words on the iPad Today card and the Mac menu bar | ✅ | `StretchText.cardLine`, `MenuBarText.todayLine` / `idleCaption` | Mac covered: "· done" or "· 25 m extra" |
| VoiceOver drops the moon | ✅ | `SunSpeech.today`, `StretchText.description` | Weekly target explainer ("from the sea to the moon") unchanged, as asked |
| Old moon strings out of the String Catalog, new ones in | ✅ | `Localizable.xcstrings` | |
| Seeded sample year (SplitMix64, weekly energy, breaks, weekends, 1 in 7 photos) | ✅ | `SampleYear`, `SeededRandom` in `Logic/Practice.swift`; Settings → Fill a sample year; `YearSummary.sample()` | Lives in an existing file because XcodeGen isn't installed here, so no new files could be added to the project |
| Year card strip uses the calendar's shapes; rest is a small dot (#C5D0EC / #3D4D93) | ✅ | `YearStrip` in `Features/Year/YearCardView.swift` | Shape size stays pitch × 0.86. Checked the 1080 px Sunrise and Evening PNGs: dots, circles and squares are clear. New preview "Strip · Sunrise and Evening" |
| Tests | ✅ | `TodayStretchTests`, `MenuBarTests`, `SunWordsTests`, `YearSummaryTests` (`SampleYearTests`) | All 628 pass on the iPhone 18 Pro Simulator (no iPhone 16 Simulator is installed). Mac app builds |

Not checked: the new wording on a real iPhone or Mac, and real VoiceOver speech.

