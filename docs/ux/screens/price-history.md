# Screen spec: Price history

Status: draft for user review (T-003). Ticket: T-063. Flow: flows/view-prices-and-history.md.

## 1. Purpose and entry points

Show how the median asking price for a game has moved, from our own daily snapshots. Entry: `price.seeHistory` on game detail. Pushed screen with the navigation visible. History starts the first day anyone looked up the game; there is no backfill, and the screen says when it starts.

## 2. Layout

| Size | Layout |
|---|---|
| Compact portrait | App bar with Back and `history.title`. Game name and `history.subtitle`. RangeSelector (four segments, 48 dp tall). Chart (16:9, about 220 dp tall at 100% text). Below the chart: ChartTextSummary (always visible), `history.startsOn`, `history.gapNote`, `history.source`, and the `history.showTable` toggle. |
| Phone landscape | Chart takes the left 62% at full height; summary, range selector, and notes in the right column. |
| Medium | One column, 640 dp; chart 280 dp tall. |
| Expanded | Two columns: chart (about 60%) left, text summary, range selector, notes right. |

At 200% text the chart keeps its height (it is a graphic); axis labels use the scaled type but are limited to 4 ticks on x and 4 on y; the text summary and table carry the information.

## 3. Components

PriceHistoryChart, ChartTextSummary, RangeSelector, HistoryTable, BggAttribution (compact, at the foot), PriceBadge, DataAgeLabel, SkeletonBlock, EmptyState, ErrorState, OfflineBanner. See docs/ux/components.md.

## 4. States

| State | What the user sees |
|---|---|
| Loading | Chart skeleton, summary skeleton lines. Range selector disabled. |
| Success | Line chart of median asking price per day, ChartTextSummary (`history.summary`), `history.startsOn`, source line `history.source` ("Asking prices, not sold prices"), the PriceBadge `price.badgeAsking`. Tooltip on tap or drag shows the date, the median asking price, and the listing count. |
| Few points (under 7 days) | Dots joined by a thin line, `history.fewPoints` under the chart, and the summary still reads in full. |
| One point | A single dot, `history.fewPoints`, and the summary with the value and date. |
| Gaps (days with no listings) | The line breaks; no zero is drawn. `history.gapNote` shows. In the table, the row reads `history.tableNoListings`. |
| Empty (no history yet) | EmptyState: `history.emptyTitle`, `history.emptyBody`, and `history.startsOn` if the start date is known. No chart. |
| Error, no cache | ErrorState `history.errorTitle`, plain body, Retry. |
| Offline with cache | OfflineBanner, cached chart, `history.offlineNote` with age. |
| Range with no data | The selected range shows the data it has and `history.startsOn`; the selector does not hide ranges. |
| Table view | Replaces the chart with HistoryTable (Date, Median asking, Listings). Toggle label becomes `history.hideTable`. The text summary stays. |
| History unavailable | The history feature is off (PRD Q24, section 6 rule 9; a backend flag, and the backend answers that history is unavailable). EmptyState: `history.unavailableTitle`, `history.unavailableBody`. No chart, no range selector, no table. The page does not use words like "error". Current asking prices remain available through Back. Game detail hides the `price.seeHistory` action when the feature is off, so users normally never reach this state; it exists for a flag that flips while the user is on the screen and for cached navigation. |

v1 has asking prices only (EBAY-100), so there is no sold history state.

## 5. Interactions and navigation

- Range selector changes the chart, summary, and table at once and announces the new summary.
- Chart: tap or drag shows the tooltip. Keyboard and screen reader users use the table instead.
- Pull to refresh.
- Back returns to game detail.

## 6. Copy

`history.*` (all keys), `common.bggCredit`, `common.bggLogoLabel`, `price.badgeAsking`, `common.retry`, `common.refreshFailed`.

## 7. Accessibility

- The chart node has the label `history.chartLabel` (which contains the full text summary) and is a single focusable element. Its individual points are excluded; screen reader users get the summary, and "Show as table" for detail.
- The visible ChartTextSummary is the same text, so it is also available to sighted users with low vision and to translation tools.
- Example summary: "Median asking price on eBay US, used. From Sep 1, 2026 to Oct 11, 2026: started at $38.00, now $42.00, up 11 percent. Lowest $36.00 on Sep 9, 2026, highest $45.00 on Oct 2, 2026. 41 days of data."
- The range selector announces "Show 90 days, selected".
- Chart colors: the line uses primary against surface at 3:1 or better; there is one series, so no color-only coding. Axis text 4.5:1.
- Tooltip is not the only way to read values (table).
- Reduce motion: no draw animation, no animated tooltip.
- Text at 200%: summary and notes wrap in full; selector segments stack to two rows if needed; chart does not clip labels.
- Targets: selector segments and toggle 48 dp.

## 8. Golden cases
Total: 8. Empty, error, offline, one point, and gaps share layouts and are covered by widget tests (the success fixture contains one gap day).

| File | Notes |
|---|---|
| price_history_loading_light_compact.png | |
| price_history_success_light_compact.png | 90 days with summary |
| price_history_success_dark_compact.png | |
| price_history_success_dark_expanded.png | |
| price_history_fewpoints_light_compact.png | 4 days |
| price_history_table_dark_compact.png | Table view |
| price_history_unavailable_light_compact.png | History feature off |
| price_history_success_text200_light_compact.png | |

## 9. What PM and reviewers should check

- Text summary visible and complete; chart label carries it.
- "Asking prices, not sold prices" and source eBay US are shown.
- History start date is stated; no fake backfill.
- Gaps are not zeros.
- Table alternative exists.
- "History unavailable" has plain wording and no chart.
- Open questions: whether the history feature is on at launch (Q24, depends on eBay's answer); how long cached history may be shown offline under eBay's age rules (Q24); date range defaults (90 days proposed).
