# Screen spec: App shell

Status: draft for user review (T-003). Tickets: T-012, T-015.

## Decisions in this spec

1. **Top-level destinations (4):** Scan, Search, Collection, Settings. In that order. Scan is the start destination.
   - T-012 assumed three (Scan, Collection, Settings). Search is added because "title search is always one tap away" is a core rule, and it keeps Search one tap from Collection and Settings too. Four destinations fit a NavigationBar (limit is 5).
2. **Navigation pattern:**
   - Compact (width under 600 dp): bottom NavigationBar.
   - Medium (600 to 839 dp) and expanded (840 dp and up): NavigationRail on the leading edge, 80 dp wide, labels always shown, destinations top-aligned.
   - Phone landscape (for example 844 x 390 dp) counts as expanded by width, so it uses the rail. Two-pane layouts need at least 600 dp of height as well, so phone landscape stays single pane.
3. **Seed color:** `0xFF1F6B5C` (a deep green-teal, the color of game table felt). Both themes come from `ColorScheme.fromSeed(seedColor: ...)` with `Brightness.light` and `Brightness.dark`, Material 3, `useMaterial3: true`. Dynamic (wallpaper) color is off in v1 so goldens and brand stay stable (confirmed by the user, PRD Q31, 2026-10-12). Developers must not hard-code any other color. If a generated pair fails 4.5:1 for text, change the role used, not the seed.
4. **Theme choice:** follows the system by default; Settings lets the user force Light or Dark.
5. **Window sizes in "Shared test definitions":** confirmed as written: compact 390 x 844 dp, medium 744 x 1133 dp, expanded 1280 x 800 dp, text scale 2.0. One addition is proposed: a fourth size named `landscape`, 844 x 390 dp (phone landscape), used only for the goldens that this spec names. The Material breakpoints used by the app are 600 dp and 840 dp of width, so 744 is medium and 1280 and 844 are expanded.
6. **Type:** Material 3 type scale with the default Roboto/San Francisco system fonts. Bundled fonts for goldens are decided in T-015.
7. **Back stack:** each destination keeps its own navigation stack and scroll position (T-012 criterion 5). Tapping the selected destination again pops to its root. Game detail, lookup result, listings, price history, item edit, and backup screens are pushed on top of the shell inside the current destination. The rail or bar stays visible on pushed screens at every size, so the other destinations are always one tap away. The only exception is the full-screen photo viewer.

## 1. Purpose and entry points

The frame around every screen: navigation, offline banner, theme, and shared scaffolding. Entry: app launch lands on Scan. There is no splash screen content beyond the system launch screen, no onboarding, no sign-in, and no what's-new screen. The first thing a user sees is the scanner (or the camera explanation on first run).

## 2. Layout

| Width | Navigation | Content |
|---|---|---|
| Compact portrait (390 x 844) | NavigationBar, 80 dp tall, 4 destinations | Full width, 16 dp margins |
| Compact landscape / phone landscape (844 x 390) | NavigationRail, 80 dp wide | Single pane, 24 dp margins |
| Medium (744 x 1133 and 1133 x 744) | NavigationRail | Single pane; ContentColumn max 600 dp for forms |
| Expanded (1280 x 800) | NavigationRail | Two-pane (TwoPane) on Search, Collection, and candidates; game detail uses two columns |

Top app bar: small (center-aligned off), title is the destination or screen name, 64 dp. Scrolls away with content on list screens (scrolledUnder elevation tint).

Safe areas and cutouts are respected on all edges. The NavigationBar never overlaps content. The scanner draws the camera behind the status bar but keeps controls inside safe areas.

Keyboard: on compact the NavigationBar hides while a text field has focus so the keyboard does not squeeze content [ASSUMPTION]; it returns when focus leaves.

## 3. Components

AdaptiveScaffold, AppNavigation, TwoPane, ContentColumn, OfflineBanner, Snackbar. See docs/ux/components.md.

## 4. States

- **Default:** destination selected, no banner.
- **Offline:** OfflineBanner under the app bar on screens that use network data (Search, Game detail, Listings, Price history, Lookup result). Scan, Collection, Settings, and Manual entry show no banner because they work offline. Content is never replaced by an error screen.
- **Loading / empty / error:** owned by each destination screen.
- **Partial:** n/a.
- **Light and dark:** both themes. Status bar icons adapt.

## 5. Interactions and navigation

- Selecting a destination switches immediately. No confirmation. State is kept per destination.
- System Back: pops within the destination; at a destination root goes to Scan; at Scan root exits the app.
- Deep links are not used in v1.
- Hardware keyboard and switch access: Tab order follows section 7.
- Rotation keeps state (scroll position, text field content, selected pane item).
- No interstitial, onboarding, rating prompt, or update screen exists anywhere in the shell.

## 6. Copy

`nav.scan`, `nav.search`, `nav.collection`, `nav.settings`, `nav.scanLabel`, `nav.searchLabel`, `nav.collectionLabel`, `nav.settingsLabel`, `shell.appName`, `common.offlineBanner`.

## 7. Accessibility

- Each destination has a semantic label (`nav.*Label`) and reports selected state ("selected", "tab 1 of 4").
- Focus order: app bar title, offline banner (if shown), content, then navigation (bar at the end on compact; rail first on medium and expanded because it is leading).
- The destination change announces the new screen title.
- Rail and bar items are at least 48 x 48 dp (bar items are 80 dp wide at minimum).
- At 200% text the NavigationBar labels wrap to 2 lines and the bar grows in height; icons stay visible. On rail, labels wrap and the rail scrolls if needed.
- The "skip" pattern for keyboard users: the first Tab stop is the content; the rail can be reached with Shift+Tab.
- Contrast: selected indicator uses secondaryContainer with onSecondaryContainer icon (3:1 or better against the bar surface).

## 8. Golden cases
Total: 10 (8 in M1 from T-015, 2 in M2 from T-032). The other states are covered by widget tests.

| File | Notes |
|---|---|
| app_shell_default_light_compact.png | T-015 |
| app_shell_default_dark_compact.png | T-015 |
| app_shell_default_light_expanded.png | T-015 |
| app_shell_default_dark_expanded.png | T-015 |
| app_shell_default_light_medium.png | T-015. Rail at 744 wide |
| app_shell_default_light_landscape.png | T-015. Rail at 844 x 390, single pane |
| app_shell_text200_light_compact.png | T-015. Nav labels at 200% |
| app_shell_text200_dark_expanded.png | T-015. Rail labels at 200% |
| app_shell_offline_light_compact.png | T-032. Offline banner on Search |
| app_shell_offline_dark_expanded.png | T-032. Offline banner with rail |

## 9. What PM and reviewers should check

- Four destinations, in order, with the seed color above; no second brand color.
- Rail from 600 dp, bar below.
- Switching tabs keeps scroll position.
- Nothing appears between launch and the scanner.
- Offline banner appears only on network-dependent screens and never replaces content.
- Open questions: (seed color answered: PRD Q31, 2026-10-12, `0xFF1F6B5C`), the fourth `landscape` test size (user), hiding the bar when the keyboard is open.
