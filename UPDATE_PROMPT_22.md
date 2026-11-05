# Update prompt 22 for Claude Code: more choices on "What's your game?"

Paste everything below the line into your Claude Code session in this folder. Everything Claude Code needs is written out here, so it doesn't depend on reading the design file.

---

Please update onboarding step 1, "What's your game?". The design file `design/Main.dc.html` was just replaced with a new version, so read it from disk again rather than relying on an earlier copy. All the details are also below.

**Layout, top to bottom**
1. The step dots (step 1 of 5) and the back chevron.
2. Title "What's your game?", with no subtitle.
3. A search field, 48 pt high, white with a 14 pt radius, a magnifier icon, and the placeholder "Search or type your own".
4. A scrolling list of suggestion chips in five groups:
   - each group has a small label (12 pt semibold, #8A93AB);
   - the chips wrap under the label;
   - chips are capsules, 14 pt medium text, with 7 pt × 12 pt padding and 6 pt gaps;
   - white background and navy text, or navy background and white text when selected.
5. A soft fade at the bottom of the list, into the background (#FAF8F4), so it's clear the list scrolls.
6. **Continue**, fixed at the bottom. It's disabled until a craft is chosen or typed.

**The suggestions, in this order**

| Group | Chips |
| --- | --- |
| Music | Piano, Guitar, Violin, Cello, Drums, Bass, Saxophone, Flute, Trumpet, Singing, Composing |
| Visual arts & making | Painting, Drawing, Sculpture, Woodworking, Ceramics, Photography, Illustration, Printmaking, Textiles, Jewellery |
| Performing arts | Acting, Dance, Ballet, Directing |
| Words & mind | Writing, Poetry, Languages, Chess, Coding |
| Professions | Medicine, Law, Architecture, Design, Cooking, Teaching |

**Behaviour**
- Only one chip can be selected. Tapping a chip selects it and puts its name in the search field. Tapping it again clears it.
- Typing filters the chips across all groups and hides groups with no match. Any typed text of 2–40 characters is accepted as a custom craft.
- Put the list in one place in code: a `CraftSuggestions` array of groups, with every name in the String Catalog using British spelling (Jewellery). Remove any older, shorter list.
- Accessibility:
  - each chip is a button with the selected trait when chosen;
  - group labels are headers;
  - Dynamic Type wraps the chips;
  - at accessibility sizes, the chips become a single-column list.

**Checks**
- Add previews with nothing selected, with Piano selected, while searching (typing "pa" shows only the names that contain "pa": Painting), and at AX5.
- Build and run the tests.
- Tell me how to see it: reset onboarding with the debug option, then tap Get started and skip the intro pages.

If something in the code still doesn't match after this, list the file and line you changed, so I can check them.
