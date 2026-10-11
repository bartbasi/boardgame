# Screen spec: Lookup result and candidate selection

Status: draft for user review (T-003). Ticket: T-033. Flows: flows/scan-to-game-detail.md, flows/barcode-candidates-and-correction.md.

## 1. Purpose and entry points

Turn a validated barcode into a game. Pushed after a scan or after manual entry, with the normalized code. Also the correction entry for "Not this game?" on game detail. A `matched` result does not stay on screen: it hands off to game detail at once.

## 2. Layout

| Size | Layout |
|---|---|
| Compact portrait | App bar with Back and `lookup.title` (shows the code). Content: header text, then a list of candidate rows (GameListRow candidate variant), then an action area with `lookup.actionSearch` (FilledTonalButton) and `lookup.actionOtherBarcode` (TextButton). Actions follow the list and stay reachable by scrolling; when there are 3 or fewer candidates they sit right under the list. |
| Phone landscape | Two columns: header and actions on the left (40%), list on the right (60%). |
| Medium | ContentColumn 600 dp; same order as compact. |
| Expanded | TwoPane: left candidate list (400 dp) with header and actions; right pane shows the highlighted candidate's detail preview (cover, name, year, description start) so the user can tell similar editions apart. Picking is by "Use this game" button in the right pane, and also by tapping the row. [ASSUMPTION: simple single column is acceptable if the right pane is cut for time.] |

For none, unavailable, offline, and error states the content is an EmptyState or ErrorState centered in a 600 dp column with two actions.

## 3. Components

GameListRow (candidate variant), SkeletonRow, EmptyState, ErrorState, OfflineBanner, TwoPane, Snackbar. See docs/ux/components.md.

## 4. States

| State | What the user sees |
|---|---|
| Loading | `lookup.loading` text and 3 skeleton rows. The code is shown in the app bar. A stored match on the device skips this screen's visible loading (the game opens at once, see Matched). |
| Matched | Not shown as a list. The route is replaced by game detail for that game. If detail needs loading, game detail shows its own skeleton. |
| Candidates (several) | Header `lookup.candidatesTitle` and body `lookup.candidatesBody`. Up to 10 rows [ASSUMPTION], in the backend's ranking order, each with thumbnail or placeholder, name, year. Tapping a row saves it as the match and opens the detail. Actions below: `lookup.actionSearch`, `lookup.actionOtherBarcode`. |
| None | EmptyState: `lookup.noneTitle`, `lookup.noneBody`; primary `lookup.actionSearch` (opens Search in barcode mode); secondary `lookup.actionOtherBarcode`; tertiary `lookup.actionScanAgain`. |
| Unavailable (barcode source down) | EmptyState-style: `lookup.unavailableTitle`, `lookup.unavailableBody`; primary `lookup.actionSearch`; secondary `common.retry`; tertiary `lookup.actionOtherBarcode`. |
| Offline, no stored match | EmptyState with offline icon: `lookup.offlineTitle`, `lookup.offlineBody`; actions `common.retry` and `lookup.actionSearch`. OfflineBanner shown. |
| Offline, stored match | Same as Matched: opens game detail from the device cache with the "Last updated" label. |
| Error: service unavailable | ErrorState: `common.errorUnavailableTitle`, `common.errorUnavailableBody`, Retry, and `lookup.actionSearch`. |
| Error: rate limited | `common.errorRateLimitedBody` with seconds if known, Retry, and `lookup.actionSearch`. |
| Error: timeout | `common.errorTimeoutBody`, Retry. |
| Correction mode | Opened from "Not this game?". Header `lookup.correctionTitle`, body `lookup.correctionBody`, the current match row is marked with the tag `lookup.currentMatch`. Candidates come from a fresh lookup when online; offline or when the lookup returns nothing, the screen shows the current match and `lookup.actionSearch`. Picking a different game replaces the stored match and replaces this screen with that game's detail. Picking the current match just goes back. |
| Partial data | A candidate with no year shows the name only; no thumbnail shows the placeholder. |

## 5. Interactions and navigation

- Tap a candidate: save match (device), show snackbar `lookup.matchSaved`, replace this route with game detail.
- `lookup.actionSearch`: push Search in barcode mode (banner with the code). A result chosen there saves the match for the code.
- `lookup.actionOtherBarcode`: push manual-entry.
- `lookup.actionScanAgain` and Back: return to the scanner, ready to scan again.
- Retry reruns the lookup. Pull to refresh does the same.
- Back always returns to where the user came from.

## 6. Copy

`lookup.title`, `lookup.loading`, `lookup.candidatesTitle`, `lookup.candidatesBody`, `lookup.candidateLabel`, `lookup.candidateLabelNoYear`, `lookup.noneTitle`, `lookup.noneBody`, `lookup.unavailableTitle`, `lookup.unavailableBody`, `lookup.offlineTitle`, `lookup.offlineBody`, `lookup.actionSearch`, `lookup.actionOtherBarcode`, `lookup.actionScanAgain`, `lookup.correctionTitle`, `lookup.correctionBody`, `lookup.currentMatch`, `lookup.matchSaved`, `common.retry`, `common.errorUnavailableTitle`, `common.errorUnavailableBody`, `common.errorRateLimitedBody`, `common.errorTimeoutBody`.

## 7. Accessibility

- Focus order: Back, header, candidate rows in order, actions, navigation.
- Each candidate row reads `lookup.candidateLabel` ("Catan, 1995. Opens details and remembers this match."). The current match row also says "Current match".
- State changes (loading, none, unavailable, error) announce their title politely; errors use a live region.
- The saved-match snackbar is announced.
- Text at 200%: rows wrap; actions become full width; nothing is clipped; the two-pane collapses to one column below 840 dp regardless of text size.
- Contrast: tag chips use secondaryContainer with onSecondaryContainer (4.5:1).

## 8. Golden cases

| File | Notes |
|---|---|
| lookup_result_loading_light_compact.png | Skeleton |
| lookup_result_loading_dark_compact.png | |
| lookup_result_candidates_light_compact.png | 3 candidates, one missing year |
| lookup_result_candidates_dark_compact.png | |
| lookup_result_candidates_light_medium.png | |
| lookup_result_candidates_dark_expanded.png | Two-pane with preview |
| lookup_result_candidates_light_landscape.png | |
| lookup_result_none_light_compact.png | Not found with 3 actions |
| lookup_result_none_dark_compact.png | |
| lookup_result_unavailable_light_compact.png | |
| lookup_result_offline_dark_compact.png | Offline banner and message |
| lookup_result_offline_light_expanded.png | |
| lookup_result_error_light_compact.png | Service unavailable |
| lookup_result_ratelimited_light_compact.png | |
| lookup_result_correction_light_compact.png | Current match tag |
| lookup_result_correction_dark_expanded.png | |
| lookup_result_candidates_text200_light_compact.png | |
| lookup_result_none_text200_dark_compact.png | |

## 9. What PM and reviewers should check

- A matched barcode never stops on this screen.
- Candidates, none, unavailable, and offline each offer a title search.
- Copy says "Barcode lookup is not available right now" for unavailable.
- Picking a candidate or search result saves the match and the correction replaces an old match.
- Offline with a stored match opens the game.
- Open questions: how many candidates to show (10 is an assumption in T-025); whether the expanded right-pane preview is worth building in M2.
