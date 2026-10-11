# Screen spec: Settings

Status: draft for user review (T-003). Tickets: T-048 (entries), T-065 (affiliate disclosure), T-012 (placeholder). Flow: flows/export-and-import.md (entry).

## 1. Purpose and entry points

Appearance, data tools, how prices work, the paid link disclosure, and legal and attribution information. The Settings destination in the shell. Works offline.

## 2. Layout

ContentColumn, max 600 dp, SettingsSections with SettingsRows. Order:

1. Appearance: Theme (Match system, Light, Dark) as a row that opens a small menu or a radio list.
2. Your data: `settings.backupRow` (opens backup-and-export), `settings.clearCache`.
3. Prices and links: `settings.pricingInfo` text (what the prices are), then the full paid link disclosure `settings.affiliateTitle` ("Paid link disclosure") and `settings.affiliateBody` as plain visible text (not behind a tap). Wording is a placeholder until Q25 and T-050, and it does not use "affiliate link" (EBAY-93). The Settings copy is in addition to the disclosure next to the listings; Settings alone is not enough (EBAY-92).
4. About, in this order: the privacy policy row `settings.privacyPolicy` (first row, a normal 56 dp row that opens the hosted policy; it is the in-app privacy policy link required by APPLE-02 and GPLAY-03, and it needs no scrolling past anything but the earlier sections), the BGG credit and Powered by BGG logo (BggAttribution full, linked to BoardGameGeek; BGG-40, BGG-41), version, eBay statement (placeholder, T-091), open source licenses, camera note, ML Kit note (placeholder, Android only if approved), no-account note.

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
- The paid link disclosure text and BGG attribution are visible without any tap.
- No sign-in, no account, no "rate us", no feedback prompts, no "what's new".

## 6. Copy

`settings.*` (all), `backup.title`, `common.bggCredit`, `common.bggLogoLabel`.

## 7. Accessibility

- Focus order follows the visual order. Section titles are headings.
- Each row reads its title, subtitle, and current value ("Theme, Match system").
- Links say they open outside the app (role link, hint "opens in browser").
- Text at 200% wraps in rows; rows grow; the disclosure paragraph wraps in full.
- Contrast: body text onSurface; section titles primary on surface (4.5:1 verified in both themes).
- Touch targets: rows at least 56 dp.

## 8. Golden cases
Total: 6. Settings is long, so the "about" golden scrolls to the About section. Placeholders are visible in the goldens on purpose.

| File | Notes |
|---|---|
| settings_default_light_compact.png | Top of the screen, disclosure (placeholder) visible |
| settings_default_dark_compact.png | |
| settings_about_light_compact.png | Scrolled to About: privacy policy row, BGG credit and logo |
| settings_default_dark_expanded.png | |
| settings_default_light_landscape.png | |
| settings_default_text200_light_compact.png | |

## 9. What PM and reviewers should check

- The paid link disclosure is visible text in Settings (placeholder wording marked, no "affiliate link").
- Pricing explanation says asking prices, used, item price only.
- BGG credit and logo are in About; the privacy policy row exists; the eBay statement spot exists (placeholder).
- No nag or prompt anywhere.
- Open questions: whether the app needs a "Contact support" row (PRD Q22); whether a theme override is wanted in v1.
