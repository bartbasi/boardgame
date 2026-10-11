# Screen spec: Manual barcode entry

Status: draft for user review (T-003). Ticket: T-031. Flow: flows/manual-barcode-entry.md.

## 1. Purpose and entry points

Let the user type a barcode when the camera cannot read it or is not allowed. Entry: `scanner.actionManual` on the scanner, "Enter barcode" on Search and on empty states, "Enter a different barcode" on lookup-result. The screen makes no network call. It is a pushed screen (not a tab), with the navigation visible.

## 2. Layout

ContentColumn, max 600 dp, centered on medium and expanded.

| Size | Layout |
|---|---|
| Compact portrait | App bar with Back and `manualEntry.title`. Below: BarcodeField (full width), helper or error text, digit counter on the right, then the primary button `manualEntry.submit` (full width, 48 dp, FilledButton). Below the button, two TextButtons: `manualEntry.scanInstead` and `manualEntry.searchInstead`. Keyboard is open on arrival with the numeric keypad. |
| Phone landscape | Field and buttons in one column at the left 55%; the right side is empty space so the keyboard does not hide the submit button. The page scrolls so the focused field and the button stay visible above the keyboard. |
| Medium | Same as compact, in the 600 dp column. |
| Expanded | Same, column centered. |

On a small keyboard-open screen, the submit button sits above the keyboard (the content scrolls; the button is also the keyboard's "Search" action).

## 3. Components

BarcodeField, ScanActionBar-style text actions, AdaptiveScaffold. See docs/ux/components.md.

## 4. States

| State | What the user sees |
|---|---|
| Initial (empty) | Field focused, helper `manualEntry.helper`, counter "0 of 13 digits". Submit is enabled (so an empty submit gives a clear error, not a dead button). |
| Typing | Digits only. Other characters (letters, spaces, dashes, including in pasted text) are dropped as they are typed or pasted, and input stops at 13 digits. Counter updates. `manualEntry.errorNonDigit` is a fallback for the rare case a non-digit still reaches validation. |
| Error: empty | `manualEntry.errorEmpty` under the field, error icon, field outline in error role. |
| Error: wrong length | `manualEntry.errorLength` (digits typed other than 8, 12, 13). |
| Error: non-digit | `manualEntry.errorNonDigit`. |
| Error: bad check digit | `manualEntry.errorCheckDigit`. |
| Valid, submitting | The app navigates to lookup-result at once. No spinner here. |
| Offline | No banner. Submitting a valid code still opens lookup-result, which handles being offline. |
| Loading / success / partial / cached | Not applicable on this screen. |

The error appears only after submit, not while typing (so a half-typed number is not flagged). The error clears when the user edits the field. Focus stays in the field after an error.

## 5. Interactions and navigation

- Submit (button or keyboard action): validates in the field order above. Valid: push lookup-result. Invalid: show the error, keep focus, announce it.
- Valid codes include 8-digit (EAN-8), 12-digit (UPC-A), and 13-digit (EAN-13) numbers with a correct check digit. Spaces around the number are trimmed.
- `manualEntry.scanInstead`: pop back to the scanner. `manualEntry.searchInstead`: switch to Search.
- Back: returns to the previous screen; the typed text is not kept.
- Clear button inside the field when it has text.

## 6. Copy

`manualEntry.title`, `manualEntry.fieldLabel`, `manualEntry.helper`, `manualEntry.submit`, `manualEntry.errorLength`, `manualEntry.errorNonDigit`, `manualEntry.errorCheckDigit`, `manualEntry.errorEmpty`, `manualEntry.errorAnnouncement`, `manualEntry.searchInstead`, `manualEntry.scanInstead`, `manualEntry.digitCounter`.

## 7. Accessibility

- Focus order: Back, field, clear button, submit, scan instead, search instead.
- The field has the visible label `manualEntry.fieldLabel` and the helper as its hint. On error the message is read as part of the field and announced immediately (assertive) using `manualEntry.errorAnnouncement`.
- Error is shown with an icon and text, not color alone.
- Counter is read as "N of 13 digits".
- Targets: all at least 48 dp.
- Text at 200%: label, helper, and error wrap; the page scrolls; the submit button is never covered by the keyboard (the page scrolls it into view).
- The numeric keyboard shows on both platforms; no spaces or separators are required.

## 8. Golden cases

| File | Notes |
|---|---|
| manual_entry_initial_light_compact.png | Helper, counter 0 of 13, keyboard not drawn |
| manual_entry_initial_dark_compact.png | |
| manual_entry_initial_light_expanded.png | Centered column |
| manual_entry_error_checkdigit_light_compact.png | Error text and icon |
| manual_entry_error_checkdigit_dark_compact.png | |
| manual_entry_error_length_light_compact.png | |
| manual_entry_error_empty_dark_expanded.png | |
| manual_entry_initial_text200_light_compact.png | Wrapped helper |
| manual_entry_error_checkdigit_text200_dark_compact.png | |
| manual_entry_initial_light_medium.png | |

## 9. What PM and reviewers should check

- Digits only, max 13, numeric keyboard.
- `036000291453` and `12345` give plain errors with focus kept and announced.
- No network indicator on this screen.
- Scan and search alternatives are on the screen.
- Open question: should 14-digit GTIN-14 codes be accepted? The spec says no (T-026 says a 14-digit string is invalid).
