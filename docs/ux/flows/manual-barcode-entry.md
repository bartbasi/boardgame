# Flow: Manual barcode entry

Tickets: T-031, T-033. Stories: US-2. Screens: manual-entry, lookup-result, game-detail.

Goal: the user types the number under the barcode when scanning is not possible.

## Happy path

1. From the scanner, Search, or lookup-result, the user taps "Enter barcode".
2. Manual entry opens with the numeric keyboard.
3. User types `036000291452` (digits only, up to 13) and presses Look up (or the keyboard action).
4. The app validates the length and check digit on the device and opens lookup-result.
5. From here the flow is the same as scanning (flows/scan-to-game-detail.md, step 5).

## Branches

| Situation | What happens |
|---|---|
| Empty submit | Error "Enter the barcode number." Focus stays. |
| Wrong length (for example 5 digits) | Error says a barcode has 8, 12, or 13 digits and how many were entered. Focus stays. |
| Bad check digit (`036000291453`) | Error says the number does not look right and to check the digits against the box. Focus stays. |
| Letters or symbols | Dropped as typed. |
| Offline | Valid code still opens lookup-result, which shows the stored match or the offline message. |
| User prefers another route | "Scan instead" returns to the scanner; "Search by title instead" opens Search. |

## Rules

- Validation is local. No network call on this screen.
- Errors are announced to screen readers and shown with an icon and text.
- A 12-digit UPC-A and its 13-digit EAN form (leading zero) are the same barcode.
