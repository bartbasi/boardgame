# Screen spec: Backup and export

Status: draft for user review (T-003). Tickets: T-045, T-046, T-047, T-048. Flows: flows/export-and-import.md, flows/backup-and-restore.md.

## 1. Purpose and entry points

Get data out of the app and back in: CSV export, CSV import, and a full backup file with restore. Entry: Settings, row `settings.backupRow`. Pushed screen with the navigation visible. Works offline.

## 2. Layout

ContentColumn, max 600 dp.

| Size | Layout |
|---|---|
| Compact portrait | App bar `backup.title`. Three SettingsSections stacked: Backup file, Export to CSV, Import from CSV. Each has a short body text and buttons (full width, 48 dp). |
| Phone landscape | One column at the right 70% of the content; sections scroll. |
| Medium | One column, 600 dp, centered. |
| Expanded | One column, 600 dp, centered (no second pane). Import and restore previews open as pushed screens in the same column. |

Section order: Backup file first (the most important safety action), then Export, then Import.

Backup section shows `backup.lastBackup` ("Last backup: 3 days ago") or `backup.neverBackedUp`. No reminders, banners, or nags about backing up.

Preview screens (import and restore) are pushed from this screen:

- Import preview: app bar `backup.importPreviewTitle`; summary `backup.importPreviewSummary`; an expandable list "Skipped rows" with `backup.importSkippedRow` entries; primary button `backup.importConfirm`.
- Restore preview: app bar `backup.restorePreviewTitle`; `backup.restorePreviewSummary`; note `backup.restoreReplaceNote`; primary button `backup.restoreConfirm`.

## 3. Components

SettingsSection, SettingsRow, ImportPreview, ProgressRow, ErrorState, Snackbar. See docs/ux/components.md.

## 4. States

| State | What the user sees |
|---|---|
| Idle | Three sections with buttons. |
| Export, nothing to export | Snackbar `backup.exportDoneNone`. No file is created. |
| Export working | ProgressRow `backup.working` with progress for large lists (2,000 games in 5 s or less). The user can leave. |
| Export success | The system share sheet opens with the file (the user chooses where to send or save it). Snackbar `backup.exportDone` after it closes. |
| Backup working and success | Same as export; snackbar `backup.backupDone`; `Last backup` updates. |
| Import: choosing | System file picker opens. Cancel returns with nothing changed. |
| Import: parsing | ProgressRow in the preview screen. |
| Import: preview ready | Summary and skipped rows with reasons (`backup.importReason*`). If at least one row is valid, the confirm button is enabled. |
| Import: all rows skipped | Confirm disabled; text explains; the user can go back and pick another file. |
| Import: file unreadable | ErrorState `backup.importFailedFile` with Back and Choose another file. |
| Import: done | Snackbar `backup.importDone` or `backup.importDoneSkipped` with `backup.importUndo`. Undo removes exactly the games added by this import. |
| Restore: choosing and parsing | As import. |
| Restore: preview ready | Counts per list and the backup date. Confirm button `backup.restoreConfirm`. |
| Restore: not a backup or damaged | ErrorState `backup.restoreFailedFile`. Collection unchanged. |
| Restore: from a newer app version | ErrorState `backup.restoreFailedNewer`. Collection unchanged. |
| Restore: older schema | Works; migrated silently. Same preview. |
| Restore: done | Snackbar `backup.restoreDone` with `backup.restoreUndo`. Undo is available until the user leaves Backup and export or restarts the app, using a safety copy of the previous collection kept on the device [ASSUMPTION]. |
| Storage error | ErrorState `backup.errorStorage` with Retry. |
| Offline | No change. Everything is local. |
| Photos in backup | PLACEHOLDER (PRD Q12): `backup.backupBodyPhotos` explains the choice. |

Restore is the only action that replaces data. The preview screen is the point of consent (the user chose a file, sees what will change, and presses Restore). It is part of the action the user started, not an interstitial, and Undo follows. No "Are you sure?" dialog is added.

## 5. Interactions and navigation

- Export buttons: each list or all lists; builds the CSV, opens the share sheet.
- Import: Choose CSV file, preview, Import N games. Duplicates (same BGG id already in the collection) are skipped and reported [ASSUMPTION].
- Back during working states returns to Settings; work continues and finishes with a snackbar.
- All file work happens off the UI thread; the UI stays responsive.
- CSV export guards against formula injection (values starting with =, +, -, @ are prefixed; stated in the handoff, no UI).

## 6. Copy

`backup.*` (all keys), `common.retry`, `common.undo`.

## 7. Accessibility

- Focus order: Back, Backup section (heading, body, last backup, Save, Restore), Export section, Import section.
- Buttons have unambiguous labels ("Export Owned"). Section titles are headings.
- Progress is announced at start, at 50%, and on completion, not continuously. ProgressRow has a value ("40 percent").
- Preview summary is one grouped node; skipped rows are a list, announced with row numbers.
- Results are announced through snackbars (live region).
- Text at 200%: buttons wrap to 2 lines and keep 48 dp minimum height; sections stack.
- Contrast: standard Material button roles; error text uses the error role with an icon.

## 8. Golden cases

| File | Notes |
|---|---|
| backup_and_export_idle_light_compact.png | Last backup shown |
| backup_and_export_idle_dark_compact.png | |
| backup_and_export_idle_never_light_compact.png | No backup yet |
| backup_and_export_idle_light_medium.png | |
| backup_and_export_idle_dark_expanded.png | |
| backup_and_export_working_light_compact.png | Export progress |
| backup_and_export_importpreview_light_compact.png | 3 skipped rows with reasons |
| backup_and_export_importpreview_dark_compact.png | |
| backup_and_export_importallskipped_light_compact.png | Confirm disabled |
| backup_and_export_importerror_dark_compact.png | Unreadable file |
| backup_and_export_restorepreview_light_compact.png | |
| backup_and_export_restorepreview_dark_expanded.png | |
| backup_and_export_restoreerror_light_compact.png | Newer version |
| backup_and_export_idle_text200_light_compact.png | |
| backup_and_export_importpreview_text200_dark_compact.png | |

## 9. What PM and reviewers should check

- Backup is first and says what is included.
- Preview shows counts and skipped rows with reasons before anything changes.
- Restore failure leaves the collection unchanged and says so.
- Undo exists for import and restore.
- No backup reminders or prompts anywhere.
- Open questions: PRD Q12 (photos in backup); import duplicate handling (skip vs update); whether the safety copy for Undo restore is acceptable.
