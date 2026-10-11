# Flow: Move between lists

Tickets: T-038, T-039. Stories: US-6. Screens: collection, game-detail, add-to-collection, collection-item-edit.

Goal: change a game from one list to another, for example Wanted to Owned after buying it.

## Happy path

1. From a Collection row's menu, or from the collection section on game detail, or from the edit screen, the user taps "Move to another list".
2. The sheet shows the three lists; the current one is marked and disabled.
3. User taps the new list. The game moves at once.
4. Snackbar: "Moved to Owned." with Undo.
5. The row leaves the old tab. The new list's fields show on the edit screen.

## Branches

| Situation | What happens |
|---|---|
| Fields that do not apply to the new list | Kept but hidden. Moving back or tapping Undo restores them. |
| Shared fields (notes, date added) | Carried over. |
| Moving Wanted to Owned | Target price and priority are hidden; the user can fill in condition and purchase price from "Add details" in the snackbar. |
| Save fails | Message in the sheet. |
| Offline | Works. |

## Rules

- No confirmation dialog. Undo only.
- Works from the Collection row menu and long press, game detail, and the edit screen.
