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
2. Two actions follow: "See eBay listings" and "See price history".

## History

1. User taps "See price history".
2. The chart shows the median asking price per day, with a text summary below. A range selector (30 days, 90 days, 1 year, All) changes the view.
3. "Show as table" gives the same data as rows.
4. A note says when history starts. There is no backfill.

## Collection total

Owned shows an estimated total, labeled as the sum of median eBay asking prices, with how many games have no price data and how old the oldest data is. Each Owned, Wanted, and Evaluating row shows its own asking price with count and age.

## Branches

| Situation | What happens |
|---|---|
| No listings | "No current listings." No $0. |
| Fewer than 3 listings | Numbers shown with a "Few listings" note. |
| Data older than 48 hours | "Out of date" chip and note. |
| Offline | Last saved price with its age and a note; never an error screen. |
| Error, nothing saved | Message in the price card with Retry. The rest of the page works. |
| No history yet | "No history yet. We save one price a day." |
| Days with no listings | Gaps in the line, not zeros. |
| Sold prices (later, behind a flag) | Separate card with the "Sold price" badge. Never merged with asking. |

## Rules

- Every price shows amount, "asking" or "sold", source eBay, sample size, and data age.
- An asking price is never called sold, value, or sale.
- A chart always has a visible text summary and a table alternative.
