# Flow: Title search to game detail

Tickets: T-032, T-034. Stories: US-3. Screens: search, game-detail.

Goal: the user finds a game by typing part of its title.

## Happy path

1. User taps the Search tab (or "Search by title" from the scanner or any empty state).
2. The field is ready. User types "catan".
3. After a 400 ms pause (or the keyboard search key), skeleton rows show, then results with thumbnail, name, and year.
4. User taps a row. Game detail opens (on tablets, the detail shows in the right pane).
5. Back returns to the same results and scroll position.

## Branches

| Situation | What happens |
|---|---|
| Only one character typed | Hint "Type at least 2 letters." No request. |
| No results | "No games found", suggestion to check the spelling, and an "Enter barcode" action. |
| Typed quickly (cat, then catan) | Only the latest query's results show. |
| Service unavailable, rate limited, timeout | Plain message and Retry for the same query. |
| Offline | "You are offline" message with Retry. Search is not cached. |
| Arrived from a barcode with no match | A banner names the barcode. Tapping a result saves it as the match for that barcode, then opens the detail. |
| Row lacks year or thumbnail | Name only; placeholder image. |

## Rules

- Search never needs an account or any prompt.
- Results are in the backend's order, with exact name matches first.
- Screen readers hear the result count and each row as "name, year".
