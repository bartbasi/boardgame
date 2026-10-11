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
| Partial data | Any missing field is hidden: no year, no players, no play time, no designers, no publishers, no image (placeholder cover with label `common.coverPlaceholderLabel`, or no cover at all in no-image mode), no description (`gameDetail.descriptionEmpty`). Never "null", "0", "unknown", or an empty label. If the whole Facts group is empty, the section header is hidden too. |
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
| Success (price age 6 hours or less) | PriceBadge `price.badgeAsking`; section title `price.sectionTitle`; median `price.median` with the amount (headlineMedium); range `price.range`; sample `price.sample`; source `price.source`; age `price.updated`; then the AffiliateDisclosure (`common.disclosureShort`, placeholder) directly above the actions `price.seeListings` and `price.seeHistory`. The disclosure is next to the eBay listings button, the only route from this screen to eBay links. |
| Few listings (under 3 [ASSUMPTION]) | Same numbers plus the FewListingsNote `price.fewNote`. |
| No listings | `price.noneTitle` ("No current listings") and `price.noneBody`. No amount, no "$0". Source line stays. No listings button and no disclosure (there are no links). |
| Stale (older than 6 hours, up to 24 hours [ASSUMPTION], EBAY-20) | Numbers stay. StaleChip `price.stale` and `price.staleNote` next to the age label. |
| Price too old (older than 24 hours [ASSUMPTION, Q24]) | No numbers. `price.tooOldTitle` and `price.tooOldBody`, Retry when online. Source line stays. Never a $0 or the old amount. |
| Offline with cache | Only if the saved price is 24 hours old or less: numbers with `price.offlineNote`, the age, and the stale chip after 6 hours. Older than 24 hours: the "Price too old" state. Listings are never shown offline (they need a connection, see listings.md). |
| Error, no cache | Inline ErrorState in the card: `price.errorTitle`, Retry. The rest of the page stays. |
| History action | `price.seeHistory` is shown only when the history feature is on and the game has a history start date. When the feature is off, the button is absent (not disabled). |

v1 shows asking prices only (EBAY-100). There is no sold-price state, card, copy, or golden.

Wording rules: the amount is always followed by or next to the word "asking". The words "sold", "value", and "sale" never appear next to an asking price. The only place "estimated" appears is the collection total.

## 5. Interactions and navigation

- Back returns to the origin. In a TwoPane, there is no Back; selecting another row replaces the right pane.
- NotThisGameAction opens lookup-result in correction mode.
- Description Show more and Show less toggle in place.
- `price.seeListings` pushes listings. `price.seeHistory` pushes price-history. Both pass the bggId.
- The BGG logo and credit (BGG-40, BGG-41) sit at the foot of the content; the logo link opens BoardGameGeek outside the app.
- Pull to refresh refreshes game info and, in M4, price data together.
- Share is not in v1.
- No dialogs. Snackbars never block.

## 6. Copy

M2: `gameDetail.*` (title, notThisGame, notThisGameLabel, players, playersValue, playersValueSingle, playTime, playTimeValue, playTimeValueSingle, designers, publishers, year, description, descriptionEmpty, notFoundTitle, notFoundBody, notFoundAction, errorTitle, updatedLabel, dataFromBgg), `common.*` (coverLabel, coverPlaceholderLabel, showMore, showLess, lastUpdated, offlineBanner, offlineNoData, refreshFailed, retry, error strings, bggCredit, bggLogoLabel).
M3: `gameDetail.inCollection`, `gameDetail.collectionSection`, `addToCollection.*`.
M4: `price.*`, `common.disclosureShort` (placeholder).

## 7. Accessibility

- Focus order: Back, header (name as a heading, then year), Not this game?, Collection section, Price section (heading, summary group, actions), Facts, Description, Show more, Attribution.
- The cover has the label `common.coverLabel` ("Cover of Catan") or the placeholder label. The placeholder is not decorative: it says there is no image.
- The price card is one grouped node with `price.summaryLabel`: "Median asking price $42.00 on eBay US, used, from 23 listings, low $30.00, high $65.00, updated 5 hours ago." Its buttons are separate.
- Sections are headings so TalkBack and VoiceOver users can jump by heading.
- Stale and few-listings notes are text with icons, not color only.
- Add and move results are announced via snackbar live regions.
- Pull to refresh has an accessible "Refresh" action in the semantics (custom action) for switch and screen reader users.
- Contrast: the median amount uses onSurface; the asking badge uses secondaryContainer with a word and an icon; the disclosure uses onSurface at 4.5:1; check both themes.
- No cover images: the screen works with no image at all (BGG-42). In no-image mode the header is text only, and no cover label is announced.
- The BGG logo has the label `common.bggLogoLabel` and is a link.
- Text at 200%: the header stacks; facts become one column; the price card wraps; no truncation of names, amounts, or notes. The median amount (headlineMedium) wraps if needed but never clips.
- Touch targets: all buttons 48 dp.

## 8. Golden cases
Total: 19 (M2: 8, M3: 3, M4: 8). Each ticket delivers its milestone's rows. Not found and error use the shared EmptyState and ErrorState layouts and are covered by widget tests, as are offline price, few listings, and price error. `game_detail_success_light_compact.png` is rendered as if opened from a barcode, so "Not this game?" is visible. The BGG credit and logo sit at the foot and are visible in the success goldens (the golden surface is tall enough to include the foot).

| File | Milestone | Notes |
|---|---|---|
| game_detail_loading_light_compact.png | M2 | Skeleton |
| game_detail_success_light_compact.png | M2 | Every field, opened from a barcode, BGG credit |
| game_detail_success_dark_compact.png | M2 | |
| game_detail_success_dark_expanded.png | M2 | Two columns |
| game_detail_partial_light_compact.png | M2 | No year, designers, or description |
| game_detail_noimages_light_compact.png | M2 | No-image mode (BGG-42) |
| game_detail_offline_dark_compact.png | M2 | Cached 3 days ago, Last updated label |
| game_detail_longtitle_text200_light_compact.png | M2 | 200-character Unicode title |
| game_detail_notincollection_light_compact.png | M3 | Add to collection button |
| game_detail_incollection_owned_dark_compact.png | M3 | |
| game_detail_incollection_wanted_light_expanded.png | M3 | |
| game_detail_price_success_light_compact.png | M4 | Asking price card, disclosure above the buttons |
| game_detail_price_success_dark_compact.png | M4 | |
| game_detail_price_loading_light_compact.png | M4 | |
| game_detail_price_none_light_compact.png | M4 | No current listings, no $0 |
| game_detail_price_stale_dark_compact.png | M4 | Stale chip (older than 6 hours) |
| game_detail_price_toold_light_compact.png | M4 | Older than 24 hours: no numbers |
| game_detail_price_success_dark_expanded.png | M4 | |
| game_detail_price_success_text200_light_compact.png | M4 | |

## 9. What PM and reviewers should check

- Missing fields are hidden, not shown as null or zero.
- Offline with a 3-day-old copy shows data and the label, never an error.
- BGG credit by name and the Powered by BGG logo sit at the foot (the logo asset comes from T-087).
- Prices go stale after 6 hours and disappear after 24; no sold state exists in v1.
- The disclosure is next to the "See eBay listings" button.
- Pricing: amount, the word asking, eBay, count, age; "No current listings" with no $0; the disclosure is inline.
- Collection actions are one tap and have Undo, with no confirmation dialogs.
- Open questions: whether cover images may be shown at all (PRD Q5, BGG-42); the final disclosure wording (Q25); the 6 and 24 hour price limits (Q24, Q18).
