# App name options

Prepared by: product-manager, 2026-10-13. For PRD Q1 (display name). The bundle id `com.bartbasi.boardgamecollection` is fixed and does not need to match the display name. The display name can change later with an app update.

**This is not legal clearance.** The checks below are web searches for existing apps and products with the same or a very similar name. I could not run a USPTO trademark search (see "Limits"). Before you commit to a name, search USPTO yourself or ask a trademark attorney.

## 1. Store metadata limits (official sources)

| Field | Limit | Source | Checked | Quote | Confidence |
|---|---|---|---|---|---|
| App Store app name | 2 to 30 characters | https://developer.apple.com/help/app-store-connect/reference/app-information/app-information | 2026-10-13 | "The name must be at least two characters and no more than 30 characters." | confirmed |
| App Store subtitle | 30 characters | same page | 2026-10-13 | "This can't be longer than 30 characters." | confirmed |
| App Store keywords | 100 bytes, each keyword more than 2 characters | https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information | 2026-10-13 | "You can provide up to 100 bytes of content." | confirmed |
| App Store promotional text, description | 170 characters, 4,000 characters | same page | 2026-10-13 | "can't be longer than 170 characters"; "Limited to 4000 characters." | confirmed |
| App Store name rules | Unique name; no trademarked terms, popular app names, or prices to game search; subtitles must not reference other apps or make unverifiable claims | https://developer.apple.com/app-store/review/guidelines/ (2.3.7) | 2026-10-13 | "Choose a unique app name ... don't try to pack any of your metadata with trademarked terms, popular app names, pricing information" | confirmed |
| App Store name uniqueness | One app per name per localization. If another developer uses the name, you can only get it with trademark rights, through Apple's claim form. | https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app | 2026-10-13 | "You can use an app name for one app per localization." | confirmed |
| Google Play app name (title) | 30 characters | https://support.google.com/googleplay/android-developer/answer/9859152 | 2026-10-13 | "30 character limit" | confirmed |
| Google Play short description | 80 characters | same page | 2026-10-13 | "80 character limit" | confirmed |
| Google Play full description | 4,000 characters | same page | 2026-10-13 | "4000 character limit" | confirmed |
| Google Play metadata rules | No emojis, no ranking or performance claims ("#1", "App of the year"), no repetitive or unrelated keywords, no all caps unless part of the brand | https://support.google.com/googleplay/android-developer/answer/9898842 | 2026-10-13 | "Don't use emojis, emoticons, or repeated special characters in these metadata elements." | confirmed |

Project constraints that apply to every option:
- No "eBay" in the name without EPN's written approval, and then only descriptively (EBAY-82, docs/api-research.md). None of the options below use it.
- No BoardGameGeek or BGG marks in the name, subtitle, or keywords. Apple 2.3.7 also bars packing metadata with trademarked terms.
- Honest pricing (APPLE-09): the app shows eBay US **asking** prices. Names with "Value" or "Worth" are fine as a brand, but the subtitle, short description, and screenshots must say "asking prices" and must not imply appraisals or sold prices.

## 2. Candidates

Each option is a store title used on both stores (App Store name and Google Play title, 30 characters or fewer). Character counts include spaces and punctuation.

| # | Brand | Store title (chars) | App or product conflicts found | Keyword strength in the title |
|---|---|---|---|---|
| 1 | ShelfWorth | ShelfWorth: Board Game Value (28) | None found under this name. Similar: "Shelf: App for Collectors" (iOS, general collecting), ShelfWatch and ShelfWise (retail shelf audit tools, different market). | Strong: board game, value. Brand hints at a collection on a shelf. |
| 2 | BoxWorth | BoxWorth: Board Game Value (26) | None found. Search results were dominated by Box (cloud storage company), so the brand is hard to search for on the web. | Strong: board game, value. "Box" ties to scanning the box. |
| 3 | MeepleWorth | MeepleWorth: Board Game Value (29) | None found. Many "Meeple" apps exist (Meeple Tracker, Meeple Meet, MeepleUp, MeepleIt, and "Meeple Collection" launching October 2026), so the prefix is crowded. A UK company "Meeple Worx Ltd" appeared in results. | Strong: board game, value. "Meeple" signals the hobby to collectors, but casual users may not know the word. |
| 4 | Meeple Ledger | Meeple Ledger: Board Games (26) | None found. Same crowded "Meeple" prefix as #3. | Medium: board games only. No value or price word in the title. |
| 5 | Tabletop Ledger | Tabletop Ledger: Game Values (28) | None found. "Tabletop Tycoon" (similar sound) is an existing board game publisher brand, so avoid that variant. | Medium: "tabletop" and "values", but no "board game" in the title. |
| 6 | Cardboard Value | Cardboard Value: Board Games (28) | Close conflicts: "CardBoard: Board Game Scoring" (iOS) and "Cardboard Nerd" (board game discovery app, iOS and Android). Google Cardboard (VR) also dominates search. | Medium: board games, value. |
| 7 | Meeple Vault | Meeple Vault: Board Game Value (30, at the limit) | None found under this name. Crowded "Meeple" prefix. | Strong: board game, value. No room left to adjust. |
| 8 | Board Game Vault | Board Game Vault: Collection (28) | "The Board Game Vault", a game cafe and store in New Braunfels, Texas (opened 2026). Generic phrase, hard to own. | Strong: board game, collection. No price word. |
| 9 | Board Game Collector (descriptive) | Board Game Collector & Value (28) | No app with this exact name found. Very close to "My Board Game Collection" (iOS and Android, collection and play logging, package com.tuyware.myboardgamecollection) and to the iOS "Board Game Collection" below. | Very strong: board game, collector, value. |
| 10 | Board Game Collection (plain, working title) | Board Game Collection (21) or Board Game Collection & Value (29) | **Exact name taken on the US App Store**: "Board Game Collection" by Uwe Meier (id408463633), a set of classic board games, last updated 2017-11-10 (https://apps.apple.com/us/app/-/id408463633, checked 2026-10-13). Under Apple's one-name-per-localization rule, we cannot use the exact name on iOS without trademark rights. Whether "Board Game Collection & Value" passes Apple's check is UNVERIFIED (App Store Connect only tells you when you create the app record). Also near "My Board Game Collection". | Very strong: board game, collection. |

Rejected after searching (clear conflicts):
- "Game Shelf" or "GameShelf Value": "Game Shelf" (also "Board Game Shelf") by Saku Studio is a board game collection app with barcode scan on the App Store.
- "ShelfScan": "Shelf Scan" by B. Hunt is on Google Play and finds books, movies, and games on shelves.
- "Board Game Price Check": an older Google Play app of that name by Greg Sharek estimated used board game prices (2013 post).
- "Tabletop Tycoon": existing board game publisher brand.

### Keyword notes

Collectors are likely to search "board game", "collection", "tracker", "price", "value", "barcode", and "scanner" [ASSUMPTION: based on how competing apps title themselves, not on store search data, which I cannot see]. A 30-character title cannot hold all of them, so the subtitle and keyword field carry the rest. On Google Play there is no keyword field, so the short description and full description carry them.

Suggested supporting metadata for any option (all within limits):
- App Store subtitle (30 max): "Scan, price, and track games" (28) or "Barcode scan and price history" (30).
- App Store keywords (100 bytes max): `collector,tracker,barcode,scanner,price,history,tabletop,meeple,wishlist,shelf,used,inventory` (93 bytes). Leave out words already in the name. Never add eBay, BGG, BoardGameGeek, or other apps' names (2.3.7).
- Google Play short description (80 max): "Scan board game barcodes, see used asking prices and history, track your games." (79)

## 3. Ranking

1. **ShelfWorth: Board Game Value.** No conflict found in either store. Short and easy to say and spell. "Shelf" is how collectors talk about their games, and "Worth" says what the app does. The descriptive tail carries the two most important search words. Risk: "Worth" must be backed by honest "asking price" copy everywhere.
2. **Board Game Collector & Value.** The most searchable option and closest to the working title, with no exact conflict found. Cons: a generic phrase is weak as a trademark, easy for others to copy, and easy to confuse with "My Board Game Collection" and the iOS "Board Game Collection".
3. **MeepleWorth: Board Game Value.** No conflict found, and "meeple" tells serious hobbyists at a glance that this is for them. Cons: the "Meeple" prefix is crowded with other board game apps, and newer collectors may not know the word.

### The plain option: "Board Game Collection"

Pros:
- Matches the working title and bundle id, so no rename work in docs or code beyond the display name.
- Every word is a high-intent search term. Instantly clear.

Cons:
- The exact name is already used on the US App Store (Uwe Meier, id408463633). Apple allows one app per name per localization, so we likely cannot ship it on iOS. We would need a variant such as "Board Game Collection & Value", whose acceptance is UNVERIFIED until we try to create the app record.
- Descriptive names are hard to protect as trademarks, and we would compete for recognition with "My Board Game Collection".
- Says nothing about prices, which is the app's main difference from other collection apps.

## 4. Limits of this research

- **No trademark clearance.** The USPTO trademark search (https://tmsearch.uspto.gov/) needs JavaScript and did not render for my tools. I found no well-known board game product with any of the shortlisted brand names through web search, but this is not a trademark search.
- **Store search is indirect.** I cannot run searches inside the App Store or Google Play apps. I used web search, which indexes store pages incompletely, especially Google Play. A name may be in use by an app that is unlisted, in development, or sold only outside the US, and App Store Connect can still reject it. The only certain test is to create the app record in App Store Connect (which reserves the name while the app is in development) and the Play Console listing.
- **Domain names and social handles** were not checked.
- **Search volume** for each keyword is not available to me; keyword strength is a judgment.

## 5. Next steps for the user

1. Pick a top choice and a backup.
2. Search the name at https://tmsearch.uspto.gov/ (classes 9 and 42 are the usual ones for apps [ASSUMPTION]) and in both store apps on your phone.
3. Create the App Store Connect app record with the chosen name early, since that reserves it.
4. Tell the orchestrator so docs/decisions.md, the rename checklist (docs/handoffs/T-012.md, R1-G6), and the BGG application text (T-087) can be updated.
