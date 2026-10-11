# Flow: Scan to game detail

Tickets: T-030, T-033, T-034, T-035. Stories: US-1, US-5. Screens: scanner, lookup-result, game-detail.

Goal: the user holds a box, points the phone at the barcode, and sees the right game.

## Happy path

1. User opens the app. It lands on Scan (or taps the Scan tab).
2. First time only: the camera explanation shows on the screen and the system permission prompt appears. User allows.
3. Camera starts. The hint says to point at the barcode.
4. A valid UPC-A, EAN-13, or EAN-8 is read. One haptic, a check on the frame, and a spoken "Barcode ... read. Looking up the game."
5. Lookup runs (skeleton on lookup-result). If the device already has a confirmed match for this barcode, it opens at once without a network call.
6. Status `matched`: the lookup screen is replaced by game detail. Back from detail returns to the scanner.

## Branches

| Situation | What happens |
|---|---|
| Permission denied | Scanner shows the explanation and "Allow camera". Manual entry and Search stay visible. |
| Permission permanently denied | Explanation plus "Open settings". Manual entry and Search stay visible. Returning from settings restarts the camera. |
| Camera unavailable | Explanation plus Retry. Manual entry and Search stay visible. |
| QR code, UPC-E, Code 128, or a bad check digit | Ignored. No feedback. |
| Same barcode read repeatedly | One lookup; ignored for 2 s. |
| Several matches or none | See flows/barcode-candidates-and-correction.md. |
| Offline, barcode known | Game opens from the device cache with "Last updated". |
| Offline, barcode not known | Offline message with Retry and Search by title. |
| Backend busy or rate limited | Plain message with Retry and Search by title. |
| User taps Enter barcode or Search by title at any point | See flows/manual-barcode-entry.md and flows/title-search-to-game-detail.md. |

## Rules

- No screen sits between the tab and the camera, except the permission explanation on first use.
- Permission is requested only when Scan is opened, never at launch.
- The camera stops when the user leaves the tab or backgrounds the app.
- The user can always reach manual entry and title search with one tap.
