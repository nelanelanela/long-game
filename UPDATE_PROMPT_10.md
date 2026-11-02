# Update prompt 10 for Claude Code: ready for iPhone Duo

Paste everything below the line into your Claude Code session in this folder.

---

We need Long Game to be ready for iPhone Duo, Apple's foldable (iOS 27): a short 5.4" outer display and a wide 7.6" inner display, with Split View, multiple windows and a vertical Dynamic Island on the side. Please read `docs/SPEC.md` section "iPhone Duo (foldable)" and `design/Duo.dc.html`. Then:

1. **Adaptive layout by window size, never by device.** Base the layouts on size classes plus the real width and height (`GeometryReader` / `ViewThatFits` / `horizontalSizeClass`):
   - Compact width keeps the phone layout. Add a short variant for heights under 700 pt: a smaller hero and sun, the number and percentage on one line, no day bars, and the buttons side by side.
   - Regular width that's wider than tall gets two panes: the sun gauge with tabs on the left; the numbers, day bars, target row, stats and buttons on the right.
   - The Timer gets a wide layout (sun left, clock and buttons right).
   - History shows Calendar and Growth side by side when wide.
   - Sheets become centred cards, max 520 pt wide.
2. **Windows and multitasking:** support all orientations and resizable windows / Split View. Make sure `UIRequiresFullScreen` isn't set. Allow multiple windows, and keep the single running session shared between them.
3. **Continuity:** folding, unfolding and resizing keep the tab, scroll position, running timer and open sheets, and animate between layouts. Use scene state restoration.
4. **Safe areas:** respect every edge, including the side Dynamic Island when open. The sun gauge's scale and the pill must never sit under it.
5. **Widgets:** check that the small and medium widgets look right at the larger sizes in the open Home Screen's Today View.
6. **Checks:**
   - Previews for compact, short-compact (405 × 567), wide (802 × 573) and half-width Split View (401 × 573) for Home (both tabs), Timer and History.
   - Test on the iPad Simulator in a resizable window and on the iPhone SE. Use the iPhone Duo Simulator once Xcode offers it.

When you're done: build, run the tests, and tell me what changed and how to try the layouts.
