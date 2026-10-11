# Screen spec: Collection

Status: draft for user review (T-003). Tickets: T-039 (lists), T-064 (total value and row prices), T-044 (offline). Flows: flows/add-to-collection.md, flows/move-between-lists.md, flows/edit-an-item.md.

## 1. Purpose and entry points

Show the three lists (Owned, Wanted, Evaluating) with sort, filter, and search, and, for Owned, the estimated total. The Collection destination in the shell. Adding a game does not navigate here; the snackbar offers Undo and Add details only. Works fully offline.

## 2. Layout

| Size | Layout |
|---|---|
| Compact portrait | App bar `collection.title`. Under it: CollectionTabs (Owned, Wanted, Evaluating with counts). Then SortFilterBar (search field, Sort, Filter) and the applied-filter chips. For Owned only: TotalValueHeader above the list. Then the list of GameListRow (collection variant). The list scrolls under the tabs; the tabs and search stay pinned [ASSUMPTION]. |
| Phone landscape | Same order, single column; TotalValueHeader collapses to one line (amount and basis) to leave room. |
| Medium | Single pane; list capped at 640 dp, centered. The tabs are a SegmentedButton above the list. |
| Expanded | TwoPane: left (400 dp) holds SegmentedButton tabs, SortFilterBar, TotalValueHeader (Owned), and the list; right shows game detail with the collection section for the selected row, or `collection.pickAGame`. |

Row content by list (subtitle line):

- Owned: `collection.rowOwnedLine` ("Very good, bought $20.00"); fields that are not set are left out. Under it the PriceInline (M4).
- Wanted: `collection.rowWantedLine` ("Target $30.00, High priority"). PriceInline (M4) so the user sees the gap to target.
- Evaluating: `collection.rowEvaluatingLine` ("Added Oct 11, 2026"). PriceInline (M4).

Every row shows thumbnail, name, year (in the label), then the type-specific line. Swipe actions are not used (not accessible by default); a row's overflow menu (48 dp icon button, label "More actions for {name}") offers Move, Edit, Remove. Long press opens the same menu.

## 3. Components

CollectionTabs, SortFilterBar, FilterSheet, TotalValueHeader, PriceInline, GameListRow, SkeletonRow, EmptyState, ErrorState, OfflineBanner, LastUpdatedLabel, TwoPane, ListSelectorSheet, Snackbar. See docs/ux/components.md.

## 4. States

| State | What the user sees |
|---|---|
| Loading | Skeleton rows (6). Tab counts show a dash. Under 300 ms on local data, so skeletons are only for first paint. |
| Empty (list has no games) | EmptyState per list: `collection.emptyOwnedTitle` and body, `emptyWantedTitle`, `emptyEvaluatingTitle`. Actions: `collection.emptyScan` (primary), `collection.emptySearch`, `collection.emptyAddManual` (when T-043 ships). No total header on an empty list. |
| Success | Rows sorted by the chosen sort (default: Recently added). Count shown in the tab. Tapping a row opens game detail (expanded: right pane). |
| Searching or filtered with no results | EmptyState `collection.noMatchesTitle`, `collection.noMatchesBody`, action `collection.filterClear`. |
| Filters applied | Chip row (each chip removable), Filter button badge with count, `collection.filtersApplied` available to screen readers. |
| Error (database cannot open) | ErrorState: `collection.errorTitle`, `collection.errorBody`, Retry. Plain words, no exception text. |
| Offline | No special state for the list; it is local. Rows with prices show cached prices with their age. OfflineBanner is not shown on this screen (the list is not blocked). The TotalValueHeader shows LastUpdatedLabel when it cannot refresh. |
| Partial data | Rows without a year or thumbnail use placeholders. Rows without prices show `collection.rowPriceMissing`. Fields not set are omitted from the subtitle. |

### Pricing in the Collection (M4)

Every price here follows the pricing rules: amount, the word asking, eBay, sample size, data age.

- **PriceInline** on each row: `collection.rowPrice`: "eBay asking $42.00, 23 listings, 5 hours ago". With no listings: `collection.rowPriceNone` ("eBay: no current listings"), never $0. No data yet: `collection.rowPriceMissing`. Older than 48 hours: `collection.rowPriceStale` adds "Out of date". With fewer than 3 listings the row adds the word "few" via the Few listings chip in the detail view only (rows stay short), but the listing count is always shown.
- **TotalValueHeader** (Owned only):
  - Title `collection.totalTitle`, amount `collection.totalValue` (headlineSmall).
  - Basis line `collection.totalBasis` always visible: "Sum of median eBay asking prices (used, item price only), not sold prices."
  - Coverage line `collection.totalCoverage`: "12 of 15 games have price data."
  - Age line `collection.totalAge`: "Oldest price data: 6 days ago", and `collection.totalStale` if any price is older than 48 hours.
  - No priced games: `collection.totalNoData` and no amount.
  - The words "sold" and "worth" never appear. "Estimated" appears in the title.
  - Loading: skeleton. Offline: cached numbers with LastUpdatedLabel.
- Sorting by price (`collection.sortValue`) puts rows with no price at the bottom.

## 5. Interactions and navigation

- Tabs switch lists; each list keeps its own scroll, search text, sort, and filters until the app closes [ASSUMPTION: sort persists across launches].
- Search filters as the user types (no debounce needed, local) in under 300 ms at 2,000 games.
- Sort opens a menu (radio items); Filter opens FilterSheet (applies live).
- Row tap: game detail. Overflow or long press: Move (opens ListSelectorSheet in move mode), Edit (collection-item-edit), Remove (immediate, Snackbar Undo).
- Moving a game removes it from the current tab and the snackbar says `addToCollection.moved` with Undo.
- Pull to refresh refreshes game info and prices (when online); on failure a snackbar `common.refreshFailed`.
- The scroll position is kept when the user visits other destinations and returns.
- No dialogs.

## 6. Copy

`collection.*` (title, tabOwned, tabWanted, tabEvaluating, tabCount, searchHint, sort and filter strings, empty strings, noMatches, error, row lines, total strings, rowPrice strings, itemCount, pickAGame), `addToCollection.*` (moved, removed, moveButton, removeButton), `common.refreshFailed`, `common.lastUpdated`.

## 7. Accessibility

- Focus order: app bar, tabs, search, Sort, Filter, chips, total header (Owned), rows, navigation.
- Tabs announce "Owned, 24 games, tab 1 of 3, selected".
- Each row is one node: `collection.rowLabel` plus the type line and the price line; the overflow menu is a separate custom action (also exposed as a semantic action on the row for TalkBack and VoiceOver).
- Total header is one grouped node reading amount, basis, coverage, and age.
- After sort or filter changes, the new result count is announced (`collection.itemCount`).
- Contrast: price lines use onSurfaceVariant; the stale marker uses an icon and the words "Out of date".
- Text at 200%: tabs scroll horizontally if labels no longer fit three across (still one tap); rows wrap; total header stacks its lines.
- Targets: rows 72 dp or taller, chips 48 dp tall hit area, overflow button 48 dp.

## 8. Golden cases

| File | Notes |
|---|---|
| collection_owned_light_compact.png | 6 rows, no prices yet (M3 look) |
| collection_owned_dark_compact.png | |
| collection_owned_light_medium.png | |
| collection_owned_dark_expanded.png | Two-pane with detail |
| collection_owned_light_landscape.png | |
| collection_wanted_light_compact.png | Target and priority lines |
| collection_evaluating_dark_compact.png | Date added line |
| collection_loading_light_compact.png | Skeleton |
| collection_empty_owned_light_compact.png | |
| collection_empty_owned_dark_compact.png | |
| collection_empty_wanted_dark_expanded.png | |
| collection_empty_evaluating_light_compact.png | |
| collection_nomatches_light_compact.png | Filters applied, none match |
| collection_filtersapplied_dark_compact.png | Chips and badge |
| collection_error_light_compact.png | |
| collection_owned_text200_light_compact.png | |
| collection_owned_text200_dark_expanded.png | |
| collection_owned_prices_light_compact.png | M4: total header and row prices |
| collection_owned_prices_dark_compact.png | M4 |
| collection_owned_prices_dark_expanded.png | M4 |
| collection_owned_pricesstale_light_compact.png | M4: stale marker |
| collection_owned_pricesnone_light_compact.png | M4: no price data, no listings |
| collection_owned_pricesoffline_dark_compact.png | M4: cached prices with age |
| collection_owned_prices_text200_light_compact.png | M4 |

## 9. What PM and reviewers should check

- Empty states tell the user how to add the first game.
- Total header basis line says asking prices, not sold, and counts games without data.
- Row price lines show amount, asking, eBay, count, age.
- No-data rows never show $0.
- Move and remove have Undo, no dialogs.
- Scroll position survives tab switches.
- Open questions: persist sort and filters across launches; whether the tab bar stays pinned; the "oldest price data" wording for the total's age.
