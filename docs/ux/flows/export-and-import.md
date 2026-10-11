# Flow: Export and import (CSV)

Tickets: T-045, T-046, T-048. Stories: US-10. Screens: settings, backup-and-export.

## Export

1. Settings, then "Backup and export".
2. User taps "Export Owned" (or Wanted, Evaluating, or "Export all lists").
3. The file is built (progress shows for large lists). The system share sheet opens with the CSV so the user chooses where to save or send it.
4. Snackbar: "Export ready."

Branches: empty list gives "Nothing to export yet. Add games to a list first." and no file. Storage full gives a plain error with Retry. The user can leave during progress; the work continues.

## Import

1. Settings, then "Backup and export", then "Choose CSV file".
2. The system file picker opens. User picks a file.
3. The import preview shows how many games are ready and how many rows are skipped, with a reason for each skipped row (no name, bad price, bad date, bad list, already in your collection).
4. User taps "Import N games".
5. Snackbar: "Imported N games." (plus the skipped count) with Undo import.

Branches:

| Situation | What happens |
|---|---|
| File is not a readable CSV | "That file could not be read..." with a way to pick another file. |
| Every row skipped | Confirm is disabled; the reasons are listed. |
| User backs out of the picker or preview | Nothing changes. |
| Undo import | Removes exactly the games added by this import. |

## Rules

- Nothing changes until the user taps the Import button on the preview.
- Exports guard against spreadsheet formula injection.
- Works offline.
