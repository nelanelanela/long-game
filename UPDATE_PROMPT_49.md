# Update prompt 49 for Claude Code: a letter to your future self, weather in the scene, a keepsake poster

Paste everything below the line into your Claude Code session in this folder.

---

Three features for the 1 December release. Please read `design/redesign/LetterToFutureSelf.dc.html`, `design/redesign/SunMoods.dc.html` (with `OnboardingWeather.dc.html`) and `design/redesign/Keepsake.dc.html`. Work on the `redesign` branch, and build and test after each part. Every button uses the app's standard styles (primary 56 pt with radius 16, text buttons 44 pt); the mock-ups are smaller than real size.

Parts 1 and 3 need nothing from my Apple Developer account. **Part 2 does** (the WeatherKit service). Build parts 1 and 3 first. Before part 2, stop and tell me exactly what to switch on and where, and wait for me.

## 1 · A letter to your future self

At a milestone, the person writes a few lines to who they'll be at the next one. The app seals it and brings it back when they get there.

**Model**
- A new SwiftData entity `Letter`: id, craft, text, written date, the overall total when written, the milestone it's for (hours), the date it was opened (nil while sealed). It syncs with iCloud only when sync is on, and it's included in the export and the backup.
- One letter per milestone per craft. Milestones: 100, 500, 1,000, then every 1,000 up to 10,000.
- Pure functions in `Logic/` (`Letters`), with tests:
  - the next milestone for a total;
  - which letter is due when a milestone is reached, including a save that passes two milestones at once (deliver the earlier letter first, then the next);
  - "You wrote this 1,000 hours ago" (the milestone minus the total when written, rounded to the nearest 10 below 1,000 and to the nearest 100 above);
  - a letter for a milestone already passed is never created.

**Writing**
- Offered in three places:
  - on each milestone celebration, a secondary button **Write to yourself at 4,000 hours** (the next milestone);
  - a row on The long game: **A letter to your future self**, "For you at 4,000 hours";
  - at the end of setup, a text button **Write to yourself at 100 hours**. If past hours already pass 100, it names the next milestone.
- The screen (a sheet):
  - **Not now** at the top left, and a quiet counter "112 / 1,000" at the top right;
  - the sun with open eyes, and **A letter to you at 4,000 hours**;
  - "Write a few lines to the person you'll be then. The sun keeps it sealed until you get there, around January 2028 at your pace." The date comes from the existing forecast, month and year. With no pace set, the sentence ends at "until you get there."
  - a paper card with a multi-line text field, up to 1,000 characters, text only;
  - the hint "Not sure what to say? What's hard right now. What you hope to be able to do.";
  - **Seal the letter** (primary), disabled while the letter is empty.
- Leaving with text typed asks "Throw this letter away?" with **Keep writing** and **Throw away**.

**Sealed**
- After sealing: an envelope with an amber seal carrying the sun, **Sealed.**, "The sun will bring it back at 4,000 hours. 1,000 hours to go.", and **Done**. A soft tap from the haptics table.
- The row on The long game becomes **A letter is waiting**, "Opens at 4,000 h · written 3 June 2026". Tapping it shows the sealed envelope with two text buttons: **Rewrite** (starts an empty letter, replacing the old one only when the new one is sealed) and **Throw away** (with a confirmation).
- A sealed letter's text can't be read anywhere in the app before its milestone.

**Delivered**
- When the milestone is reached, right after the milestone celebration closes, once:
  - the sun's celebrate face, **A letter from you**, and a navy pill with gold text "You wrote this 1,000 hours ago";
  - the letter on its paper card, with "3 June 2026 · at 3,000 h" under it;
  - **Write to you at 5,000 hours** (primary) and **Keep it and close** (text button);
  - the rising three haptic.
- Opened letters are kept under **Your letters**, reached from the row on The long game, oldest first. A letter can be deleted there with a confirmation.
- At 10,000 hours, after the celebration, all the letters are shown together, first to last, on one scrolling screen.

**Privacy**
- A letter's text never appears on a share card, a widget, a notification, the Live Activity or the Watch.
- No reminder to write one, ever.
- Replacing the craft keeps the letters with the archived craft. Sealed letters of an archived craft stay sealed and are listed as "Never reached".

**Accessibility**
- The paper card's text field has the label "Your letter". The counter is read as "112 of 1,000 characters".
- The delivered letter is one element: the pill, then the text, then the date.
- Everything scrolls at the accessibility text sizes. The envelope is decorative.

## 2 · Weather in the scene

On Home, the weather where the person is passes quietly through the landscape: a thin, pale layer over the sky and sea. There are no costumes on the sun. **The sky's colour, the sun's height and its lit rays never change with the weather**; they keep showing progress. On a clear day nothing changes at all.

**Before you start this part:** it needs the WeatherKit capability on the app's identifier in my Apple Developer account, and the entitlement in `project.yml`. Stop, tell me in plain words what to switch on and where, and wait. Also tell me what Apple currently asks for as attribution, and the free monthly call limit, from Apple's own documentation.

**The layers** (pure function in `Logic/`, `SceneWeather.current(weather:)`, returning one layer or none)

| Weather | In the scene | When |
| --- | --- | --- |
| Cloud | three soft white clouds drifting slowly, high and to the sides | mostly cloudy or overcast |
| Rain | fine slanted white lines falling, a few thin rings on the water, the whole scene 10% cooler (a navy veil); the sun rests its eyes (the sleepy face without the "z") | rain or drizzle |
| Wind | the dune lines and the water sway about twice as fast; a few faint gust lines pass low; one long thin cloud | wind of 40 km/h or more |
| Mist | a pale veil along the horizon, densest just above the water, with two slow bands | fog, mist or haze |
| Snow | slow white flakes of four sizes; the sun's eyes are open | snow or sleet |

- One at a time, in this order of preference: snow, rain, mist, wind, cloud.
- Clear and partly cloudy days, and no data, show the scene as it is.
- Draw the layer in its own view between the scene and Home's text, in white and pale tones only. Positions of drops, flakes and clouds are seeded, like the star field, so they look natural and don't jump between launches.

**Behaviour**
- **The sun is never hidden.** Clouds keep clear of the sun's disc wherever it is on its arc, and the mist stays below its face.
- The sea and the fill below it stay opaque and in front of the sun, as now. Rain rings are drawn on top of the water.
- Home only. Never in the timer, a widget, the app icon, a share card, the launch animation or the Watch.
- The sun still breathes, blinks and giggles when tickled. A celebration, a wink from The sun remembers and the giggle win over the resting or open eyes.
- Slow movement and no sound or haptic. Reduce Motion: the layer is still. Dark mode: the same layer at 70% strength.
- VoiceOver: the scene's label gains one word or two, for example "Sunrise scene, light rain".

**Weather and privacy**
- **Off by default.** A switch in Settings, in the group with Giggle sound: **Weather in the scene**, with the subtitle "Rain, mist and snow from outside your window". Turning it on asks for location (When In Use, and request reduced accuracy; approximate is enough). If the person refuses, the switch goes back to off with one line: "Without your location the app can't see the weather."
- Weather comes from WeatherKit (`WeatherService`, current weather only). No third-party service or dependency.
- Fetch only when Home appears, and at most once every 3 hours. Keep only the last layer and the time it was fetched; never store the location. With no network or an error, show the scene as it is and say nothing.
- Under the switch, show Apple's weather attribution (the mark and the legal link from `WeatherService.attribution`), as Apple requires.
- Add the location purpose string: "Long Game uses your approximate location only to show the weather in its landscape."
- Tell me what to change in the privacy policy and in the App Store privacy answers. Don't change anything in App Store Connect yourself.

**In onboarding** (read `design/redesign/OnboardingWeather.dc.html`)
- A new last setup step after A gentle nudge, so the steps become 7 of 7. People who already finished setup never see it; they use the Settings switch.
- A small scene with the rain layer and the sun resting its eyes, then **The weather outside** and "When it rains where you are, it can rain here too. Mist, wind, cloud and snow pass through quietly; on a clear day nothing changes."
- A card with two rows:
  - **Only in the landscape** · "The sun's height and the sky still show your progress."
  - **Your rough area is enough** · "Used to ask Apple Weather a few times a day. Never saved, never shared."
- "iPhone will ask for your location next. Change your mind any time in Settings."
- **Show the weather** (primary) shows the system location prompt and, if allowed, turns the Settings switch on. **Not now** (text button) leaves it off. Both go on to Home. The system prompt is only ever shown from this button or the Settings switch.

**Tests**
- Each layer's condition and the order of preference.
- The 3-hour rule.
- No layer when the switch is off.
- Clouds never overlap the sun's disc, for sun positions along the whole arc.

## 3 · A keepsake poster

At the big milestones, the whole calendar becomes a field of suns: a print-ready poster.

**When**
- A secondary button on the celebration at every 1,000 hours: **Make a keepsake poster**.
- A row at the bottom of History › Growth, shown once the total has passed 1,000 hours: **Keepsake poster**, "Your whole calendar, ready to print".

**The poster**
- Top to bottom, centred, on warm paper (#FFFDF8):
  - "LONG GAME", small and spaced;
  - the hours, large: "3,000 hours" (the milestone just reached; from the Growth row, the last 1,000 passed);
  - "of piano" in ember (the craft's name in lower case);
  - **the field:** one mark for every day from the first session logged to the day the milestone was reached, in order, 28 to a row, so each row is four weeks. Each mark uses the calendar's own level shapes and colours (`CalendarLevelShape`; a rest day is the small pale dot);
  - at the bottom left, the dates and "653 days played · each row is four weeks";
  - at the bottom centre, the calendar's legend, small;
  - at the bottom right, "2,190 hours came before" (hours added for the time before the app; left out when there are none) and "by We Have Sun".
- For long histories, make the marks smaller so the field always fits; never cut days.
- No name, photos or notes.
- **Night look:** navy #0B1029 paper, gold marks (levels as four gold tints with the same shapes), cream text.

**Making it** (a sheet)
- A small preview of the poster, **A keepsake for your wall**, and "Every day of your 3,000 hours as a small sun. Print it at home or at any print shop."
- **Paper:** A4, A3, 50 × 70 (cm), 18 × 24 in. The default is A3, or 18 × 24 in where the region uses inches.
- **Look:** Paper, Night.
- **Save the poster** (primary) makes the file and opens the share sheet (Files, AirDrop, Print). **Not now** (text button).
- The file is a vector PDF at the chosen size, drawn with Core Graphics on the device (not a screenshot), with a 15 mm margin and the fonts embedded. The file name: "Long Game – 3,000 hours of piano.pdf".
- Nothing is uploaded and there is no ordering. Printing is up to the person.

**Logic and tests**
- A pure function in `Logic/` that turns sessions into the list of day levels for the poster, reusing the calendar's level function. Tests:
  - the first and last day;
  - rest days included;
  - the days played count;
  - a history of one week and of ten years (the layout still fits);
  - hours before the app left out when there are none.
- A test that the PDF has one page of the right size for each paper choice.

**Accessibility**
- The preview is one element: "Poster: 3,000 hours of piano, 653 days played."
- The two choices are segmented controls with their selected state read.
- The PDF has a title and a short description in its metadata.

## Text and docs
- All new text goes in the String Catalog, with British spelling. Dates, numbers and wind speeds are formatted for the person's locale.
- Update `docs/SPEC.md` (milestones, The long game, Home, Settings, History, the data model, privacy) and `docs/AUDIT.md`.

When you're done:
- build and run all the tests;
- tell me how to see each one in the Simulator. Add debug options to reach a milestone with a letter waiting, to force each weather layer, and to open the poster sheet with a three-year sample.
