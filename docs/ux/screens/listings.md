# Screen spec: Listings

Status: draft for user review (T-003). Ticket: T-062. Flows: flows/view-prices-and-history.md, flows/open-listing-on-ebay.md.

## 1. Purpose and entry points

Show the current eBay US listings behind a game's price, each with a "View on eBay" button. Entry: `price.seeListings` on game detail. Pushed screen with the navigation visible.

Rules on this screen:

- Every price is an asking price and says so.
- "View on eBay" opens the backend-provided URL (the affiliate link when eBay provides one, the plain item URL otherwise) outside the app, in the browser or the eBay app, in one tap. No confirmation dialog, no interstitial, no countdown, no "you are leaving the app" screen.
- The app never builds an affiliate URL and never holds a campaign id.
- The disclosure (`listings.disclosure`, placeholder wording pending Q25 and T-050, using an EPN-approved phrase such as "Paid link", never "affiliate link") is inline text that is visible without scrolling at every size, including phone landscape and text at 200% (EBAY-92, EBAY-93). It is pinned in the top region of the screen, not in the scrolling list.
- Listings are never shown older than 6 hours (EBAY-20), including offline. Each row shows its own age.

## 2. Layout

| Size | Layout |
|---|---|
| Compact portrait | App bar with Back and `listings.title`. A pinned header (stays on screen while rows scroll): the AffiliateDisclosure first (placeholder), then the one-line summary `listings.summary` ("23 current listings on eBay US, updated 5 hours ago"). Below the pinned header, scrolling: the `listings.subtitle` line, a sort control (`listings.sortLow` default), then ListingRows, then the compact BggAttribution at the foot. At text 200% the pinned header is allowed to take up to 40% of the screen height; the summary line moves out of the pinned header into the scrolling area first, so the disclosure always stays on screen. |
| Phone landscape | Left column (40%, pinned and independently scrollable only if it overflows): disclosure first, then summary and sort. Right column (60%): rows. At text 200% the left column scrolls, but the disclosure is its first element, so it is on screen without scrolling. |
| Medium | One column, 640 dp, centered, with the same pinned header. |
| Expanded | Two columns: left summary, disclosure (first), and sort (320 dp); right list of rows (up to 720 dp). Rows have the button on the trailing side. |

ListingRow layout (compact): thumbnail (72 dp, left, omitted in no-image mode), title (up to 3 lines at 100%), price line "$42.00 asking" (titleMedium), condition, shipping note (`listings.rowShippingNote`), the row's own age `listings.rowAge` ("Checked 2 hours ago"), then the "View on eBay" button on its own line (full width of the text column, 48 dp). At medium and expanded the button sits to the right of the text.

## 3. Components

ListingRow, AffiliateDisclosure, BggAttribution (compact), PriceBadge, DataAgeLabel, FewListingsNote, SkeletonRow, EmptyState, ErrorState, OfflineBanner, Snackbar. See docs/ux/components.md.

## 4. States

| State | What the user sees |
|---|---|
| Loading | Summary skeleton and 5 ListingRow skeletons. The disclosure shows immediately (it is static text). |
| Success | Summary (count, source, age), PriceBadge `price.badgeAsking`, disclosure, sort control, rows. |
| Few listings (under 3) | `listings.fewNote` under the summary. |
| Empty (no listings) | EmptyState: `listings.emptyTitle` ("No current listings"), `listings.emptyBody`. No $0. The disclosure is hidden because there are no links. |
| Error, no cache | ErrorState `listings.errorTitle`, plain body, Retry. |
| Offline | OfflineBanner and an EmptyState-style message: `listings.offlineTitle`, `listings.offlineBody` ("Listings and prices need a connection."), Retry. No rows are shown, even if some were saved, because listings may not be shown older than 6 hours (EBAY-20). No disclosure is shown because there are no links. |
| Data older than 6 hours | Not possible on this screen. Rows older than 6 hours are never rendered; if a refresh fails after that time, the screen is in the Error or Offline state. There is no stale state. |
| Partial data | A listing with no photo shows the placeholder (`listings.thumbPlaceholder`) or nothing in no-image mode; no condition hides that line. Every row keeps its age. Listings with no usable link are not shown. |
| Opening | The button opens eBay immediately. If the system cannot open it, a snackbar `listings.openFailed` appears. |
| Refresh | Pull to refresh; failure shows `common.refreshFailed` with cached rows kept. |

## 5. Interactions and navigation

- `listings.viewOnEbay` opens the listing outside the app. Back from eBay returns to the same scroll position.
- Row (outside the button) does nothing [ASSUMPTION; see components.md ListingRow]. This avoids accidental opens while scrolling.
- Sort menu: price low to high (default), price high to low. Sorting applies to the already loaded rows.
- Back returns to game detail.

## 6. Copy

`listings.*` (title, subtitle, summary, disclosure placeholder, row strings, viewOnEbay, viewOnEbayLabel, rowAge, sort strings, empty, error, offlineTitle, offlineBody, openFailed, thumb strings, fewNote), `common.bggCredit`, `common.bggLogoLabel`, `price.badgeAsking`, `price.updated`, `common.refreshFailed`, `common.retry`.

## 7. Accessibility

- Focus order: Back, summary, disclosure, sort, then each row's button in list order. Row text is read before each button.
- Each row group reads `listings.rowLabel` ("Catan 5th edition. Asking price $42.00. Very good. Checked 2 hours ago. Opens on eBay."). The button reads `listings.viewOnEbayLabel` and states it opens outside the app.
- The disclosure is read right after the summary, before the list.
- Thumbnails: `listings.thumbLabel` or decorative when the row label already names the item.
- Text at 200%: titles show fully; the button spans the width; price and condition wrap.
- Contrast: asking badge and price text 4.5:1; external-link icon has text next to it.
- Targets: button 48 dp tall, minimum 120 dp wide.

## 8. Golden cases
Total: 8. The disclosure must be visible without scrolling in every success golden, including landscape and text200. Few listings, error, partial rows (missing photo or condition), and no-image mode are covered by widget tests.

| File | Notes |
|---|---|
| listings_loading_light_compact.png | Disclosure shown above skeleton rows |
| listings_success_light_compact.png | 5 rows with ages, disclosure placeholder pinned at top, BGG credit at the foot |
| listings_success_dark_expanded.png | Two columns, disclosure in the left column |
| listings_success_light_landscape.png | Disclosure in the left column, on screen without scrolling |
| listings_success_text200_light_compact.png | Disclosure still on screen without scrolling |
| listings_success_text200_dark_landscape.png | Worst case: disclosure on screen at 200% text in landscape |
| listings_empty_light_compact.png | No current listings, no $0 |
| listings_offline_dark_compact.png | "Listings and prices need a connection" |

## 9. What PM and reviewers should check

- Every price is followed by "asking"; no "sold", "value", or "sale".
- Count, source (eBay US), and age are in the summary.
- "No current listings" never shows $0.
- The disclosure is visible text above the first listing, placeholder marked.
- "View on eBay" opens in one tap with no step before it (check the widget test taps once and expects the launcher call).
- The disclosure is on screen without scrolling in every success golden, including landscape and text200, and its wording has no "affiliate link".
- Each row shows its age, and nothing older than 6 hours is shown.
- Open questions: the exact disclosure wording (Q25, T-050); eBay attribution rules for showing listings (T-091); whether showing listing photos is allowed directly from eBay's hosts (PRD Q5); whether the whole row should be tappable.
