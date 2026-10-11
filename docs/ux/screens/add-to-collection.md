# Screen spec: Add to collection (and move between lists)

Status: draft for user review (T-003). Tickets: T-038 (add and move), T-049 (integration). Flows: flows/add-to-collection.md, flows/move-between-lists.md.

This is a sheet, not a full screen: the ListSelectorSheet component, opened from game detail, from a Collection row menu, and from the collection section on game detail.

## 1. Purpose and entry points

File a game in Owned, Wanted, or Evaluating with one tap, or move it to another list. A game is in one list at a time. Entry points: `addToCollection.button` on game detail (add mode), `addToCollection.moveButton` on game detail and on a Collection row menu (move mode).

## 2. Layout

| Size | Layout |
|---|---|
| Compact portrait | Modal bottom sheet, rounded top, drag handle, title `addToCollection.sheetTitle` (or `moveSheetTitle`) with the game name, then three rows of 72 dp: Owned, Wanted, Evaluating, each with an icon, title, one-line description. Sheet height wraps content. |
| Phone landscape | Bottom sheet capped at 400 dp wide, left-aligned to the content area center; scrolls if the screen is shorter than the sheet. |
| Medium | Anchored card, 400 dp wide, centered over the content, with a scrim that does not hide the page. |
| Expanded | Same card, centered over the right pane when in TwoPane. |

## 3. Components

ListSelectorSheet, Snackbar, SkeletonBlock (small progress). See docs/ux/components.md.

## 4. States

| State | What the user sees |
|---|---|
| Add mode | Three tappable rows. Nothing preselected. |
| Move mode | Three rows; the current list has a check and the text `addToCollection.currentList` and is disabled. |
| Saving | The tapped row shows a small progress indicator; the other rows are disabled for the moment of the write (local, under 100 ms in practice). |
| Success | The sheet closes. Snackbar: `addToCollection.added` or `addToCollection.moved` with Undo (and `addToCollection.addDetails` on add). Game detail updates its collection section. |
| Failure | The sheet stays open, an inline error line `addToCollection.failed` shows above the rows, rows are enabled again. |
| Already in a list (add pressed) | Not possible: the button turns into the collection section. If it happens through a race, `addToCollection.alreadyIn`. |
| Loading / empty / offline | Not applicable: local only, works offline. |
| Partial data | Moving keeps all shared fields (notes, date added, purchase data) where they apply; fields that do not apply to the new list are kept hidden, not deleted, so Undo or moving back restores them [ASSUMPTION; T-037 decides storage]. |

## 5. Interactions and navigation

- Tap a row: act at once. No confirm button, no second step.
- Swipe down, tap outside, or Back dismisses with no change.
- Undo (snackbar) reverses the add or the move and restores prior fields.
- `addToCollection.addDetails` opens collection-item-edit for the item.
- Add removes nothing; Remove is on game detail and on the row menu, immediate with Undo `addToCollection.removed`.

## 6. Copy

`addToCollection.button`, `sheetTitle`, `moveSheetTitle`, `listOwned`, `listWanted`, `listEvaluating`, `descOwned`, `descWanted`, `descEvaluating`, `currentList`, `added`, `moved`, `addDetails`, `failed`, `moveButton`, `removeButton`, `removed`, `alreadyIn`, `common.undo`.

## 7. Accessibility

- The sheet is announced as a dialog with its title; focus lands on the title, then the first row.
- Each row is a button: "Owned. Games on your shelf." The current list reads "Wanted, current list, unavailable".
- Result is announced via the snackbar: "Added to Owned."
- Escape and Back close the sheet. The scrim is a "Dismiss" button for screen readers.
- Targets 72 dp rows. Contrast: icons use onSurfaceVariant (3:1), row text onSurface (4.5:1).
- Text at 200%: row descriptions wrap; the sheet scrolls and expands to full height if needed.

## 8. Golden cases

| File | Notes |
|---|---|
| add_to_collection_add_light_compact.png | Sheet over game detail |
| add_to_collection_add_dark_compact.png | |
| add_to_collection_move_light_compact.png | Current list disabled |
| add_to_collection_move_dark_expanded.png | Anchored card |
| add_to_collection_add_light_medium.png | |
| add_to_collection_saving_light_compact.png | Progress on a row |
| add_to_collection_failed_dark_compact.png | Inline error |
| add_to_collection_added_snackbar_light_compact.png | Snackbar with Undo and Add details |
| add_to_collection_add_text200_light_compact.png | |
| add_to_collection_move_text200_dark_compact.png | |

## 9. What PM and reviewers should check

- One tap adds. No confirmation step. Undo exists.
- A game cannot be in two lists.
- Moving keeps shared fields.
- Works offline.
- Open question: when moving from Owned to Wanted, do purchase price and photos stay stored but hidden? Proposed yes (T-037).
