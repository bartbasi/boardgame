# Screen spec: Collection item edit

Status: draft for user review (T-003). Tickets: T-040, T-041, T-042. Flow: flows/edit-an-item.md.

## 1. Purpose and entry points

View and edit the fields for a game in the collection. Entry: Edit on game detail's collection section, Edit in a Collection row menu, `addToCollection.addDetails` in the add snackbar. Fields depend on the list:

- Owned: condition, purchase price, purchase date, edition, expansions owned, notes, photos.
- Wanted: target price, priority, notes.
- Evaluating: notes, date added.

## 2. Layout

ContentColumn, max 600 dp. Pushed screen with the navigation visible.

| Size | Layout |
|---|---|
| Compact portrait | App bar with Back and `itemEdit.title`. A header row: small cover, name, year, and the current list with a "Move to another list" text action. Then sections in one scrolling form: Details (type-specific fields), Notes, Photos (Owned only). At the end: `itemEdit.removeRow` as a TextButton in error color text with icon (not color alone). |
| Phone landscape | Form in one column at the right 60%; header with cover and list at the left 40% (pinned). |
| Medium | One column, 600 dp, centered. |
| Expanded | Same, centered. When opened from the Collection TwoPane, the edit appears in the right pane in place of detail, with a Back arrow to detail. |

Fields use full width. Two short fields (purchase price and purchase date) sit side by side at 600 dp and stack below 400 dp or at large text.

## 3. Components

MoneyField, DateField, ChoiceField, MultiLineField, ChipChoice, PhotoStrip, ListSelectorSheet, Snackbar. See docs/ux/components.md.

## 4. States

| State | What the user sees |
|---|---|
| Loading | Skeleton fields for under 300 ms (local data). |
| Success (viewing and editing) | Fields show saved values. Empty optional fields show the label and `common.optional`. |
| Editing | Each field autosaves when it loses focus or when the user leaves the screen. After each save, a quiet "Saved" text (`itemEdit.saved`) fades in next to the app bar title and is announced politely. There is no Save button, no discard dialog, and no unsaved-changes prompt. |
| Field error | Price: `itemEdit.errorPrice`. Date: `itemEdit.errorDate`, `itemEdit.errorFutureDate`. The error shows under the field with an icon; the invalid value is not saved, the last valid value stays stored. Leaving the screen with an invalid field keeps the last valid value. |
| Save failed | Inline message `itemEdit.saveFailed` pinned under the app bar; fields stay editable. |
| Photos: empty | `itemEdit.photosEmpty` and the Add photo tile. |
| Photos: permission denied | Inline message `itemEdit.photoPermissionDenied` with `common.openSettings`. Does not affect other fields. |
| Photos: add | Menu with `itemEdit.photoFromCamera` and `itemEdit.photoFromLibrary`. |
| Photo removed | Snackbar `itemEdit.photoRemoved` with Undo. |
| Item no longer exists | `itemEdit.notFound` ErrorState, with a Back action. |
| Offline | Works fully. No banner. |
| Partial | Empty optional fields are normal. Price and date, if empty, show nothing in the collection row line. |

When the list changes (move) from inside this screen, the form re-renders for the new list's fields immediately. Shared fields (notes, date added) carry over; fields that no longer apply are hidden, not deleted.

## 5. Interactions and navigation

- Tapping DateField opens the system date picker (Material date picker; iOS uses the same Material picker, since the app is Material).
- Clear buttons (48 dp) empty a field; labeled `itemEdit.clearField`.
- Priority is a SegmentedButton: High, Medium, Low.
- Condition is a dropdown with six options (`itemEdit.condition*`).
- Expansions owned is a multi-line field, one expansion per line [ASSUMPTION; could later be a chip list tied to BGG data].
- Photos: tap opens a full-screen viewer (swipe between photos, Remove button). Max 10 photos per item [ASSUMPTION].
- `itemEdit.moveRow` opens ListSelectorSheet in move mode. `itemEdit.removeRow` removes at once and goes back, Snackbar Undo.
- Back or the system gesture leaves the screen; everything was already saved.
- Keyboard: the numeric keyboard for money; the date uses the picker, not the keyboard.

## 6. Copy

`itemEdit.*` (title, sectionList, sectionDetails, sectionNotes, sectionPhotos, condition and the six condition values, purchasePrice, purchasePriceHelper, purchaseDate, purchaseDateEmpty, edition, editionHint, expansions, expansionsHint, notes, targetPrice, targetPriceHelper, priority and values, dateAdded, photos strings, error strings, saved, saveFailed, clearField, moveRow, removeRow, notFound), `addToCollection.moved`, `addToCollection.removed`, `common.optional`, `common.undo`, `common.openSettings`.

## 7. Accessibility

- Focus order follows reading order: Back, header (name, list, move), fields in order, photos, remove.
- Every field has a visible label (not placeholder-only) and its helper or error as a hint. Errors are announced when they appear.
- Money fields read "Purchase price, US dollars".
- "Saved" is announced politely, at most once every 2 seconds.
- Photo thumbnails are labeled `itemEdit.photoLabel` ("Photo 2 of 4"); the viewer announces position; Remove has a clear label.
- The date picker is the platform's accessible picker.
- Contrast: error text and icon use the error role on surface (4.5:1); the remove action uses text plus icon.
- Text at 200%: fields keep a minimum height and grow; side-by-side fields stack; labels wrap.
- Targets: 48 dp for every control, including clear buttons and photo tiles (96 dp).

## 8. Golden cases

| File | Notes |
|---|---|
| collection_item_edit_owned_light_compact.png | All fields filled, 3 photos |
| collection_item_edit_owned_dark_compact.png | |
| collection_item_edit_owned_empty_light_compact.png | New item, no values, photos empty |
| collection_item_edit_wanted_light_compact.png | Target and priority |
| collection_item_edit_wanted_dark_expanded.png | |
| collection_item_edit_evaluating_dark_compact.png | Notes and date added |
| collection_item_edit_owned_light_medium.png | |
| collection_item_edit_owned_light_landscape.png | |
| collection_item_edit_error_light_compact.png | Price and date errors |
| collection_item_edit_error_dark_compact.png | |
| collection_item_edit_photopermission_light_compact.png | Denied, Open settings |
| collection_item_edit_savefailed_dark_compact.png | |
| collection_item_edit_notfound_light_compact.png | |
| collection_item_edit_owned_text200_light_compact.png | |
| collection_item_edit_owned_text200_dark_expanded.png | |

## 9. What PM and reviewers should check

- No Save button and no discard prompt; autosave works.
- Fields match the brief per list.
- Errors are plain and announced; the invalid value is not stored.
- Photos have permission handling and stay on the device.
- Remove and photo delete have Undo.
- Open questions: PRD Q11 (manual entry scope), Q12 (photos in backups), the photo limit, and whether expansions should be structured data.
