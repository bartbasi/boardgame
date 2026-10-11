# Flow: Edit an item

Tickets: T-040, T-041, T-042. Stories: US-7, US-8. Screens: collection, game-detail, collection-item-edit.

Goal: record condition, purchase price and date, edition, expansions, notes, photos (Owned); target price and priority (Wanted); notes and date added (Evaluating).

## Happy path

1. User opens a game in the collection and taps Edit (or "Add details" from the add snackbar, or Edit in the row menu).
2. The edit screen shows the fields for the item's list.
3. User changes a field. It saves when they move to another field or leave. "Saved" appears quietly.
4. User taps Back. Everything is already stored.

## Branches

| Situation | What happens |
|---|---|
| Invalid price (not a number) | Error under the field. The last valid value stays stored. |
| Date in the future (purchase date) | Error. Last valid value stays. |
| Add a photo | Choose Take photo or Choose from library. If permission is denied, a message with "Open settings" appears. The rest of the form still works. |
| Remove a photo | Removed at once; Undo in the snackbar. |
| Remove the item | "Remove from collection" removes at once and goes back; Undo in the snackbar. |
| Save fails | Message under the app bar. Fields stay editable. |
| Item disappears (for example after Undo of an add) | "This item is no longer in your collection." with Back. |

## Rules

- No Save button, no discard prompt, no "unsaved changes" dialog.
- Photos stay on the device.
- All fields except the list are optional.
