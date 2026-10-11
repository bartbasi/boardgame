# Flow: Add to collection

Tickets: T-038, T-040, T-042, T-049. Stories: US-6, US-7, US-8. Screens: game-detail, add-to-collection, collection-item-edit, collection.

Goal: file a game in Owned, Wanted, or Evaluating in as few taps as possible.

## Happy path

1. User is on a game detail (from a scan or a search).
2. User taps "Add to collection". A sheet lists Owned, Wanted, Evaluating.
3. User taps one list. The game is added at once and the sheet closes.
4. Snackbar: "Added to Owned." with Undo and "Add details". Game detail now shows "In your collection: Owned".
5. Optional: tapping "Add details" (or Edit later) opens the edit screen. See flows/edit-an-item.md.

Total: two taps from the detail screen to a saved item, no required fields.

## Branches

| Situation | What happens |
|---|---|
| Undo tapped | The item is removed. |
| Save fails | The sheet stays open with a short message. |
| Game already in a list | The button is replaced by the collection section (Edit, Move, Remove). |
| Offline | Works the same. Everything is local. |
| Sheet dismissed | Nothing changes. |

## Rules

- One list per game at a time.
- No confirmation step. Undo is the safety net.
- The collection screen shows the new game under the chosen tab; the Owned total updates (M4).
