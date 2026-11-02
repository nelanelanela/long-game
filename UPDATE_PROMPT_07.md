# Update prompt 07 for Claude Code: tip jar

Paste everything below the line into your Claude Code session in this folder.

---

We're adding an optional tip jar. Please read `docs/SPEC.md` section "14 · Support Long Game — tip jar" (and "15 · Thank you"), plus `design/TipJar.dc.html` and `design/TipThanks.dc.html`. Then implement it.

**1. StoreKit**
- Use StoreKit 2 with four **consumable** products. The product IDs are in the spec table: `com.wehavesun.LongGame.tip.ray`, `.tip.morning`, `.tip.goldenhour` and `.tip.sunrise`.
- Add a StoreKit configuration file `LongGame.storekit` with those four products and EUR reference prices of 0.99, 2.99, 4.99 and 9.99. Select it in the scheme so tips work in the Simulator.
- Put all store code in one small `TipStore` (`@Observable`). It loads the products, buys, verifies, finishes transactions, and listens to `Transaction.updates` from app launch.
- Prices always come from `Product.displayPrice`.
- Handle every case:
  - success → thank-you sheet;
  - user cancelled → nothing happens;
  - pending (Ask to Buy) → "Waiting for approval";
  - failed or store unavailable → "Tips aren't available right now".
- Save `lastTipAt` and `tipCount` in Settings.

**2. Screens**
- **Settings:** add "Support Long Game" as its first row, with the small sun icon, pushing the tip jar screen. After a tip, the subtitle reads "Thank you for your support".
- **Tip jar screen:**
  - The breathing sun and "Keep the sun shining" with the paragraph from the spec.
  - A flat white card of four rows. Each row has its sun icon with more rays for bigger tips, a name, a line and a navy price pill.
  - The footnote under the card.
  - A loading state per price, and buttons disabled while a purchase is running.
- **Thank-you sheet:** the hopping open-eyed sun with the little burst, "Thank you!", the text and **Back to my game**. Add a success haptic. With Reduce Motion it's still.

**3. One gentle offer**
- After a milestone celebration on Home, show a text button "Support Long Game" under the celebration's main button.
- It shows only if all of these are true: at least 14 days since onboarding, no offer in the last 90 days (`lastTipOfferAt`), no tip in the last 12 months, and no timer running or just finished.
- Never show it as a separate pop-up.

**4. Rules**
- Tips unlock nothing. Don't add badges, themes or any feature difference.
- No analytics or third-party SDKs.
- All text goes in the String Catalog.

**5. Tests**
- Unit tests for the offer rule: 14 days, 90 days, 12 months, timer running.
- Use `StoreKitTest` (`SKTestSession`) for a successful purchase, a cancelled one and an Ask to Buy one.

When you're done: build, run the tests, and tell me how to try a tip in the Simulator. Also list exactly what I need to set up in App Store Connect before release.
