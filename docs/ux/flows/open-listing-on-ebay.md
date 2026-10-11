# Flow: Open a listing on eBay

Tickets: T-062, T-050, T-065. Stories: US-13. Screens: game-detail, listings, settings.

Goal: the user opens an eBay listing in one tap.

## Happy path

1. On game detail, the user taps "See eBay listings".
2. The listings screen shows the summary, a short disclosure (inline text pinned at the top, always visible without scrolling, placeholder wording such as "Paid link" until Q25 and T-050), and the rows.
3. User taps "View on eBay" on a row.
4. The listing opens at once in the browser or the eBay app. No confirmation, no interstitial, no countdown.
5. User comes back with the system Back or by switching apps. The list is where they left it.

## Branches

| Situation | What happens |
|---|---|
| The link cannot be opened | Snackbar "Could not open eBay. Try again." |
| Offline | "Listings and prices need a connection." No rows are shown, because listings may not be shown older than 6 hours. |
| Listing has no usable link | Row is not shown. |
| No listings | "No current listings." No buttons. |

## Rules

- The URL comes from the backend (affiliate URL when eBay provides one, plain item URL otherwise). The app never builds or edits it.
- The disclosure is inline text next to the listings, visible without scrolling, and in full in Settings. It is never a modal and never needs acknowledgment.
- Nothing is placed between the tap and eBay.
