# Copy

Owner: ux-designer. Every user-facing string, with a stable key. Draft for user review (T-003).

Rules:

- US English. Plain words. Short sentences.
- No em dashes. No double hyphens used as dashes. Use commas, colons, periods, or parentheses.
- Errors say what happened and what to do. No status codes, no exception text, no "oops".
- Never blame the user. No exclamation marks.
- Asking prices are never called sold, value, or sale. The word "value" appears only for the collection estimate, which says it is based on asking prices.
- Placeholders use {name}. Counts use ICU plural syntax in the .arb file. Dates and money are formatted by the app (US formats: $1,234.56, Oct 11, 2026).
- Keys match app/lib/l10n/app_en.arb (camelCase there; dots here are grouping only, so `scanner.denied.title` becomes `scannerDeniedTitle`).
- Strings marked PLACEHOLDER wait on research or legal text and must be replaced before release. They are listed in the handoff.

Time phrases ({when}) come from one formatter: "just now", "5 minutes ago", "5 hours ago", "3 days ago", "Oct 11, 2026" (older than 30 days).

## common

| Key | String |
|---|---|
| common.retry | Retry |
| common.back | Back |
| common.close | Close |
| common.undo | Undo |
| common.done | Done |
| common.openSettings | Open settings |
| common.lastUpdated | Last updated {when} |
| common.offlineBanner | You are offline. Showing saved data. |
| common.offlineNoData | You are offline and nothing is saved for this yet. |
| common.errorGenericTitle | Something went wrong |
| common.errorGenericBody | We could not finish that. Try again in a moment. |
| common.errorUnavailableTitle | Service is busy |
| common.errorUnavailableBody | Our service is not responding right now. Try again in a moment. |
| common.errorRateLimitedBody | Too many requests. Try again in {seconds} seconds. |
| common.errorRateLimitedBodyNoTime | Too many requests. Try again shortly. |
| common.errorTimeoutBody | That took too long. Check your connection and try again. |
| common.refreshFailed | Could not refresh. Showing what we saved. |
| common.loading | Loading |
| common.optional | Optional |
| common.showMore | Show more |
| common.showLess | Show less |
| common.coverPlaceholderLabel | No cover image |
| common.coverLabel | Cover of {name} |
| common.yearUnknown | Year unknown |
| common.nameYear | {name} ({year}) |
| common.poweredByBgg | PLACEHOLDER (T-002): BGG attribution wording and logo |
| common.poweredByBggLabel | PLACEHOLDER (T-002): BGG attribution link label |

## app-shell

| Key | String |
|---|---|
| nav.scan | Scan |
| nav.search | Search |
| nav.collection | Collection |
| nav.settings | Settings |
| nav.scanLabel | Scan a barcode |
| nav.searchLabel | Search by title |
| nav.collectionLabel | Your collection |
| nav.settingsLabel | Settings |
| shell.appName | Board Game Collector |
| shell.skipToContent | Skip to content |

(The app name is a placeholder until PRD Q1 is answered.)

## scanner

| Key | String |
|---|---|
| scanner.title | Scan a barcode |
| scanner.hint | Point the camera at the barcode on the box. |
| scanner.hintSlow | Hold steady and fill the frame with the barcode. Try the torch in low light. |
| scanner.viewfinderLabel | Camera view. Barcode scanning is active. |
| scanner.actionManual | Enter barcode |
| scanner.actionSearch | Search by title |
| scanner.torchOn | Turn torch on |
| scanner.torchOff | Turn torch off |
| scanner.torchLabelOn | Torch is on |
| scanner.torchLabelOff | Torch is off |
| scanner.success | Barcode {code} read. Looking up the game. |
| scanner.permission.requestingTitle | Camera access |
| scanner.permission.requestingBody | The camera reads barcodes on game boxes. Photos and video are never saved or sent anywhere. |
| scanner.denied.title | Camera access is off |
| scanner.denied.body | Without the camera we cannot scan. You can still enter the barcode or search by title. |
| scanner.denied.allow | Allow camera |
| scanner.permanentlyDenied.title | Camera access is blocked |
| scanner.permanentlyDenied.body | To scan, turn on the camera for this app in system settings. You can still enter the barcode or search by title. |
| scanner.restricted.body | Camera access is restricted on this device, so scanning is not available. You can still enter the barcode or search by title. |
| scanner.unavailable.title | Camera not available |
| scanner.unavailable.body | The camera could not start. Another app may be using it. You can still enter the barcode or search by title. |
| scanner.starting | Starting camera |
| scanner.iosUsageDescription | Board Game Collector uses the camera to read barcodes on game boxes. Images are not saved or sent. |
| scanner.androidRationale | Same text as scanner.permission.requestingBody |

## manual-entry

| Key | String |
|---|---|
| manualEntry.title | Enter barcode |
| manualEntry.fieldLabel | Barcode number |
| manualEntry.helper | 8, 12, or 13 digits, printed under the barcode. |
| manualEntry.submit | Look up |
| manualEntry.errorLength | A barcode has 8, 12, or 13 digits. You entered {count}. |
| manualEntry.errorNonDigit | Use digits only. |
| manualEntry.errorCheckDigit | That number does not look right. Check the digits against the box. |
| manualEntry.errorEmpty | Enter the barcode number. |
| manualEntry.errorAnnouncement | Error: {message} |
| manualEntry.searchInstead | Search by title instead |
| manualEntry.scanInstead | Scan instead |
| manualEntry.digitCounter | {count} of 13 digits |

## search

| Key | String |
|---|---|
| search.title | Search |
| search.fieldLabel | Game title |
| search.fieldHint | Search board games |
| search.clear | Clear search |
| search.hintShort | Type at least 2 letters. |
| search.initialTitle | Find a game by title |
| search.initialBody | Type a title above, or scan the barcode on the box. |
| search.actionScan | Scan a barcode |
| search.actionManual | Enter barcode |
| search.emptyTitle | No games found |
| search.emptyBody | Check the spelling or try fewer words. If the box has a barcode, you can enter it instead. |
| search.errorTitle | Search is not working right now |
| search.offlineTitle | You are offline |
| search.offlineBody | Search needs a connection. Games you have opened before still work from your collection or by scanning. |
| search.resultCount | {count, plural, one{1 game found} other{{count} games found}} |
| search.resultLabel | {name}, {year} |
| search.resultLabelNoYear | {name}, year unknown |
| search.resultsFooterBgg | PLACEHOLDER (T-002): BGG attribution in results |
| search.forBarcodeBanner | Pick the game that matches barcode {code}. We will remember your choice. |
| search.paneEmpty | Pick a game to see its details here. |

## lookup-result

| Key | String |
|---|---|
| lookup.title | Barcode {code} |
| lookup.loading | Looking up barcode {code} |
| lookup.candidatesTitle | Which game is this? |
| lookup.candidatesBody | Several games use this barcode. Pick the one in your hands. We will remember your choice. |
| lookup.candidateLabel | {name}, {year}. Opens details and remembers this match. |
| lookup.candidateLabelNoYear | {name}, year unknown. Opens details and remembers this match. |
| lookup.noneTitle | No game found for this barcode |
| lookup.noneBody | Some games are not in our barcode source yet. Search by title and we will remember the match. |
| lookup.unavailableTitle | Barcode lookup is not available right now |
| lookup.unavailableBody | You can still search by title. |
| lookup.offlineTitle | You are offline |
| lookup.offlineBody | This barcode is not saved on your phone yet. Connect to look it up, or search by title when you are back online. |
| lookup.actionSearch | Search by title |
| lookup.actionOtherBarcode | Enter a different barcode |
| lookup.actionScanAgain | Scan again |
| lookup.correctionTitle | Pick the right game |
| lookup.correctionBody | Choose the game that matches barcode {code}. Your choice replaces the current match. |
| lookup.currentMatch | Current match |
| lookup.matchSaved | Saved. Barcode {code} now opens {name}. |

## game-detail

| Key | String |
|---|---|
| gameDetail.title | Game details |
| gameDetail.notThisGame | Not this game? |
| gameDetail.notThisGameLabel | Not this game? Pick a different match for barcode {code} |
| gameDetail.players | Players |
| gameDetail.playersValue | {min} to {max} |
| gameDetail.playersValueSingle | {count} |
| gameDetail.playTime | Play time |
| gameDetail.playTimeValue | {min} to {max} min |
| gameDetail.playTimeValueSingle | {minutes} min |
| gameDetail.designers | {count, plural, one{Designer} other{Designers}} |
| gameDetail.publishers | {count, plural, one{Publisher} other{Publishers}} |
| gameDetail.year | Published {year} |
| gameDetail.description | About this game |
| gameDetail.descriptionEmpty | No description available. |
| gameDetail.notFoundTitle | Game not found |
| gameDetail.notFoundBody | We could not find this game. Try searching by title. |
| gameDetail.notFoundAction | Search by title |
| gameDetail.errorTitle | Could not load this game |
| gameDetail.updatedLabel | Details last updated {when} |
| gameDetail.refreshing | Refreshing |
| gameDetail.dataFromBgg | Game information from BoardGameGeek. |
| gameDetail.openOnBgg | PLACEHOLDER (T-002): link label for the BGG page |
| gameDetail.inCollection | In your collection: {list} |
| gameDetail.collectionSection | Your collection |
| gameDetail.shareLabel | Share |

## add-to-collection

| Key | String |
|---|---|
| addToCollection.button | Add to collection |
| addToCollection.sheetTitle | Add {name} to |
| addToCollection.moveSheetTitle | Move {name} to |
| addToCollection.listOwned | Owned |
| addToCollection.listWanted | Wanted |
| addToCollection.listEvaluating | Evaluating |
| addToCollection.descOwned | Games on your shelf. |
| addToCollection.descWanted | Games you are looking for. |
| addToCollection.descEvaluating | Games you are deciding about. |
| addToCollection.currentList | Current list |
| addToCollection.added | Added to {list}. |
| addToCollection.moved | Moved to {list}. |
| addToCollection.addDetails | Add details |
| addToCollection.failed | Could not save that. Try again. |
| addToCollection.moveButton | Move to another list |
| addToCollection.removeButton | Remove from collection |
| addToCollection.removed | Removed from your collection. |
| addToCollection.alreadyIn | Already in {list}. |

## collection

| Key | String |
|---|---|
| collection.title | Collection |
| collection.tabOwned | Owned |
| collection.tabWanted | Wanted |
| collection.tabEvaluating | Evaluating |
| collection.tabCount | {list}, {count} games |
| collection.searchHint | Search this list |
| collection.sort | Sort |
| collection.filter | Filter |
| collection.sortNameAsc | Name, A to Z |
| collection.sortNameDesc | Name, Z to A |
| collection.sortRecent | Recently added |
| collection.sortYear | Year published |
| collection.sortValue | Estimated price, high to low |
| collection.sortTarget | Target price |
| collection.sortPriority | Priority |
| collection.filterCondition | Condition |
| collection.filterPriority | Priority |
| collection.filterHasPhotos | Has photos |
| collection.filterClear | Clear filters |
| collection.filtersApplied | {count, plural, one{1 filter applied} other{{count} filters applied}} |
| collection.emptyOwnedTitle | No games on your shelf yet |
| collection.emptyOwnedBody | Scan a box or search by title, then add the game to Owned. |
| collection.emptyWantedTitle | Nothing on your want list |
| collection.emptyWantedBody | Found a game you want? Scan or search for it and add it to Wanted. |
| collection.emptyEvaluatingTitle | Nothing to evaluate |
| collection.emptyEvaluatingBody | Holding a game and not sure? Scan it and add it to Evaluating. |
| collection.emptyScan | Scan a barcode |
| collection.emptySearch | Search by title |
| collection.emptyAddManual | Add a game by hand |
| collection.noMatchesTitle | No games match |
| collection.noMatchesBody | Try a different search or clear the filters. |
| collection.errorTitle | Could not open your collection |
| collection.errorBody | Your data is safe on this phone. Close and reopen the app, then try again. |
| collection.rowOwnedLine | {condition}, bought {price} |
| collection.rowWantedLine | Target {price}, {priority} priority |
| collection.rowEvaluatingLine | Added {date} |
| collection.rowLabel | {name}, {year}. {list}. |
| collection.totalTitle | Estimated total of Owned games |
| collection.totalValue | {amount} |
| collection.totalBasis | Sum of median eBay asking prices (used, item price only), not sold prices. |
| collection.totalCoverage | {priced} of {total} games have price data. |
| collection.totalNoData | No price data yet for your Owned games. |
| collection.totalAge | Oldest price data: {when} |
| collection.totalStale | Some prices are more than 2 days old. |
| collection.rowPrice | eBay asking {amount}, {count, plural, one{1 listing} other{{count} listings}}, {when} |
| collection.rowPriceNone | eBay: no current listings |
| collection.rowPriceMissing | No price data yet |
| collection.rowPriceStale | eBay asking {amount}, {count, plural, one{1 listing} other{{count} listings}}, {when}. Out of date. |
| collection.itemCount | {count, plural, one{1 game} other{{count} games}} |
| collection.pickAGame | Pick a game to see its details here. |

## collection-item-edit

| Key | String |
|---|---|
| itemEdit.title | Edit {name} |
| itemEdit.sectionList | List |
| itemEdit.sectionDetails | Details |
| itemEdit.sectionNotes | Notes |
| itemEdit.sectionPhotos | Photos |
| itemEdit.condition | Condition |
| itemEdit.conditionNew | New or sealed |
| itemEdit.conditionLikeNew | Like new |
| itemEdit.conditionVeryGood | Very good |
| itemEdit.conditionGood | Good |
| itemEdit.conditionAcceptable | Acceptable |
| itemEdit.conditionPoor | Poor |
| itemEdit.purchasePrice | Purchase price |
| itemEdit.purchasePriceHelper | What you paid, in US dollars. |
| itemEdit.purchaseDate | Purchase date |
| itemEdit.purchaseDateEmpty | Not set |
| itemEdit.edition | Edition |
| itemEdit.editionHint | For example, 2nd printing |
| itemEdit.expansions | Expansions owned |
| itemEdit.expansionsHint | One per line |
| itemEdit.notes | Notes |
| itemEdit.targetPrice | Target price |
| itemEdit.targetPriceHelper | The most you are willing to pay, in US dollars. |
| itemEdit.priority | Priority |
| itemEdit.priorityHigh | High |
| itemEdit.priorityMedium | Medium |
| itemEdit.priorityLow | Low |
| itemEdit.dateAdded | Date added |
| itemEdit.photosAdd | Add photo |
| itemEdit.photoFromCamera | Take photo |
| itemEdit.photoFromLibrary | Choose from library |
| itemEdit.photoLabel | Photo {index} of {count} |
| itemEdit.photoRemove | Remove photo |
| itemEdit.photoRemoved | Photo removed. |
| itemEdit.photosEmpty | No photos yet. Photos stay on this phone. |
| itemEdit.photoPermissionDenied | Photo access is off. You can turn it on in system settings. |
| itemEdit.errorPrice | Enter an amount like 25.00. |
| itemEdit.errorDate | Enter a real date. |
| itemEdit.errorFutureDate | That date is in the future. |
| itemEdit.saved | Saved |
| itemEdit.saveFailed | Could not save. Your last change was not stored. |
| itemEdit.clearField | Clear {field} |
| itemEdit.moveRow | Move to another list |
| itemEdit.removeRow | Remove from collection |
| itemEdit.notFound | This item is no longer in your collection. |

## backup-and-export

| Key | String |
|---|---|
| backup.title | Backup and export |
| backup.sectionBackup | Backup file |
| backup.sectionExport | Export to CSV |
| backup.sectionImport | Import from CSV |
| backup.backupBody | Save everything in one file: your lists, details, and notes. Keep the file somewhere safe. |
| backup.backupBodyPhotos | PLACEHOLDER (PRD Q12): whether the backup file includes photos |
| backup.saveBackup | Save backup file |
| backup.restoreBackup | Restore from backup file |
| backup.exportBody | Open your lists in a spreadsheet. |
| backup.exportOwned | Export Owned |
| backup.exportWanted | Export Wanted |
| backup.exportEvaluating | Export Evaluating |
| backup.exportAll | Export all lists |
| backup.importBody | Add games from a CSV file. You will see a preview first. |
| backup.importChoose | Choose CSV file |
| backup.working | Working. You can leave this screen. |
| backup.exportDone | Export ready. |
| backup.exportDoneNone | Nothing to export yet. Add games to a list first. |
| backup.backupDone | Backup file ready. |
| backup.lastBackup | Last backup: {when} |
| backup.neverBackedUp | No backup yet |
| backup.importPreviewTitle | Import preview |
| backup.importPreviewSummary | {ok, plural, one{1 game ready to import} other{{ok} games ready to import}}. {skipped, plural, one{1 row skipped} other{{skipped} rows skipped}}. |
| backup.importSkippedTitle | Skipped rows |
| backup.importSkippedRow | Row {row}: {reason} |
| backup.importReasonMissingName | no game name |
| backup.importReasonBadPrice | price is not a number |
| backup.importReasonBadDate | date is not valid |
| backup.importReasonBadList | list is not Owned, Wanted, or Evaluating |
| backup.importReasonDuplicate | already in your collection |
| backup.importConfirm | Import {count} games |
| backup.importDone | Imported {count} games. |
| backup.importDoneSkipped | Imported {count} games. {skipped} rows were skipped. |
| backup.importFailedFile | That file could not be read. Check that it is a CSV file and try again. |
| backup.importUndo | Undo import |
| backup.restorePreviewTitle | Restore preview |
| backup.restorePreviewSummary | Backup from {date}: {owned} Owned, {wanted} Wanted, {evaluating} Evaluating. |
| backup.restoreReplaceNote | Restoring replaces your current collection. Your current collection is kept for undo until you leave this screen. |
| backup.restoreConfirm | Restore |
| backup.restoreDone | Restored from backup. |
| backup.restoreUndo | Undo restore |
| backup.restoreFailedFile | That file is not a backup from this app, or it is damaged. Your collection was not changed. |
| backup.restoreFailedNewer | This backup was made by a newer version of the app. Update the app to restore it. Your collection was not changed. |
| backup.errorStorage | Could not save the file. Check that your phone has free space and try again. |

## settings

| Key | String |
|---|---|
| settings.title | Settings |
| settings.sectionAppearance | Appearance |
| settings.theme | Theme |
| settings.themeSystem | Match system |
| settings.themeLight | Light |
| settings.themeDark | Dark |
| settings.sectionData | Your data |
| settings.backupRow | Backup and export |
| settings.backupRowSub | Save, restore, export, and import |
| settings.sectionPricing | Prices and links |
| settings.pricingInfo | About our prices |
| settings.pricingInfoBody | Prices come from current eBay US listings for used games, item price only, without shipping. They are asking prices, not sold prices. |
| settings.affiliateTitle | Affiliate disclosure |
| settings.affiliateBody | PLACEHOLDER (T-050): full affiliate disclosure text from docs/legal/. Draft idea: "When you open an eBay listing from this app and buy something, we may earn a commission. It does not change your price." |
| settings.sectionAbout | About |
| settings.version | Version {version} |
| settings.bggAttribution | PLACEHOLDER (T-002): BGG attribution and logo |
| settings.ebayStatement | PLACEHOLDER (T-002): eBay data statement if eBay requires one |
| settings.privacyPolicy | Privacy policy |
| settings.privacyPolicyNote | PLACEHOLDER (T-078): link opens the hosted policy in your browser |
| settings.licenses | Open source licenses |
| settings.cameraNote | Camera is used only to read barcodes. Nothing is recorded. |
| settings.mlKitNote | PLACEHOLDER (PRD Q4): Google ML Kit metrics disclosure for Android |
| settings.noAccountNote | There are no accounts. Your collection stays on this phone. |
| settings.clearCache | Clear saved game data |
| settings.clearCacheBody | Removes saved game details and prices. Your collection is not touched. |
| settings.clearCacheDone | Saved game data cleared. |

## listings

| Key | String |
|---|---|
| listings.title | eBay listings |
| listings.subtitle | Current asking prices, used, item price only |
| listings.summary | {count, plural, one{1 current listing} other{{count} current listings}} on eBay US, updated {when} |
| listings.disclosure | PLACEHOLDER (T-050): short affiliate disclosure. Draft idea: "We may earn a commission if you buy through these links." |
| listings.rowPrice | {amount} asking |
| listings.rowCondition | {condition} |
| listings.rowShippingNote | Item price, shipping not included |
| listings.rowEndsAt | Listing ends {date} |
| listings.rowLabel | {title}. Asking price {amount}. {condition}. Opens on eBay. |
| listings.viewOnEbay | View on eBay |
| listings.viewOnEbayLabel | View {title} on eBay |
| listings.sortLow | Price, low to high |
| listings.sortHigh | Price, high to low |
| listings.sortNewest | Newest first |
| listings.emptyTitle | No current listings |
| listings.emptyBody | Nobody has this game listed on eBay US right now. Check back later. |
| listings.errorTitle | Could not load listings |
| listings.offlineBody | You are offline. Showing listings saved {when}. They may have ended. |
| listings.staleNote | These listings are more than 2 days old and may have ended. |
| listings.openFailed | Could not open eBay. Try again. |
| listings.thumbLabel | Photo of listing {title} |
| listings.thumbPlaceholder | No photo |
| listings.fewNote | Only {count, plural, one{1 listing} other{{count} listings}}. Treat these prices with care. |

## price-section (in game-detail)

| Key | String |
|---|---|
| price.sectionTitle | Used price on eBay |
| price.badgeAsking | Asking price |
| price.badgeSold | Sold price |
| price.median | Median asking price |
| price.medianSold | Median sold price |
| price.range | Low {low}, high {high} |
| price.sample | From {count, plural, one{1 listing} other{{count} listings}} |
| price.sampleSold | From {count, plural, one{1 sale} other{{count} sales}} |
| price.source | Source: eBay US, used, item price only |
| price.updated | Updated {when} |
| price.stale | Out of date |
| price.staleNote | This price is more than 2 days old. |
| price.few | Few listings |
| price.fewNote | Based on only {count, plural, one{1 listing} other{{count} listings}}. It may not reflect the market. |
| price.noneTitle | No current listings |
| price.noneBody | Nobody has this game listed on eBay US right now. |
| price.loadingLabel | Loading price |
| price.errorTitle | Could not load the price |
| price.offlineNote | You are offline. Showing the last price we saved, {when}. |
| price.seeListings | See eBay listings |
| price.seeHistory | See price history |
| price.summaryLabel | Median asking price {median} on eBay US, used, from {count} listings, low {low}, high {high}, updated {when}. |
| price.soldDisabledNote | Sold prices are not available. |
| price.noteAskingExplain | Asking prices are what sellers want, not what buyers paid. |

## price-history

| Key | String |
|---|---|
| history.title | Price history |
| history.subtitle | Median asking price on eBay US, used |
| history.range30 | 30 days |
| history.range90 | 90 days |
| history.range365 | 1 year |
| history.rangeAll | All |
| history.rangeLabel | Show {range} |
| history.startsOn | History starts {date}. We began tracking this game then. |
| history.emptyTitle | No history yet |
| history.emptyBody | We save one price a day. Check back tomorrow to see the first points. |
| history.fewPoints | Only {count, plural, one{1 day} other{{count} days}} of history so far. |
| history.errorTitle | Could not load price history |
| history.offlineNote | You are offline. Showing history saved {when}. |
| history.gapNote | Days with no listings are not drawn. |
| history.summary | Median asking price on eBay US, used. From {start} to {end}: started at {first}, now {last}, {trend}. Lowest {min} on {minDate}, highest {max} on {maxDate}. {days} days of data. |
| history.trendUp | up {percent} percent |
| history.trendDown | down {percent} percent |
| history.trendFlat | little changed |
| history.chartLabel | Price history chart. {summary} |
| history.pointLabel | {date}: median asking price {amount}, from {count} listings |
| history.showTable | Show as table |
| history.hideTable | Show chart |
| history.tableDate | Date |
| history.tableMedian | Median asking |
| history.tableCount | Listings |
| history.tableNoListings | No listings |
| history.source | Source: eBay US daily snapshots by this app. Asking prices, not sold prices. |
