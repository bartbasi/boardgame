# Flow: Backup and restore

Tickets: T-047, T-048. Stories: US-10. Screens: settings, backup-and-export.

Goal: protect the collection, which lives only on the phone.

## Save a backup

1. Settings, then "Backup and export", then "Save backup file" (the first section on the screen).
2. The app builds one versioned file with all lists, details, and notes (photos: see PRD Q12).
3. The share sheet opens so the user can save it to Files, Drive, email, and so on.
4. Snackbar: "Backup file ready." "Last backup" updates on the screen.

No reminders or prompts ever ask the user to back up.

## Restore

1. "Restore from backup file". The system file picker opens.
2. User picks the file. A preview screen shows the backup date and counts per list, with the note that restoring replaces the current collection.
3. User taps "Restore".
4. Snackbar: "Restored from backup." with Undo restore. The previous collection is kept for undo until the user leaves Backup and export or closes the app.

## Branches

| Situation | What happens |
|---|---|
| File is not a backup from this app, or is damaged | Plain message; collection unchanged. |
| Backup is from a newer app version | "Update the app to restore it." Collection unchanged. |
| Backup is from an older version | Restores normally (migrated). |
| Storage full while saving | Plain error with Retry. |
| User cancels the picker or goes back from the preview | Nothing changes. |
| Offline | Works. |

## Rules

- The preview comes before any change, and Undo comes after.
- A failed restore never leaves a half-restored collection.
