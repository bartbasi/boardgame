# Screen spec: Game detail

Status: draft for user review (T-003). Tickets: T-034 (M2 part), T-038 and T-040 to T-042 (collection part, M3), T-061 and T-062 (pricing part, M4). Flows: all scan and search flows, add-to-collection, view-prices-and-history, open-listing-on-ebay.

The screen is built in three layers. Each ticket adds its layer; earlier layers must not change. Section order on the page: Header, Collection (M3), Price (M4), Facts, Description, Attribution. In M2 only Header, Facts, Description, and Attribution show (T-034 criterion 12).

## 1. Purpose and entry points

Show what a game is, what the user has done with it, and what it sells for. Entry: lookup-result (matched or chosen candidate), Search result, Collection row, and the right pane of two-pane layouts. It works offline from the device cache.

## 2. Layout

| Size | Layout |
|---|---|
| Compact portrait | App bar with Back and the title (the game name, one line, shown when the header scrolls off; the full name is in the header). One scrolling column: DetailHeader (cover 160 dp wide on the left, name and year on the right at 100% text; stacked at 200%), then `Not this game?` action (when opened from a barcode), then Collection section, Price section, Facts (two-column grid of FactRows), Description (ExpandableText), BGG attribution. LastUpdatedLabel sits under the header. Pull to refresh on the whole column. |
| Phone landscape | Two columns: left (40%) holds cover, name, year, collection actions; right (60%) scrolls with Price, Facts, Description, Attribution. |
| Medium | One column in a 640 dp content width centered, cover 200 dp. Price section and Facts sit side by side when width allows (two 300 dp columns). |
| Expanded | Two columns, each independently scrolling: left (about 40%): cover, name, year, collection actions, Facts, Attribution; right: Price section, Description. As the right pane of TwoPane (Search, Collection), the same two columns apply when the pane is at least 640 dp wide, otherwise the compact layout is used inside the pane. |

Cover is a 2:3 portrait image; if the image is square or wide, it is fitted (not cropped) in its box with the placeholder color behind it.

## 3. Components

DetailHeader, CoverImage, NotThisGameAction, LastUpdatedLabel, OfflineBanner, FactRow, ExpandableText, BggAttribution, ListSelectorSheet, PriceSummaryCard, PriceBadge, DataAgeLabel, StaleChip, FewListingsNote, AffiliateDisclosure, SkeletonBlock, EmptyState, ErrorState, Snackbar. See docs/ux/components.md.

## 4. States

### M2: game information

| State | What the user sees |
|---|---|
| Loading (no cache) | DetailHeader skeleton (cover block, two text bars), a facts skeleton, three description lines. App bar title is blank. |
| Success | Cover, name, year (`gameDetail.year`), Facts: players (`gameDetail.players`), play time, designers, publishers; Description under `gameDetail.description` (collapsed to 6 lines with Show more); BggAttribution; LastUpdatedLabel ("Details last updated just now"). |
| Partial data | Any missing field is hidden: no year, no players, no play time, no designers, no publishers, no image (placeholder cover, label `common.coverPlaceholderLabel`), no description (`gameDetail.descriptionEmpty`). Never "null", "0", "unknown", or an empty label. If the whole Facts group is empty, the section header is hidden too. |
| Not found | EmptyState: `gameDetail.notFoundTitle`, `gameDetail.notFoundBody`, action `gameDetail.notFoundAction` (opens Search). |
| Error, no cache | ErrorState: `gameDetail.errorTitle` with the plain body (`common.errorUnavailableBody`, `common.errorTimeoutBody`, or rate limited), Retry. |
| Offline with cache | Everything from the cache shows. OfflineBanner plus `gameDetail.updatedLabel` ("Details last updated 3 days ago"). No error screen. |
| Offline, no cache | ErrorState with `common.offlineNoData` and Retry. |
| Refreshing (pull to refresh) | Standard pull indicator; content stays. Success: content and label update and the label reads "just now". Failure: cached content stays and a snackbar shows `common.refreshFailed`. |
| Opened from a barcode | NotThisGameAction visible under the header. |
| Very long title (200 characters, Unicode) | Wraps to as many lines as needed in the header and the app bar title (app bar shows one line with ellipsis, the header shows all). No overflow at 200% text. |

### M3: collection section (right after the header)

| State | What the user sees |
|---|---|
| Not in collection | A single prominent FilledButton `addToCollection.button`. Opens ListSelectorSheet. One tap on a list adds the game at once (Snackbar `addToCollection.added` with Undo and "Add details"). |
| In a collection list | A card: `gameDetail.inCollection` (for example "In your collection: Owned") and a compact list of the main fields for that list (for example condition and purchase price for Owned). Actions: Edit (opens collection-item-edit), `addToCollection.moveButton` (opens the sheet in move mode), `addToCollection.removeButton` (removes at once with Undo snackbar `addToCollection.removed`). |
| Saving | The button shows a small progress indicator for the moment of the write. No full-screen blocking. |
| Failed to save | Snackbar `addToCollection.failed`. |

The collection section works fully offline.

### M4: price section (below the Collection section)

All prices are eBay US, used condition, item price without shipping, and asking prices. Every state keeps the source line.

| State | What the user sees |
|---|---|
| Loading | PriceSummaryCard skeleton, with `price.loadingLabel` for screen readers. The rest of the page is usable. |
| Success | PriceBadge `price.badgeAsking`; section title `price.sectionTitle`; median `price.median` with the amount (headlineMedium); range `price.range`; sample `price.sample`; source `price.source`; age `price.updated`; actions `price.seeListings` and `price.seeHistory`; a single AffiliateDisclosure line (placeholder) under the actions. |
| Few listings (under 3 [ASSUMPTION]) | Same numbers plus the FewListingsNote `price.fewNote`. |
| No listings | `price.noneTitle` ("No current listings") and `price.noneBody`. No amount, no "$0". Source line stays. `price.seeHistory` stays if history exists. |
| Stale (older than 48 hours [ASSUMPTION]) | StaleChip `price.stale` and `price.staleNote` next to the age label. |
| Offline with cache | The cached numbers with `price.offlineNote` and the age. |
| Error, no cache | Inline ErrorState in the card: `price.errorTitle`, Retry. The rest of the page stays. |
| Sold prices (later, feature flag) | A second card with PriceBadge `price.badgeSold`, `price.medianSold`, `price.sampleSold`. Never merged or averaged with asking. Hidden entirely while the flag is off (do not show `price.soldDisabledNote`, which is only for tests of the off state). |

Wording rules: the amount is always followed by or next to the word "asking". The words "sold", "value", and "sale" never appear next to an asking price. The only place "estimated" appears is the collection total.

## 5. Interactions and navigation

- Back returns to the origin. In a TwoPane, there is no Back; selecting another row replaces the right pane.
- NotThisGameAction opens lookup-result in correction mode.
- Description Show more and Show less toggle in place.
- `price.seeListings` pushes listings. `price.seeHistory` pushes price-history. Both pass the bggId.
- The BGG attribution link opens outside the app (placeholder behavior from T-002).
- Pull to refresh refreshes game info and, in M4, price data together.
- Share is not in v1.
- No dialogs. Snackbars never block.

## 6. Copy

M2: `gameDetail.*` (title, notThisGame, notThisGameLabel, players, playersValue, playersValueSingle, playTime, playTimeValue, playTimeValueSingle, designers, publishers, year, description, descriptionEmpty, notFoundTitle, notFoundBody, notFoundAction, errorTitle, updatedLabel, dataFromBgg, openOnBgg), `common.*` (coverLabel, coverPlaceholderLabel, showMore, showLess, lastUpdated, offlineBanner, offlineNoData, refreshFailed, retry, error strings, poweredByBgg placeholders).
M3: `gameDetail.inCollection`, `gameDetail.collectionSection`, `addToCollection.*`.
M4: `price.*`, `listings.disclosure` (placeholder).

## 7. Accessibility

- Focus order: Back, header (name as a heading, then year), Not this game?, Collection section, Price section (heading, summary group, actions), Facts, Description, Show more, Attribution.
- The cover has the label `common.coverLabel` ("Cover of Catan") or the placeholder label. The placeholder is not decorative: it says there is no image.
- The price card is one grouped node with `price.summaryLabel`: "Median asking price $42.00 on eBay US, used, from 23 listings, low $30.00, high $65.00, updated 5 hours ago." Its buttons are separate.
- Sections are headings so TalkBack and VoiceOver users can jump by heading.
- Stale and few-listings notes are text with icons, not color only.
- Add and move results are announced via snackbar live regions.
- Pull to refresh has an accessible "Refresh" action in the semantics (custom action) for switch and screen reader users.
- Contrast: the median amount uses onSurface; asking and sold badges use different container roles and different words and icons; check both themes.
- Text at 200%: the header stacks; facts become one column; the price card wraps; no truncation of names, amounts, or notes. The median amount (headlineMedium) wraps if needed but never clips.
- Touch targets: all buttons 48 dp.

## 8. Golden cases

M2 goldens (T-034 criterion 14). M3 and M4 goldens are produced by their own tickets (T-038/T-040 and T-061/T-062) from the same list.

| File | Milestone | Notes |
|---|---|---|
| game_detail_loading_light_compact.png | M2 | Skeleton |
| game_detail_loading_dark_compact.png | M2 | |
| game_detail_success_light_compact.png | M2 | Every field, BGG attribution placeholder |
| game_detail_success_dark_compact.png | M2 | |
| game_detail_success_light_medium.png | M2 | |
| game_detail_success_dark_expanded.png | M2 | Two columns |
| game_detail_success_light_landscape.png | M2 | Two columns, phone landscape |
| game_detail_partial_light_compact.png | M2 | No year, image, designers |
| game_detail_partial_dark_compact.png | M2 | |
| game_detail_notfound_light_compact.png | M2 | |
| game_detail_error_light_compact.png | M2 | |
| game_detail_error_dark_expanded.png | M2 | |
| game_detail_offline_light_compact.png | M2 | Cached 3 days ago |
| game_detail_offline_dark_compact.png | M2 | |
| game_detail_frombarcode_light_compact.png | M2 | Not this game? visible |
| game_detail_longtitle_text200_light_compact.png | M2 | 200-character Unicode title |
| game_detail_longtitle_text200_dark_expanded.png | M2 | |
| game_detail_success_text200_dark_compact.png | M2 | |
| game_detail_notincollection_light_compact.png | M3 | Add to collection button |
| game_detail_incollection_owned_dark_compact.png | M3 | |
| game_detail_incollection_wanted_light_expanded.png | M3 | |
| game_detail_price_success_light_compact.png | M4 | Asking price card |
| game_detail_price_success_dark_compact.png | M4 | |
| game_detail_price_success_dark_expanded.png | M4 | |
| game_detail_price_loading_light_compact.png | M4 | |
| game_detail_price_none_light_compact.png | M4 | No current listings |
| game_detail_price_none_dark_compact.png | M4 | |
| game_detail_price_few_light_compact.png | M4 | Few listings note |
| game_detail_price_stale_dark_compact.png | M4 | Stale chip |
| game_detail_price_error_light_compact.png | M4 | |
| game_detail_price_offline_dark_compact.png | M4 | Cached price with age |
| game_detail_price_success_text200_light_compact.png | M4 | |

## 9. What PM and reviewers should check

- Missing fields are hidden, not shown as null or zero.
- Offline with a 3-day-old copy shows data and the label, never an error.
- Attribution placeholder sits at the foot; it must be replaced with the T-002 wording and logo before release.
- Pricing: amount, the word asking, eBay, count, age; "No current listings" with no $0; the disclosure is inline.
- Collection actions are one tap and have Undo, with no confirmation dialogs.
- Open questions: BGG attribution wording and placement (T-002); whether cover images can load directly (PRD Q5); whether to show an "Open on BGG" link at all (depends on BGG terms).
