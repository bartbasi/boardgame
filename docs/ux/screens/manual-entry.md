# Screen spec: Manual barcode entry

Status: draft for user review (T-003). Ticket: T-031. Flow: flows/manual-barcode-entry.md.

## 1. Purpose and entry points

Let the user type a barcode when the camera cannot read it or is not allowed. Entry: `scanner.actionManual` on the scanner, "Enter barcode" on Search and on empty states, "Enter a different barcode" on lookup-result. The screen makes no network call. It is a pushed screen (not a tab), with the navigation visible.

## 2. Layout

ContentColumn, max 600 dp, centered on medium and expanded.

| Size | Layout |
|---|---|
| Compact portrait | App bar with Back and `manualEntry.title`. Below: BarcodeField (full width), the helper or error text at the full field width, the digit counter on its own line below that (right-aligned), then the primary button `manualEntry.submit` (full width, 48 dp, FilledButton). Below the button, two TextButtons: `manualEntry.scanInstead` and `manualEntry.searchInstead`. Keyboard is open on arrival with the numeric keypad. |
| Phone landscape | Field and buttons in one column at the left 55%; the right side is empty space so the keyboard does not hide the submit button. The page scrolls so the focused field and the button stay visible above the keyboard. |
| Medium | Same as compact, in the 600 dp column. |
| Expanded | Same, column centered. |

On a small keyboard-open screen, the submit button sits above the keyboard (the content scrolls). On Android the button is also the keyboard's "Search" action. The iOS number pad has no Search or Done key, so on iOS Look up is the only way to submit.

Phone landscape with the keyboard open (T-031 UX check, accepted): the field and Look up do not both fit above the keyboard (about 178 dp visible). The user scrolls to the button; Android users can also use the keyboard action. Do not move the button beside the field for v1. T-103 may revisit this after an on-device check.

The helper and the error text never share a line with the counter. They get the full field width at every text size, and the counter sits below them. Helper and error swap in place (no fade or slide).

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
- Clear button inside the field when it has text. Its label reuses `itemEdit.clearField` with the field name `manualEntry.fieldLabel` ("Clear Barcode number"). Reuse is confirmed; no separate key.

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
Total: 6. Other error messages differ only in text and are covered by widget tests.

| File | Notes |
|---|---|
| manual_entry_initial_light_compact.png | Helper, counter 0 of 13 on its own right-aligned line, keyboard not drawn. The NavigationBar shows because the golden has focus but no keyboard (app-shell.md section 2) |
| manual_entry_initial_dark_compact.png | |
| manual_entry_initial_light_expanded.png | Centered column |
| manual_entry_error_checkdigit_light_compact.png | Error text and icon at full width (two lines), counter below |
| manual_entry_error_checkdigit_dark_compact.png | Error container roles |
| manual_entry_initial_text200_light_compact.png | Wrapped helper |

## 9. What PM and reviewers should check

- Digits only, max 13, numeric keyboard.
- `036000291453` and `12345` give plain errors with focus kept and announced.
- No network indicator on this screen.
- Scan and search alternatives are on the screen.
- Phone landscape with the keyboard open scrolls to the button (accepted, see section 2).
- Open question: should 14-digit GTIN-14 codes be accepted? The spec says no (T-026 says a 14-digit string is invalid).
