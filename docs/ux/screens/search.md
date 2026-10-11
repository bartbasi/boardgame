# Screen spec: Title search

Status: draft for user review (T-003). Ticket: T-032. Flows: flows/title-search-to-game-detail.md, flows/barcode-candidates-and-correction.md.

## 1. Purpose and entry points

Find a game by title. Entry points: the Search destination; `scanner.actionSearch`; "Search by title" on lookup-result (none, unavailable, offline, correction); `manualEntry.searchInstead`; empty states on Collection. When opened from a barcode that had no match, the screen is in barcode mode: a banner says which barcode the choice will be saved for.

## 2. Layout

| Size | Layout |
|---|---|
| Compact portrait | App bar `search.title`. Search field (SearchBar style, full width, 56 dp) with clear button, keyboard action "Search". Under it: results list (GameListRow, 72 dp or taller), then a footer with the BGG credit and the Powered by BGG logo (BggAttribution full, BGG-40, BGG-41). In barcode mode a banner (`search.forBarcodeBanner`) sits between the field and the list. Tapping a result pushes game detail. |
| Phone landscape | Field on top at full width; results below in one column, up to 2 columns of rows [ASSUMPTION: single column]. Keyboard overlays; list scrolls. |
| Medium | Same as compact; results list capped at 640 dp wide and centered; thumbnails 64 dp. |
| Expanded | TwoPane. Left (400 dp): field, banner, results. Right: the selected game's detail (game-detail spec embedded). Nothing selected shows `search.paneEmpty`. Tapping a result loads its detail on the right without leaving search. |

Entry buttons "Enter barcode" and "Scan a barcode" appear as text actions in the initial and empty states, and as a trailing icon button (48 dp, label `search.actionManual`) in the app bar at all times, so manual entry is one tap from search.

## 3. Components

GameListRow (search result variant), CoverImage, SkeletonRow, EmptyState, ErrorState, OfflineBanner, BggAttribution, TwoPane, AdaptiveScaffold. See docs/ux/components.md.

## 4. States

| State | What the user sees |
|---|---|
| Initial (no query) | Field focused (keyboard open on arrival from the scanner or lookup; not auto-opened when the user arrives by tapping the tab, so the tab can be browsed). EmptyState: `search.initialTitle`, `search.initialBody`, actions `search.actionScan` and `search.actionManual`. |
| One character | Hint `search.hintShort` under the field. No request. |
| Loading | 5 skeleton rows under the field. The previous results are replaced only when the new ones arrive (so typing does not flash empty). A subtle linear progress line under the field while a request is in flight. |
| Success | Rows with thumbnail, name, year. A count line `search.resultCount` above the list (read by screen readers). Exact title matches come first (backend order). Footer: BGG credit and logo. |
| Empty (no results) | EmptyState: `search.emptyTitle`, `search.emptyBody`, action `search.actionManual`. |
| Error: service unavailable | ErrorState: `search.errorTitle` plus `common.errorUnavailableBody`, Retry reruns the same query. |
| Error: rate limited | ErrorState: `search.errorTitle` plus `common.errorRateLimitedBody` (or the no-time version), Retry stays enabled. |
| Error: timeout | `common.errorTimeoutBody`, Retry. |
| Offline | ErrorState variant with the offline icon: `search.offlineTitle`, `search.offlineBody`, Retry, plus actions to open the Collection or scan (works offline for known barcodes). OfflineBanner is shown. Search results are not cached (T-029), so there is nothing to show. |
| Partial data | A row with no year shows the name only (`search.resultLabelNoYear`); a row with no thumbnail shows the placeholder. |
| Barcode mode | Banner `search.forBarcodeBanner` is always visible while the list scrolls (pinned). Tapping a result stores the match and opens that game's detail. |
| Out-of-order responses | A late response for an older query is dropped; the screen shows only the latest query's results. |

Debounce: a search runs 400 ms after the last keystroke [ASSUMPTION], or at once when the user presses the keyboard's search key.

## 5. Interactions and navigation

- Typing searches after the debounce. Clear button empties the field and returns to the initial state.
- Tap a result: push game detail for that bggId (expanded: load in the right pane). In barcode mode, the barcode match is saved first, then detail opens, with a snackbar `lookup.matchSaved`.
- Retry: reruns the last query, keeping the field text.
- Pull to refresh on the results list reruns the query.
- Back from detail returns to the same query and scroll position.
- Leaving the tab keeps the query and results; switching back restores them.
- No sorting or filtering controls in v1.

## 6. Copy

`search.title`, `search.fieldLabel`, `search.fieldHint`, `search.clear`, `search.hintShort`, `search.initialTitle`, `search.initialBody`, `search.actionScan`, `search.actionManual`, `search.emptyTitle`, `search.emptyBody`, `search.errorTitle`, `search.offlineTitle`, `search.offlineBody`, `search.resultCount`, `search.resultLabel`, `search.resultLabelNoYear`, `common.bggCredit`, `common.bggLogoLabel`, `search.forBarcodeBanner`, `search.paneEmpty`, `common.retry`, `common.errorUnavailableBody`, `common.errorRateLimitedBody`, `common.errorRateLimitedBodyNoTime`, `common.errorTimeoutBody`, `lookup.matchSaved`.

## 7. Accessibility

- Focus order: app bar (title, manual entry button), search field, clear button, barcode banner, count line, rows, footer attribution, navigation.
- Each row is one node: "{name}, {year}", with the hint "opens details". Thumbnails are excluded from semantics.
- When results change, the count line is announced politely ("12 games found"). Loading, empty, and error states announce their title.
- Keyboard: the search key submits immediately. Escape or the clear button clears.
- Contrast: result subtitles use onSurfaceVariant on surface (4.5:1 or better in both themes).
- Text at 200%: names wrap fully (no ellipsis); thumbnail shrinks to 48 dp (or is absent in no-image mode); the field label stays visible; the footer wraps.
- Skeleton rows are one polite "Loading" announcement.

## 8. Golden cases
Total: 8 (this ticket also delivers the two app_shell offline goldens listed in app-shell.md). Error, rate limited, and offline share one layout; the offline golden covers it. Barcode mode, no-image mode, and partial rows are covered by widget tests; the results golden includes rows with a missing year and a missing thumbnail, and shows the BGG credit at the foot of a short list.

| File | Notes |
|---|---|
| search_initial_light_compact.png | Initial empty state with two actions |
| search_loading_light_compact.png | Skeleton rows |
| search_results_light_compact.png | 3 rows, mixed missing year and thumbnail, BGG credit and logo visible |
| search_results_dark_compact.png | |
| search_results_selected_dark_expanded.png | Two-pane with a selected game detail |
| search_empty_light_compact.png | No results |
| search_offline_light_compact.png | Offline banner and message |
| search_results_text200_light_compact.png | Wrapped names |

## 9. What PM and reviewers should check

- One character shows the hint; two or more search after the pause.
- Late "cat" results never overwrite "catan".
- Empty state offers manual entry and says check the spelling.
- Offline shows a plain message with Retry, not raw text.
- Barcode mode banner and the saved match.
- Open question: whether result thumbnails may load directly from BGG's image host (PRD Q5). Until answered, golden thumbnails use placeholders.
