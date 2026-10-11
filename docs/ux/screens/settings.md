# Screen spec: Settings

Status: draft for user review (T-003). Tickets: T-048 (entries), T-065 (affiliate disclosure), T-012 (placeholder). Flow: flows/export-and-import.md (entry).

## 1. Purpose and entry points

Appearance, data tools, how prices work, the affiliate disclosure, and legal and attribution information. The Settings destination in the shell. Works offline.

## 2. Layout

ContentColumn, max 600 dp, SettingsSections with SettingsRows. Order:

1. Appearance: Theme (Match system, Light, Dark) as a row that opens a small menu or a radio list.
2. Your data: `settings.backupRow` (opens backup-and-export), `settings.clearCache`.
3. Prices and links: `settings.pricingInfo` text (what the prices are), then the full affiliate disclosure `settings.affiliateTitle` and `settings.affiliateBody` as plain visible text (not behind a tap) [placeholder until T-050].
4. About: version, BGG attribution (placeholder), eBay statement (placeholder), privacy policy link (placeholder), open source licenses, camera note, ML Kit note (placeholder, Android only if approved), no-account note.

| Size | Layout |
|---|---|
| Compact portrait | One column, full width, 16 dp margins. |
| Phone landscape | One column in the right 70%; scrolls. |
| Medium | One column, 600 dp, centered. |
| Expanded | Two-pane list-detail [ASSUMPTION: optional]; the baseline is one centered 600 dp column, which is acceptable. |

## 3. Components

SettingsSection, SettingsRow, AffiliateDisclosure, BggAttribution, Snackbar. See docs/ux/components.md.

## 4. States

| State | What the user sees |
|---|---|
| Default | All sections. |
| Theme change | Applies at once, no restart. |
| Clear saved data working / done | The row shows a small progress indicator, then snackbar `settings.clearCacheDone`. The collection is never touched (`settings.clearCacheBody` says so). No confirmation dialog because the action is safe and reversible (data reloads when viewed). |
| Loading / empty / error | No loading or empty states. A link that cannot open (for example the privacy policy while offline) shows a snackbar `common.errorGenericBody`. |
| Offline | No change; no banner. |
| Partial | Placeholders marked in copy.md must be replaced before release; they show the placeholder text in the golden so reviewers can see where they go. |

## 5. Interactions and navigation

- Theme row: menu with three choices; selected one has a check.
- Backup row pushes backup-and-export.
- Links (privacy policy, BGG, licenses) open outside the app, except licenses, which opens the Flutter license page inside the app.
- The affiliate text and BGG attribution are visible without any tap.
- No sign-in, no account, no "rate us", no feedback prompts, no "what's new".

## 6. Copy

`settings.*` (all), `backup.title`, `common.poweredByBgg` placeholders.

## 7. Accessibility

- Focus order follows the visual order. Section titles are headings.
- Each row reads its title, subtitle, and current value ("Theme, Match system").
- Links say they open outside the app (role link, hint "opens in browser").
- Text at 200% wraps in rows; rows grow; the affiliate paragraph wraps in full.
- Contrast: body text onSurface; section titles primary on surface (4.5:1 verified in both themes).
- Touch targets: rows at least 56 dp.

## 8. Golden cases

| File | Notes |
|---|---|
| settings_default_light_compact.png | Placeholders visible |
| settings_default_dark_compact.png | |
| settings_default_light_medium.png | |
| settings_default_dark_expanded.png | |
| settings_default_light_landscape.png | |
| settings_themeoptions_light_compact.png | Theme menu open |
| settings_cleardone_dark_compact.png | Snackbar |
| settings_default_text200_light_compact.png | |
| settings_default_text200_dark_expanded.png | |

## 9. What PM and reviewers should check

- The affiliate disclosure is visible text in Settings (placeholder wording marked).
- Pricing explanation says asking prices, used, item price only.
- BGG attribution (T-002) and eBay statement spots exist.
- No nag or prompt anywhere.
- Open questions: whether the app needs a "Contact support" row (PRD Q22); whether a theme override is wanted in v1.
