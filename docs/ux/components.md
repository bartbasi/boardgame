# Components

Owner: ux-designer. Shared components and their states. Draft for user review (T-003). Screen specs link here by component name.

Rules for all components:

- Colors come from the Material 3 color roles of the seed-based scheme (see screens/app-shell.md). Text uses the M3 type scale. No hard-coded colors or sizes in specs.
- Spacing uses a 4 dp grid. Standard gaps: 8, 12, 16, 24. Page margin: 16 dp compact, 24 dp medium and expanded.
- Minimum touch target 48 x 48 dp, including icon buttons and chips.
- Every state below must be reachable in a widget test and, where the screen spec says so, a golden.
- Information is never conveyed by color alone: pair color with text or an icon.
- Animations respect the system reduce-motion setting (see accessibility-checklist.md).

Role names below are Material 3 roles: surface, surfaceContainer, onSurface, onSurfaceVariant, primary, onPrimary, primaryContainer, onPrimaryContainer, secondaryContainer, tertiaryContainer, error, errorContainer, outline, outlineVariant.

## Navigation and layout

### AdaptiveScaffold
Wraps every top-level screen. Picks the navigation component by window width: compact (under 600 dp) NavigationBar; medium (600 to 839 dp) and expanded (840 dp and up) NavigationRail. See screens/app-shell.md.
- States: default; keyboard open (bar hides on compact when a text field has focus [ASSUMPTION], so the keyboard does not squeeze content); offline (OfflineBanner shown under the app bar).

### AppNavigation
NavigationBar (compact) or NavigationRail (medium, expanded) with four destinations: Scan, Search, Collection, Settings.
- States per destination: selected, unselected, focused, pressed. Rail shows labels always. Bar shows labels always (labelBehavior alwaysShow).
- Semantics: each destination has a label from `nav.*Label` and reports selected state.
- Tablet landscape or phone landscape: rail only, 80 dp wide.

### TwoPane
Used at expanded width (840 dp and up, and at least 600 dp tall) on Search, Collection, and lookup candidates. Left pane is a list, 360 to 420 dp wide. Right pane shows the selected game's detail.
- States: nothing selected (right pane shows EmptyState with `search.paneEmpty` or `collection.pickAGame`), selected, loading detail (skeleton in right pane only).
- Below the breakpoint, the same list is single pane and a tap pushes the detail screen.

### ContentColumn
Single-column screens (forms, settings, backup) cap their width at 600 dp and center it on medium and expanded, so lines stay readable.

## Feedback

### SkeletonBlock and SkeletonRow
Placeholder shapes in surfaceContainerHighest while loading. Shimmer is a slow fade between two container roles; with reduce motion on, it is static.
- Semantics: one live region on the list says `common.loading`; the individual blocks are excluded from semantics.
- Variants: GameListRow skeleton (thumbnail 56 dp square, two text bars), DetailHeader skeleton (cover, title bars), PriceSummary skeleton, ListingRow skeleton, Chart skeleton.

### EmptyState
Icon (decorative, excluded from semantics), title (titleMedium), body (bodyMedium, onSurfaceVariant), and one or two actions. The primary action is a FilledButton, the secondary a TextButton. Always tells the user what to do next.
- Never shown for error or offline states.

### ErrorState
Same layout as EmptyState with an error icon, a plain-language title and body from `common.error*` or a screen string, and a Retry FilledButton. Optional secondary action (for example "Search by title"). Never shows exception text, codes, or HTTP status.
- Variants by failure: generic, service unavailable, rate limited (body names the wait time when known), timeout, no connection (uses OfflineState instead when cached data exists).
- Semantics: title is a heading; announces on appearance (liveRegion).

### OfflineBanner
A slim, non-dismissable-but-not-blocking strip under the app bar: cloud-off icon plus `common.offlineBanner`. Uses secondaryContainer. Takes no taps. Disappears when the connection returns.
- States: shown, hidden. Does not push content when hidden. Announces once when it appears (polite).

### LastUpdatedLabel
A bodySmall line in onSurfaceVariant: `common.lastUpdated`. Always shown with cached data that could not refresh, and also after a successful refresh (reads "just now").
- States: fresh (just now), aged (minutes, hours, days). Used for game details. Price data has its own rules: stale after 6 hours (StaleChip), not shown after 24 hours (EBAY-20, PRD section 6).

### Snackbar (InlineMessage)
Short message at the bottom, with an optional Undo or action. Auto-dismisses after 5 seconds [ASSUMPTION]; stays 10 seconds if it has an action, and never covers the primary action. Does not block input. On expanded, it appears at the bottom of the content pane.
- Used for: added, moved, removed, saved match, refresh failed, export ready.
- Semantics: announced as a polite live region. Actions are reachable by TalkBack and VoiceOver.

### ProgressRow
Linear progress indicator with label, for export, import, and backup. Indeterminate when the total is unknown. Does not block navigation: the user can leave and the work continues, with a snackbar when done.

## Game components

### CoverImage
Rounded square or 2:3 portrait image with placeholder.
- States: loading (surfaceContainerHighest block), loaded, failed (placeholder with board-game icon), missing (same placeholder).
- Semantics: `common.coverLabel` when loaded; `common.coverPlaceholderLabel` for placeholder; decorative thumbnails in rows are excluded because the row label already has the name.
- No-image mode: BGG asked developers not to hotlink images (BGG-42, PRD Q5), so every screen must work with no cover images at all. One app setting (`showCoverImages`, default follows the answer to Q5) turns the image tile off everywhere. In no-image mode GameListRow drops the thumbnail and the text starts at the leading margin (row height 64 dp), DetailHeader drops the cover and the title uses the full width, ListingRow has no thumbnail unless eBay photos are allowed, and no cover semantic label is emitted. Every screen has a widget test in this mode. Default goldens use placeholders; a golden in no-image mode is listed where it matters.
- Sizes: thumbnail 56 dp, row 64 dp, header 160 dp wide (compact) or 200 dp (medium, expanded).

### GameListRow
Used by Search results, lookup candidates, and Collection lists. Minimum height 72 dp. Layout: CoverImage thumbnail, title (titleMedium, up to 2 lines at 100% text, wraps to as many as needed at large text), subtitle (bodyMedium, onSurfaceVariant), optional trailing slot (chevron, current-match tag, price block).
- Variants: search result (subtitle is year), candidate (adds "Current match" tag in correction mode), collection Owned/Wanted/Evaluating (subtitle is a type-specific line, see screens/collection.md), collection with price.
- States: default, pressed, focused, selected (expanded two-pane: secondaryContainer background plus a leading bar), skeleton.
- Semantics: one node; label is `search.resultLabel` or the variant's label; the tap action is "open". Trailing price block is merged into the label.
- Large text: layout switches thumbnail to 48 dp at 200% to keep text width; text never truncates with an ellipsis for names; it wraps.

### DetailHeader
Cover, title (headlineSmall), year line. At compact the cover sits above the title; at medium and expanded the cover is left of the title.
- States: loading (skeleton), loaded, partial (no cover: placeholder; no year: line hidden).

### FactRow
Label (labelMedium, onSurfaceVariant) over value (bodyLarge). Hidden entirely when the value is missing, never shows "null", "0", or an empty label.
- Variants: players, play time, designers (wrapping text list), publishers.

### ExpandableText
Description text, 6 lines collapsed at 100% text scale, with `common.showMore` / `common.showLess` TextButton. At 200% text scale the collapsed limit stays 6 lines. Description is plain text (HTML entities decoded by the backend).
- Semantics: the button states whether it expands or collapses; the full text is always in the semantics tree.

### BggAttribution
BoardGameGeek is credited by name and the "Powered by BGG" logo is shown, linked to BoardGameGeek, at a legible size (BGG-40, BGG-41). It appears on every screen that shows BGG data: game detail (foot), search (foot of the results list), lookup-result (foot, in every state that shows games), collection (foot of each list, and in the left pane in two-pane), collection item edit (foot), listings and price history (foot, because they show the BGG game name), and Settings About. It is not shown on the scanner, manual entry, the list sheet, or backup screens, which show no BGG data.
- Content: the logo image (asset from T-087; semantic label `common.bggLogoLabel`) with the credit text `common.bggCredit` beside or under it. The link URL comes from the backend (T-018); the app never builds BGG URLs. The link opens outside the app.
- Variants: full (logo 40 dp tall with credit text; game detail, Settings, list screens) and compact (logo 32 dp tall with bodySmall credit; listings, price history, item edit). Never smaller than 32 dp tall. 8 dp clear space around the logo.
- Placement rule: inside the scrolling content at the foot, not floating, and never hidden at 200% text (the text wraps under the logo).
- States: default, focused, pressed.
- Open: the official logo file and any size rule (T-087, T-091). Until then a placeholder box with the same semantics is drawn.

### NotThisGameAction
A TextButton with an icon, `gameDetail.notThisGame`, shown on game detail only when the screen was opened from a barcode. Opens the correction flow.

## Collection components

### ListSelectorSheet
Modal bottom sheet on compact; dialog-like anchored card (max 400 dp wide) on medium and expanded. Three large rows: Owned, Wanted, Evaluating, each with an icon, title, one-line description. Tapping a row acts immediately (adds or moves) and closes the sheet. No second confirm. The current list (move mode) is marked with a check and `addToCollection.currentList` and is not tappable.
- States: add mode, move mode, saving (row shows a small progress indicator, others disabled), failed (inline error under the rows, sheet stays open).
- Dismiss: swipe down, tap outside, Back. Dismiss changes nothing.
- Semantics: sheet is a dialog with a title; rows are buttons. Focus lands on the sheet title.

### CollectionTabs
Three tabs (Owned, Wanted, Evaluating), each with a count badge. On compact they are a TabBar under the app bar; on medium and expanded they are a SegmentedButton in the list pane header.
- States: selected, unselected, focused. Label reads `collection.tabCount`.

### SortFilterBar
A search field, a Sort button (opens menu), and a Filter button (opens FilterSheet). A chip row shows applied filters, each removable with a 48 dp target.
- States: default, searching, filters applied (Filter button shows a count badge and the text count for screen readers), no matches.

### FilterSheet
Bottom sheet (compact) or side sheet/popup card (medium, expanded) with filter groups for the active list: Owned (condition, has photos), Wanted (priority), Evaluating (none beyond search and sort in v1). Applies live; has `collection.filterClear`.

### TotalValueHeader
Card at the top of the Owned list. Shows the estimated total as a headline number, the basis line, coverage line, and oldest-data line. See screens/collection.md for the required words.
- States: loading (skeleton), no current price data (`collection.totalNoData`), partial coverage (summaries older than 24 hours count as no data and are left out, with `collection.totalTooOld`), stale (some priced games 6 to 24 hours old: StaleChip and `collection.totalStale`), offline with cached prices inside the 24 hour limit (age shown).
- Never shows "$0" for no data.

### PriceInline
A compact price line inside a collection row: `collection.rowPrice`. Contains amount, the word "asking", source "eBay", listing count, and age. States: priced (within 6 hours), stale (6 to 24 hours, adds "Out of date"), none (`collection.rowPriceNone`), missing or too old (`collection.rowPriceMissing`; a summary older than 24 hours is treated as no current price data and its amount is never shown).

### FormFields (MoneyField, DateField, ChoiceField, MultiLineField, ChipChoice)
- MoneyField: leading "$" in the prefix, numeric keyboard with decimal, max 2 decimals, clear button (48 dp), helper and error text. Value is USD only.
- DateField: shows formatted date (Oct 11, 2026), opens the system date picker on tap, clear button. No future dates for purchase date.
- ChoiceField: dropdown menu (condition) or SegmentedButton (priority).
- MultiLineField: grows with content, min 3 lines.
- States for all: empty, filled, focused, error (error text plus error icon, not color alone), disabled.
- Autosave: a field commits when it loses focus or the screen closes. `itemEdit.saved` is announced politely after each save.

### PhotoStrip
Horizontal list of square photo thumbnails (96 dp) with an "Add photo" tile first. Tapping a photo opens a full-screen viewer with a Remove action (snackbar Undo, no dialog).
- States: empty (hint text), loaded, loading thumbnail, permission denied (inline message with Open settings), failed to read.

## Pricing components

### PriceBadge
Small labeled chip: "Asking price" (`price.badgeAsking`) with a tag icon, on secondaryContainer. v1 has asking prices only (EBAY-100): there is no sold variant, no sold copy, and no sold state anywhere. If sold prices are ever approved, a separate badge, icon, and spec update come first.
- Semantics: label is the text.

### PriceSummaryCard
The pricing section on game detail. Contents in order: PriceBadge and section title, median amount (headlineMedium) with `price.median`, range line (`price.range`), sample size (`price.sample`), source line (`price.source`), DataAgeLabel (`price.updated`), optional StaleChip, optional FewListingsNote, and two actions (`price.seeListings`, `price.seeHistory`).
- States:
  - loading: PriceSummary skeleton.
  - success: all lines.
  - few listings (fewer than 3 [ASSUMPTION]): numbers shown plus `price.fewNote`.
  - none: `price.noneTitle` and `price.noneBody`. No amount, no "$0". Source line still shown.
  - stale (older than 6 hours [ASSUMPTION], EBAY-20): StaleChip plus `price.staleNote`. Numbers still show.
  - too old (older than 24 hours [ASSUMPTION, Q24]): no numbers. `price.tooOldTitle` and `price.tooOldBody`, with Retry when online. The source line stays. Never shows $0 or the old amount.
  - error with no cache: ErrorState inside the card with Retry.
  - offline with cache: valid only within the 24 hour limit. Data plus `price.offlineNote`, and the StaleChip after 6 hours. Past 24 hours the card is in the too old state.
- The AffiliateDisclosure (`common.disclosureShort`, placeholder) sits directly above the two action buttons inside the card, next to "See eBay listings", the only way from game detail to eBay links.
- Semantics: the card is one group whose label is `price.summaryLabel`; actions are separate buttons.

### DataAgeLabel
Text such as "Updated 5 hours ago" using the shared time formatter. Always present with any price.

### StaleChip
Chip with a clock icon and `price.stale`, shown when price data is more than 6 hours old. Uses errorContainer or tertiaryContainer with text that passes 4.5:1. Not color alone: icon and word.

### FewListingsNote
Inline note with an info icon and `price.fewNote` or `listings.fewNote`.

### ListingRow
Thumbnail (CoverImage variant, 72 dp, placeholder allowed), title (bodyLarge, wraps up to 3 lines at 100%, no limit at large text), price (titleMedium) followed by the word "asking" in the same line, condition (bodyMedium), shipping note (`listings.rowShippingNote`, bodySmall), the row's own age (`listings.rowAge`, "Checked 2 hours ago", bodySmall; a row older than 6 hours is never rendered, EBAY-20), and a "View on eBay" button (OutlinedButton, 48 dp minimum height, external-link icon).
- No thumbnail in no-image mode.
- States: default, pressed, focused, skeleton, opening (button shows no spinner delay; the link opens immediately), open failed (snackbar `listings.openFailed`).
- Whole-row tap is not used; only the button opens eBay, so scrolling does not trigger accidental opens. [ASSUMPTION; reviewers may prefer a whole-row tap]
- No confirmation step. The button opens the backend-provided URL outside the app.
- Semantics: row label `listings.rowLabel`; button label `listings.viewOnEbayLabel`.

### AffiliateDisclosure
Inline text (bodyMedium, onSurface for 4.5:1) with an info icon. Wording is a PLACEHOLDER until Q25 and T-050. It must use an EPN-approved phrase such as "Paid link" and must not use "affiliate link" (EBAY-93). EPN's rule (EBAY-92): visible without scrolling and close to the links; text only in Settings, behind a link, or in small print is not enough. It is not a modal and never needs acknowledgment.
- Placements: (1) Listings screen: pinned in the top region, on screen with no scrolling at every size, including phone landscape and text at 200% (screens/listings.md). (2) Game detail: directly above the "See eBay listings" button inside the price card. (3) Settings: the full text, visible without a tap. Any new screen that shows an eBay link places it next to the link.
- States: default only. Wraps in full at large text; never truncated.
- Semantics: read in order with the listings.

### PriceHistoryChart
fl_chart line chart of the median asking price by day. Axis labels: dates on x, dollars on y. Points are marked with dots when fewer than 15 points. Days with no listings are gaps, not zeros. The line and area use primary; gridlines use outlineVariant (3:1 not required for gridlines because the information is also in the text summary and table).
- States: loading (Chart skeleton), success, history unavailable (feature flag off: EmptyState `history.unavailableTitle`, no chart), few points (fewer than 7 days: dots only, with `history.fewPoints`), empty (`history.emptyTitle`), error, offline with cache.
- Interaction: tap or drag shows a tooltip card with the date, price, and listing count; keyboard and screen reader users use the table instead.
- Semantics: the chart node has `history.chartLabel` containing the text summary; individual points are excluded; "Show as table" is the accessible detail view. Never rely on color alone: single series.
- Reduce motion: no draw animation.

### ChartTextSummary
Visible text paragraph under the chart: `history.summary`. Always visible, not hidden, so it serves everyone.

### RangeSelector
SegmentedButton or chip group: 30 days, 90 days, 1 year, All. Each segment is 48 dp tall. Selected state shows a check icon plus fill. Announces the selection and the new summary.

### HistoryTable
Alternate view of the chart data: rows of date, median asking, listing count. Shown when "Show as table" is on. The chart stays the default view at every text scale; the toggle is always one tap away.

## Scanner components

### ScannerViewfinder
Camera preview filling the content area with a centered scan frame (rounded rectangle, 4 corner marks, 2.5:1 aspect, 70% of the width) and a scrim outside the frame. The frame and the hint text are drawn on a scrim so they stay readable on any camera image (hint sits on a surface-colored pill with onSurface text, 4.5:1).
- States: starting (spinner and `scanner.starting`), scanning, detected (frame flashes primary for 300 ms, check icon, haptic; with reduce motion no flash, only the check), paused (app in background, preview frozen and stopped), permission requesting, denied, permanently denied, restricted, camera unavailable.
- Semantics: `scanner.viewfinderLabel`; success announced with `scanner.success`.

### TorchToggle
48 dp icon toggle in the top corner of the viewfinder. Hidden when the device has no torch.
- States: off, on, disabled while camera starts. Label switches between `scanner.torchOn` (action when off) and `scanner.torchOff` (action when on); state also in `scanner.torchLabelOn/Off`.

### ScanActionBar
Two buttons always visible below (compact) or beside (landscape) the viewfinder: `scanner.actionManual` (FilledTonalButton) and `scanner.actionSearch` (FilledTonalButton). Present in every scanner state.

### PermissionPanel
Card in the viewfinder area for requesting, denied, permanently denied, restricted, and unavailable states: icon, title, body, one primary action (Allow camera, Open settings, or Retry). The ScanActionBar stays visible beneath it.

### BarcodeField
Numeric TextField, digits only, max 13, counter `manualEntry.digitCounter`, clear button. Error text appears under the field with an error icon and is announced.
- States: empty with helper, typing, valid-looking, error (length, non-digit, check digit), submitting.

## Settings components

### SettingsRow
ListTile with leading icon, title, optional subtitle, optional trailing control. Minimum height 56 dp. Whole row is the tap target.

### SettingsSection
Header (titleSmall, primary) over a group of SettingsRows.

### ImportPreview
Summary line (`backup.importPreviewSummary`), an expandable list of skipped rows with reasons, and the confirm button. Used for CSV import and restore preview.
- States: parsing (progress), ready, all rows skipped (confirm disabled, explanation), file unreadable (ErrorState).
