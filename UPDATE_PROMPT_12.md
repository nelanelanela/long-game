# Update prompt 12 for Claude Code: a note and a photo after each session

Paste everything below the line into your Claude Code session in this folder.

---

We're adding an optional photo and note to each session. Please read these parts of `docs/SPEC.md`:
- the new section **"16 · A note and a photo, if you like"**;
- the updated Session row in the data model;
- "5 · History — Calendar";
- the Finish sheet line in the Timer section;
- the Settings line about Export and Delete.

Also read `design/NotePhoto.dc.html`. Then implement the following.

**The most important rule:** this must stay completely optional and low key.
- Nothing opens or focuses by itself.
- Nothing is ever required.
- Save looks and works the same with or without a photo or note.
- No reminders, prompts, badges, counts, ratings or tags anywhere.

**1. Data**
- Add `photo: Data?` to `Session` with `@Attribute(.externalStorage)`. `note` already exists; limit it to 500 characters in the UI.
- Write a SwiftData migration so existing sessions keep working.
- Before saving a photo:
  - resize it to at most 2048 px on the longest side;
  - encode it as JPEG at quality 0.8;
  - strip location and other metadata.
- Make thumbnails on the fly and cache them in memory. Don't store them.
- Photos sync through CloudKit only when sync is on. Deleting a session deletes its photo, and "Delete all data" removes all photos.
- Export CSV includes the notes (properly escaped) and no photos.

**2. Finish sheet**
- Add one row between the session time and Save:
  - a 64 pt dashed photo square with a camera icon;
  - a soft field, "A note, if you like", with the hint "What you made, what needs work".
- Tapping the square offers **Take photo** and **Choose from library**:
  - Choose from library uses `PhotosPicker`, which needs no permission.
  - Take photo uses the camera. Add `NSCameraUsageDescription`: "Take a photo of what you made, if you like."
  - The camera permission is asked only the first time Take photo is tapped.
- With a photo, the square shows the thumbnail with a small navy ✕ to remove it.
- The note field grows to 4 lines, then scrolls.

**3. Editing later**
- Tapping a session row in the History day card opens the same two fields, plus the existing duration edit and delete.
- That's also how sessions finished from the Live Activity or the Watch get a photo or note.

**4. History**
- Calendar:
  - Add a tiny white dot (4 pt) in the centre of each day square that has at least one photo.
  - Keep the full legend: Rest, and Less → More with the four colours.
  - Once the user has at least one photo, add a second legend line: a square with the dot and "White dot: a day with a photo".
- Day card:
  - Each session row shows its 56 pt photo thumbnail and its note.
  - A row with neither says "No note" in light grey.

**5. Photo viewer**
- Tapping a thumbnail opens a dark full-screen viewer:
  - a close ✕, the date and "Evening · 1 h 15" at the top;
  - the photo fitted, with pinch to zoom;
  - the note under it;
  - a strip of recent photo thumbnails at the bottom.
- Swiping left and right moves through photos across all days, with the newest last.
- ··· offers Change photo, Edit note and Remove photo (with a confirmation).
- With Reduce Motion, use a cross-fade instead of sliding.

**6. Accessibility and text**
- VoiceOver labels:
  - the photo square: "Add a photo" or "Photo, double-tap to change";
  - thumbnails: "Photo from Thursday 22 October, evening session".
- The viewer supports VoiceOver swipes between photos.
- Use Dynamic Type everywhere.
- All new text goes in the String Catalog, with British spelling.

**7. Tests**
- Photo processing: the size limit, JPEG output and stripped metadata.
- The 500-character note limit.
- CSV escaping of notes with commas, quotes and new lines.
- "Day has a photo" for the calendar dot.
- Deleting a session removes its photo.

Adding the camera usage text is just an Info.plist entry and needs nothing from my Apple Developer account. If anything else does, ask me first.

When you're done:
- build and run all the tests;
- update `docs/AUDIT.md`;
- tell me how to try it in the Simulator. The Simulator has no camera, so use Choose from library, and add a debug option to fill a few past sessions with sample photos and notes.
