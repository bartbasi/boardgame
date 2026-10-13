# api_contract

Request and response DTOs shared by the Board Game Collector app (`app/`) and backend (`server/`). Both depend on this package with `path: ../packages/api_contract` (docs/decisions.md, T-004). The package is pure Dart: it has no Flutter dependency, so the server builds it with the plain Dart SDK.

## Compatibility rule

- Changes within /v1 are additive only: new optional fields, new DTOs, new error codes.
- Removing or renaming a field, changing its type, or making an optional field required needs a new API version (/v2), while /v1 keeps working. There is never a forced app update.
- Clients must tolerate additions, so decoding ignores unknown fields and maps unknown error codes and lookup statuses to `unknown`.
- Adding an `ErrorCode` or `LookupStatus` value is wire compatible (old app builds decode it to `unknown`), but it breaks the build of any code in this repo that switches over every value. The app's exhaustive switches are intentional (docs/decisions.md 2026-10-13): whoever adds a value updates the app in the same change so that the new value is handled.

## Decoding rules

- Every DTO has `fromJson(Map<String, dynamic>)` and `toJson()`.
- Before calling `fromJson`, callers must check that the body is a JSON object: handle the `FormatException` from `jsonDecode` (invalid JSON, or an HTML error page from a proxy) and check `is Map<String, dynamic>` (not an array or a scalar). Those failures happen before this package is involved and are not `CheckedFromJsonException`.
- Unknown fields are ignored.
- A required field that is missing, null, or of the wrong type throws `CheckedFromJsonException` (re-exported from this package). Its `key` names the field. Decoding never returns a silent null for a required field.
- An error code this version does not know decodes to `ErrorCode.unknown`.
- JSON keys are camelCase, the same as the Dart field names. Error code values are snake_case.

## JSON shapes

### Error envelope

Every error response body from the backend:

```json
{
  "error": {
    "code": "invalid_barcode",
    "message": "The barcode must be a valid UPC-A, EAN-13, or EAN-8 code."
  }
}
```

| Field | Type | Required | Notes |
|---|---|---|---|
| `error.code` | string | yes | Machine-readable code from the table below. |
| `error.message` | string | yes | Human-readable text. Never contains stack traces or upstream error bodies. |

Dart: `ErrorEnvelope(error: ApiError(code: ErrorCode.invalidBarcode, message: '...'))`.

| Code | HTTP status | Dart value | Meaning |
|---|---|---|---|
| `invalid_barcode` | 400 | `ErrorCode.invalidBarcode` | Not a valid UPC-A, EAN-13, or EAN-8 code. |
| `invalid_query` | 400 | `ErrorCode.invalidQuery` | Search query empty, too short, or too long. |
| `invalid_bgg_id` | 400 | `ErrorCode.invalidBggId` | BGG id is not a positive integer. |
| `not_found` | 404 | `ErrorCode.notFound` | The route or resource does not exist. |
| `rate_limited` | 429 | `ErrorCode.rateLimited` | Too many requests; the `Retry-After` header gives whole seconds. |
| `upstream_unavailable` | 503 | `ErrorCode.upstreamUnavailable` | BGG, eBay, or GameUPC failed or timed out. Always 503 with a `Retry-After` header, never 500 (T-013). |
| `internal_error` | 500 | `ErrorCode.internalError` | Unexpected server error. |
| (any other value) | any | `ErrorCode.unknown` | Client side only: a code added after this app version. The server never sends it. |

There is no generic `bad_request` code (decided in T-018, docs/handoffs/T-018.md). A request whose URL the server cannot parse gets 404 `not_found`.

### Health

Body of `GET /health` (outside /v1):

```json
{
  "status": "ok",
  "version": "0.1.0+abc1234"
}
```

| Field | Type | Required | Notes |
|---|---|---|---|
| `status` | string | yes | `ok` when the server is healthy. |
| `version` | string | yes | Server build version. |

### Game summary

One game in a list (search results, lookup candidates). Not a response body on its own.

```json
{
  "bggId": 13,
  "name": "Catan",
  "yearPublished": 1995,
  "thumbnailUrl": null,
  "bggUrl": "https://boardgamegeek.com/boardgame/13"
}
```

| Field | Type | Required | Notes |
|---|---|---|---|
| `bggId` | integer | yes | BoardGameGeek id, a whole number of at least 1. |
| `name` | string | yes | Primary name. |
| `yearPublished` | integer or null | no | Null when BGG gives none, never 0. May be negative. |
| `thumbnailUrl` | string or null | no | Always null for now: no cover images until BGG answers (PRD Q5, docs/decisions.md 2026-10-12). |
| `bggUrl` | string | yes | The game's BGG page, built by the server for the "Powered by BGG" link (BGG-41). Clients never build BGG URLs. |

Dart: `GameSummary`.

### Search

Body of `GET /v1/games/search?q=`. No results is a 200 with an empty list.

```json
{
  "query": "catan",
  "games": [{"bggId": 13, "name": "Catan", "yearPublished": 1995, "thumbnailUrl": null, "bggUrl": "https://boardgamegeek.com/boardgame/13"}]
}
```

| Field | Type | Required | Notes |
|---|---|---|---|
| `query` | string | yes | The query as the server normalized it (T-023 sets the rules). |
| `games` | array of game summaries | yes | Server ranking order: exact name matches first. May be empty. |

Dart: `SearchResponse`.

### Barcode lookup

Body of `GET /v1/lookup/barcode/{code}`.

```json
{
  "code": "0036000291452",
  "status": "matched",
  "games": [{"bggId": 13, "name": "Catan", "yearPublished": 1995, "thumbnailUrl": null, "bggUrl": "https://boardgamegeek.com/boardgame/13"}]
}
```

| Field | Type | Required | Notes |
|---|---|---|---|
| `code` | string | yes | The normalized barcode: a GTIN-13 of exactly 13 ASCII digits (a UPC-A gets one leading zero, an EAN-8 gets five; docs/decisions.md 2026-10-13). |
| `status` | string | yes | One of the statuses below. |
| `games` | array of game summaries | yes | The count must fit the status, or decoding fails. |

| Status | Dart value | `games` |
|---|---|---|
| `matched` | `LookupStatus.matched` | Exactly one game. |
| `candidates` | `LookupStatus.candidates` | At least one game, in ranking order. |
| `none` | `LookupStatus.none` | Empty. The barcode source knows no game for this code. |
| `unavailable` | `LookupStatus.unavailable` | Empty. The barcode source failed or timed out. Still a 200, so the app can offer title search. |
| (any other value) | `LookupStatus.unknown` | Any number. Client side only; the server never sends it. |

A busy BGG queue while the server names candidates is not a status: it is a 503 `upstream_unavailable` error (T-025).

### Game detail

Body of `GET /v1/games/{bggId}`.

```json
{
  "bggId": 13,
  "name": "Catan",
  "yearPublished": 1995,
  "minPlayers": 3,
  "maxPlayers": 4,
  "minPlayTimeMinutes": 60,
  "maxPlayTimeMinutes": 120,
  "designers": ["Example Designer"],
  "publishers": ["Example Publisher A"],
  "description": "Plain text.\nSecond paragraph.",
  "bggUrl": "https://boardgamegeek.com/boardgame/13",
  "fetchedAt": "2026-10-13T08:15:30.000Z"
}
```

| Field | Type | Required | Notes |
|---|---|---|---|
| `bggId` | integer | yes | A whole number of at least 1. |
| `name` | string | yes | Primary name. |
| `yearPublished` | integer or null | no | Null when unknown, never 0. May be negative. |
| `minPlayers`, `maxPlayers` | integer or null | no | At least 1 when present. |
| `minPlayTimeMinutes`, `maxPlayTimeMinutes` | integer or null | no | Minutes, at least 1 when present. |
| `designers`, `publishers` | array of strings | no | BGG's order. Missing or null decodes as an empty list; the server sends `[]`. |
| `description` | string or null | no | Plain text with `\n` line breaks, no HTML markup or character entities. |
| `bggUrl` | string | yes | As in the game summary. |
| `fetchedAt` | string | yes | ISO 8601 in UTC (ends in `Z`, or has an explicit offset). When the server fetched the data from BGG; a cached answer keeps its original time. A timestamp without a zone fails decoding. |

Dart: `GameDetailResponse`. There is no cover image field (PRD Q5); one can be added later as an optional field.

### Missing values

For a value BGG does not give, the server sends null (or `[]` for a list), never 0 or an empty string. The server always includes optional fields, with an explicit null; decoders also accept an absent key.

### BGG page URL

`bggUrl` is `https://boardgamegeek.com/boardgame/{bggId}`, without `www` (BGG-03). The server builds it; the format may change without a contract change, so clients use the field as given.

## Fixtures

`test/fixtures/` holds example JSON that the tests decode and encode again. The app's data layer tests (T-028) reuse them in place.

- `error/<code>.json`: one valid error envelope per known code; must round trip exactly.
- `health/*.json`: valid health responses; must round trip exactly.
- `lookup/<status>.json`: one lookup response per known status (`matched`, `candidates`, `none`, `unavailable`); must round trip exactly.
- `search/results.json` and `search/empty.json`: must round trip exactly.
- `game_detail/full.json` (every field) and `game_detail/minimal.json` (every optional field null or empty): must round trip exactly.
- `game_summary/full.json` and `game_summary/minimal.json`: must round trip exactly.
- `variants/<type>_<case>.json`: valid input that does not round trip (extra fields, unknown codes or statuses, absent optional keys, a UTC offset).
- `malformed/<type>_<case>.json`: input that must fail with `CheckedFromJsonException`. `<type>` is `error`, `health`, `game_summary`, `game_detail`, `search`, or `lookup`; test/fixtures_test.dart decodes each file as that type.

Fixture values (names, designers, descriptions) are examples written for tests, not copies of BGG data.

## Generated code

`*.freezed.dart` and `*.g.dart` files are generated by freezed and json_serializable and are committed, so `app/` and `server/` (and the server Docker build) can use this package without running the generator. The package and the generator need Dart 3.13 or later (`sdk: ^3.13.0`; freezed 4.0.2 requires 3.13). After editing a DTO, regenerate with Dart 3.13 or later and commit the output:

```sh
dart run build_runner build
```

CI (T-011) should run the same command and fail if `git diff --exit-code` shows the committed files are stale.

## Commands

Run from this folder with the Dart SDK (no Flutter needed):

```sh
dart pub get
dart analyze
dart format --output=none --set-exit-if-changed .
dart test
dart run coverage:test_with_coverage   # writes coverage/lcov.info
```
