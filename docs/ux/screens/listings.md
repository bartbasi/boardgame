# Screen spec: Listings

Status: draft for user review (T-003). Ticket: T-062. Flows: flows/view-prices-and-history.md, flows/open-listing-on-ebay.md.

## 1. Purpose and entry points

Show the current eBay US listings behind a game's price, each with a "View on eBay" button. Entry: `price.seeListings` on game detail. Pushed screen with the navigation visible.

Rules on this screen:

- Every price is an asking price and says so.
- "View on eBay" opens the backend-provided URL (the affiliate link when eBay provides one, the plain item URL otherwise) outside the app, in the browser or the eBay app, in one tap. No confirmation dialog, no interstitial, no countdown, no "you are leaving the app" screen.
- The app never builds an affiliate URL and never holds a campaign id.
- The affiliate disclosure is inline text above the first listing.

## 2. Layout

| Size | Layout |
|---|---|
| Compact portrait | App bar with Back and `listings.title`. Summary block: game name, `listings.summary` ("23 current listings on eBay US, updated 5 hours ago"), `listings.subtitle`. Then the AffiliateDisclosure (placeholder). Then a sort control (`listings.sortLow` default). Then ListingRows. |
| Phone landscape | Summary and disclosure in a left column (40%, pinned); rows in the right column. |
| Medium | One column, 640 dp, centered. |
| Expanded | Two columns: left summary, disclosure, and sort (320 dp); right list of rows (up to 720 dp). Rows have the button on the trailing side. |

ListingRow layout (compact): thumbnail (72 dp, left), title (up to 3 lines at 100%), price line "$42.00 asking" (titleMedium), condition, shipping note (`listings.rowShippingNote`), then the "View on eBay" button on its own line (full width of the text column, 48 dp). At medium and expanded the button sits to the right of the text.

## 3. Components

ListingRow, AffiliateDisclosure, PriceBadge, DataAgeLabel, StaleChip, FewListingsNote, SkeletonRow, EmptyState, ErrorState, OfflineBanner, Snackbar. See docs/ux/components.md.

## 4. States

| State | What the user sees |
|---|---|
| Loading | Summary skeleton and 5 ListingRow skeletons. The disclosure shows immediately (it is static text). |
| Success | Summary (count, source, age), PriceBadge `price.badgeAsking`, disclosure, sort control, rows. |
| Few listings (under 3) | `listings.fewNote` under the summary. |
| Empty (no listings) | EmptyState: `listings.emptyTitle` ("No current listings"), `listings.emptyBody`. No $0. The disclosure is hidden because there are no links. |
| Error, no cache | ErrorState `listings.errorTitle`, plain body, Retry. |
| Offline with cache | OfflineBanner and `listings.offlineBody` ("You are offline. Showing listings saved 5 hours ago. They may have ended."). Rows and buttons still work; the button opens the saved link (the browser reports a failure if there is no connection). |
| Stale (over 48 hours) | StaleChip and `listings.staleNote`. |
| Partial data | A listing with no photo shows the placeholder (`listings.thumbPlaceholder`); no condition hides that line; no end date hides that line. Listings with no usable link are not shown. |
| Opening | The button opens eBay immediately. If the system cannot open it, a snackbar `listings.openFailed` appears. |
| Refresh | Pull to refresh; failure shows `common.refreshFailed` with cached rows kept. |

## 5. Interactions and navigation

- `listings.viewOnEbay` opens the listing outside the app. Back from eBay returns to the same scroll position.
- Row (outside the button) does nothing [ASSUMPTION; see components.md ListingRow]. This avoids accidental opens while scrolling.
- Sort menu: price low to high (default), price high to low. Sorting applies to the already loaded rows.
- Back returns to game detail.

## 6. Copy

`listings.*` (title, subtitle, summary, disclosure placeholder, row strings, viewOnEbay, viewOnEbayLabel, sort strings, empty, error, offline, staleNote, openFailed, thumb strings, fewNote), `price.badgeAsking`, `price.updated`, `price.stale`, `common.refreshFailed`, `common.retry`.

## 7. Accessibility

- Focus order: Back, summary, disclosure, sort, then each row's button in list order. Row text is read before each button.
- Each row group reads `listings.rowLabel` ("Catan 5th edition. Asking price $42.00. Very good. Opens on eBay."). The button reads `listings.viewOnEbayLabel` and states it opens outside the app.
- The disclosure is read right after the summary, before the list.
- Thumbnails: `listings.thumbLabel` or decorative when the row label already names the item.
- Text at 200%: titles show fully; the button spans the width; price and condition wrap.
- Contrast: asking badge and price text 4.5:1; external-link icon has text next to it.
- Targets: button 48 dp tall, minimum 120 dp wide.

## 8. Golden cases

| File | Notes |
|---|---|
| listings_loading_light_compact.png | |
| listings_loading_dark_compact.png | |
| listings_success_light_compact.png | 5 rows, disclosure placeholder visible |
| listings_success_dark_compact.png | |
| listings_success_light_medium.png | |
| listings_success_dark_expanded.png | Two columns |
| listings_success_light_landscape.png | |
| listings_partial_light_compact.png | Missing photo, condition, end date |
| listings_few_light_compact.png | Few listings note |
| listings_empty_light_compact.png | No current listings, no $0 |
| listings_empty_dark_compact.png | |
| listings_error_light_compact.png | |
| listings_offline_dark_compact.png | Saved listings with age |
| listings_stale_light_compact.png | Stale chip |
| listings_success_text200_light_compact.png | |
| listings_success_text200_dark_expanded.png | |

## 9. What PM and reviewers should check

- Every price is followed by "asking"; no "sold", "value", or "sale".
- Count, source (eBay US), and age are in the summary.
- "No current listings" never shows $0.
- The disclosure is visible text above the first listing, placeholder marked.
- "View on eBay" opens in one tap with no step before it (check the widget test taps once and expects the launcher call).
- Open questions: the exact disclosure wording (T-050); the eBay attribution or logo rules for showing listings (T-002); whether showing listing photos is allowed directly from eBay's hosts (PRD Q5); whether the whole row should be tappable.
