# Flow: View prices and history

Tickets: T-055, T-058, T-060, T-061, T-063, T-064. Stories: US-11, US-12, US-14. Screens: game-detail, listings, price-history, collection.

Goal: the user sees what a game goes for used on eBay US, how reliable that is, and how it has moved.

## Price on game detail

1. User opens a game. The Price section shows a skeleton, then:
   - the "Asking price" badge,
   - the median asking price,
   - low and high,
   - "From 23 listings",
   - "Source: eBay US, used, item price only",
   - "Updated 5 hours ago".
2. The disclosure ("Paid link ..." placeholder) sits right above two actions: "See eBay listings" and, only if history is available, "See price history".

## History

1. User taps "See price history".
2. The chart shows the median asking price per day, with a text summary below. A range selector (30 days, 90 days, 1 year, All) changes the view.
3. "Show as table" gives the same data as rows.
4. A note says when history starts. There is no backfill.

## Collection total

Owned shows an estimated total, labeled as the sum of median eBay asking prices, with how many games have no current price data (older than 24 hours counts as none) and how old the oldest data is. Each Owned, Wanted, and Evaluating row shows its own asking price with count and age.

## Branches

| Situation | What happens |
|---|---|
| No listings | "No current listings." No $0. |
| Fewer than 3 listings | Numbers shown with a "Few listings" note. |
| Price older than 6 hours | Numbers stay with an "Out of date" chip and note. |
| Price older than 24 hours | No numbers: "Price not available. The last price we saved is too old to show." Collection rows read "No current price data" and the total leaves the game out. |
| Offline | A price saved within 24 hours shows with its age and a note; older than that it is the "Price not available" state. Listings need a connection and are not shown offline. |
| History turned off | The "See price history" action is absent. If the screen is reached anyway: "Price history is not available." |
| Error, nothing saved | Message in the price card with Retry. The rest of the page works. |
| No history yet | "No history yet. We save one price a day." |
| Days with no listings | Gaps in the line, not zeros. |

## Rules

- Every price shows amount, "asking", source eBay, sample size, and data age. v1 has no sold prices.
- An asking price is never called sold, value, or sale.
- A chart always has a visible text summary and a table alternative.
