# Flow: Barcode with zero or several matches, candidates, and correction

Tickets: T-025 (server), T-033, T-034, T-029. Stories: US-4. Screens: lookup-result, search, game-detail.

Goal: when the barcode does not give one clear game, the user picks the right one, and the app remembers.

## A. Several matches (candidates)

1. A scan or manual entry returns status `candidates`.
2. Lookup-result shows "Which game is this?" with up to 10 rows (thumbnail, name, year).
3. User taps the right game. The app stores the barcode as a confirmed match (on the device only) and opens its detail. A snackbar says the match was saved.
4. Next time the same barcode is read, the game opens at once, offline too.

Also available on this screen: "Search by title" and "Enter a different barcode".

## B. No match

1. Status `none`: "No game found for this barcode".
2. User taps "Search by title". Search opens with a banner naming the barcode.
3. User searches and taps a result. The app stores the barcode against that game and opens its detail.
4. Other actions: "Enter a different barcode", "Scan again".

## C. Lookup unavailable

1. Status `unavailable`: "Barcode lookup is not available right now."
2. Actions: Search by title (same as B), Retry, Enter a different barcode.
3. Nothing is stored as a match unless the user picks one.

## D. Correction ("Not this game?")

1. The user opened a game from a barcode scan and sees it is wrong.
2. User taps "Not this game?" on game detail.
3. Lookup-result opens in correction mode: "Pick the right game", with the current match marked.
4. User picks another candidate, or searches by title and picks a result.
5. The new choice replaces the stored match for that barcode. Game detail for the new game replaces the screen.
6. If the user picks the current match, nothing changes and the screen closes.

## Branches

| Situation | What happens |
|---|---|
| Offline in correction mode | Shows the current match and "Search by title" (search needs a connection; the offline message appears there). |
| Candidate lacks year or thumbnail | Name only; placeholder. |
| Backend busy | Plain message with Retry and Search by title. |

## Rules

- The match is stored on the device only (PRD Q9 may change this).
- A single backend match counts as confirmed until the user corrects it.
- "Not this game?" shows only when the detail was opened from a barcode.
