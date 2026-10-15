// T-028 AC2 (and AC3, AC4 for the error and malformed files): every JSON
// fixture in packages/api_contract/test/fixtures/ goes through the games
// remote data source, served by the fake HTTP adapter. The fixtures are
// read in place (decisions.md 2026-10-12, T-013); a new fixture file fails
// the coverage test at the bottom until it is handled here.
import 'dart:convert';
import 'dart:io';

import 'package:board_game_collector/core/data/network/retry_policy.dart';
import 'package:board_game_collector/core/domain/result.dart';
import 'package:board_game_collector/features/game_detail/data/games_remote_data_source.dart';
import 'package:board_game_collector/features/game_detail/domain/barcode_lookup.dart';
import 'package:board_game_collector/features/game_detail/domain/game_details.dart';
import 'package:board_game_collector/features/game_detail/domain/game_search_results.dart';
import 'package:board_game_collector/features/game_detail/domain/game_summary.dart';
import 'package:board_game_collector/features/scanner/domain/barcode.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_http.dart';

const String _fixtureDir = '../packages/api_contract/test/fixtures';

/// Every fixture path relative to [_fixtureDir], with forward slashes.
List<String> _allFixtures() {
  final root = Directory(_fixtureDir).absolute.path;
  return [
    for (final entity in Directory(_fixtureDir).listSync(recursive: true))
      if (entity is File && entity.path.endsWith('.json'))
        entity.absolute.path
            .substring(root.length + 1)
            .replaceAll(Platform.pathSeparator, '/'),
  ]..sort();
}

Map<String, dynamic> _json(String path) =>
    jsonDecode(contractFixture(path)) as Map<String, dynamic>;

GamesRemoteDataSource _source(FakeHttpAdapter adapter) =>
    GamesRemoteDataSource(fakeClient(adapter, random: FixedRandom(0)));

/// The barcode used to request a lookup fixture: its own code, so the
/// answer fits the request. Malformed fixtures may have no usable code.
Barcode _barcodeFor(Map<String, dynamic> json) {
  final code = json['code'];
  final parsed = code is String ? Barcode.parse(code).valueOrNull : null;
  return parsed ?? Barcode.parse('0036000291452').valueOrNull!;
}

/// The bggId used to request a detail fixture: its own id when usable.
int _bggIdFor(Map<String, dynamic> json) {
  final id = json['bggId'];
  return id is num && id >= 1 && id == id.truncate() ? id.toInt() : 13;
}

Result<BarcodeLookup> _lookup(String body, Map<String, dynamic> json) {
  final adapter = FakeHttpAdapter([respond(200, body: body)]);
  final t = runFake(() => _source(adapter).lookupBarcode(_barcodeFor(json)));
  expect(adapter.requests, hasLength(1));
  return t.result;
}

Result<GameSearchResults> _search(String body) {
  final adapter = FakeHttpAdapter([respond(200, body: body)]);
  final t = runFake(() => _source(adapter).searchGames('catan'));
  expect(adapter.requests, hasLength(1));
  return t.result;
}

Result<GameDetails> _detail(String body, Map<String, dynamic> json) {
  final adapter = FakeHttpAdapter([respond(200, body: body)]);
  final t = runFake(() => _source(adapter).fetchGame(_bggIdFor(json)));
  expect(adapter.requests, hasLength(1));
  return t.result;
}

/// A bare game summary is not a response body; it arrives inside a search
/// (and a lookup), so it is served in a search response.
String _inSearch(String summaryJson) =>
    '{"query":"catan","games":[$summaryJson]}';

/// Checks [game] against the raw JSON: same values, and a missing or null
/// optional value is null, never 0 or an empty string.
void _expectSummary(GameSummary game, Map<String, dynamic> json) {
  expect(game.bggId, json['bggId']);
  expect(game.name, json['name']);
  expect(game.yearPublished, json['yearPublished']);
  expect(game.bggUrl, json['bggUrl']);
}

void _expectDetails(GameDetails game, Map<String, dynamic> json) {
  expect(game.bggId, json['bggId']);
  expect(game.name, json['name']);
  for (final (value, key) in [
    (game.yearPublished, 'yearPublished'),
    (game.minPlayers, 'minPlayers'),
    (game.maxPlayers, 'maxPlayers'),
    (game.minPlayTimeMinutes, 'minPlayTimeMinutes'),
    (game.maxPlayTimeMinutes, 'maxPlayTimeMinutes'),
  ]) {
    expect(value, json[key], reason: key);
  }
  expect(game.designers, json['designers'] ?? isEmpty);
  expect(game.publishers, json['publishers'] ?? isEmpty);
  expect(game.description, json['description']);
  expect(game.bggUrl, json['bggUrl']);
  expect(game.fetchedAt, DateTime.parse(json['fetchedAt'] as String));
  expect(game.fetchedAt.isUtc, isTrue);
}

void _expectGames(List<GameSummary> games, Object? json) {
  final list = json! as List<Object?>;
  expect(games, hasLength(list.length));
  for (var i = 0; i < list.length; i++) {
    _expectSummary(games[i], list[i]! as Map<String, dynamic>);
  }
}

/// Valid response fixtures, by endpoint. Each maps to an entity.
const List<String> _lookupFixtures = [
  'lookup/candidates.json',
  'lookup/matched.json',
  'lookup/none.json',
  'lookup/unavailable.json',
  'variants/lookup_unknown_status.json',
];
const List<String> _searchFixtures = [
  'search/empty.json',
  'search/results.json',
  'variants/search_extra_field.json',
];
const List<String> _detailFixtures = [
  'game_detail/full.json',
  'game_detail/minimal.json',
  'variants/game_detail_extra_field.json',
  'variants/game_detail_fetched_at_offset.json',
  'variants/game_detail_lists_null.json',
  'variants/game_detail_optional_fields_absent.json',
];
const List<String> _summaryFixtures = [
  'game_summary/full.json',
  'game_summary/minimal.json',
  'variants/game_summary_whole_double_id.json',
];

/// Error envelopes and the failure each maps to with its usual status.
const Map<String, (int, Failure)> _errorFixtures = {
  'error/internal_error.json': (500, UnexpectedFailure()),
  'error/invalid_barcode.json': (
    400,
    InvalidInputFailure(InvalidInputCode.invalidBarcode),
  ),
  'error/invalid_bgg_id.json': (
    400,
    InvalidInputFailure(InvalidInputCode.invalidBggId),
  ),
  'error/invalid_query.json': (
    400,
    InvalidInputFailure(InvalidInputCode.invalidQuery),
  ),
  'error/not_found.json': (404, NotFoundFailure()),
  'error/rate_limited.json': (429, RateLimitedFailure()),
  'error/upstream_unavailable.json': (503, ServiceUnavailableFailure()),
  // An extra field is ignored; this one carries not_found.
  'variants/error_extra_field.json': (404, NotFoundFailure()),
  // A code added after this app version, sent with a 400.
  'variants/error_unknown_code.json': (
    400,
    InvalidInputFailure(InvalidInputCode.unknown),
  ),
};

/// Health is an operations endpoint the app never calls (decisions.md
/// 2026-10-14, T-019 rule 4), so its fixtures are not game responses.
bool _isHealth(String path) =>
    path.startsWith('health/') ||
    path.startsWith('variants/health_') ||
    path.startsWith('malformed/health_');

void main() {
  group('AC2: every valid response fixture maps to its entity', () {
    for (final path in _lookupFixtures) {
      test(path, () {
        final json = _json(path);
        final lookup = _lookup(contractFixture(path), json).valueOrNull;
        expect(lookup, isNotNull);
        expect(lookup!.gtin13, json['code']);
        _expectGames(lookup.games, json['games']);
      });
    }
    for (final path in _searchFixtures) {
      test(path, () {
        final json = _json(path);
        final results = _search(contractFixture(path)).valueOrNull;
        expect(results, isNotNull);
        expect(results!.query, json['query']);
        _expectGames(results.games, json['games']);
      });
    }
    for (final path in _detailFixtures) {
      test(path, () {
        final json = _json(path);
        final details = _detail(contractFixture(path), json).valueOrNull;
        expect(details, isNotNull);
        _expectDetails(details!, json);
      });
    }
    for (final path in _summaryFixtures) {
      test(path, () {
        final json = _json(path);
        final results = _search(_inSearch(contractFixture(path))).valueOrNull;
        expect(results, isNotNull);
        _expectSummary(results!.games.single, json);
      });
    }
  });

  group('AC2: each lookup status maps to its domain status', () {
    const expected = {
      'lookup/matched.json': BarcodeLookupStatus.matched,
      'lookup/candidates.json': BarcodeLookupStatus.candidates,
      'lookup/none.json': BarcodeLookupStatus.none,
      'lookup/unavailable.json': BarcodeLookupStatus.unavailable,
      'variants/lookup_unknown_status.json': BarcodeLookupStatus.unknown,
    };
    for (final MapEntry(key: path, value: status) in expected.entries) {
      test('$path is $status', () {
        final lookup = _lookup(contractFixture(path), _json(path)).valueOrNull;
        expect(lookup?.status, status);
      });
    }
  });

  group('AC2: missing optional fields are absent, not empty or zero', () {
    for (final path in [
      'game_detail/minimal.json',
      'variants/game_detail_optional_fields_absent.json',
      'variants/game_detail_lists_null.json',
    ]) {
      test(path, () {
        final json = _json(path);
        final details = _detail(contractFixture(path), json).valueOrNull!;
        if (path != 'variants/game_detail_lists_null.json') {
          expect(details.yearPublished, isNull);
          expect(details.minPlayers, isNull);
          expect(details.maxPlayers, isNull);
          expect(details.minPlayTimeMinutes, isNull);
          expect(details.maxPlayTimeMinutes, isNull);
          expect(details.description, isNull);
        }
        expect(details.designers, isEmpty);
        expect(details.publishers, isEmpty);
      });
    }

    test('game_detail/minimal.json maps to exactly this entity', () {
      const path = 'game_detail/minimal.json';
      final details = _detail(contractFixture(path), _json(path));
      expect(
        details,
        Ok(
          GameDetails(
            bggId: 424242,
            name: 'Example Game With No Details',
            designers: const [],
            publishers: const [],
            bggUrl: 'https://boardgamegeek.com/boardgame/424242',
            fetchedAt: DateTime.utc(2026, 10, 6, 23, 59, 59),
          ),
        ),
      );
    });

    test('game_summary/minimal.json has no year (null, not 0)', () {
      final results = _search(
        _inSearch(contractFixture('game_summary/minimal.json')),
      ).valueOrNull!;
      expect(results.games.single.yearPublished, isNull);
    });

    test('a UTC offset timestamp maps to the same instant in UTC', () {
      const path = 'variants/game_detail_fetched_at_offset.json';
      final json = _json(path);
      final details = _detail(contractFixture(path), json).valueOrNull!;
      expect(details.fetchedAt.isUtc, isTrue);
      expect(
        details.fetchedAt,
        DateTime.parse(json['fetchedAt'] as String).toUtc(),
      );
    });

    test('mapped lists cannot be changed', () {
      const path = 'game_detail/full.json';
      final details = _detail(contractFixture(path), _json(path)).valueOrNull!;
      expect(() => details.designers.add('x'), throwsUnsupportedError);
      final results = _search(contractFixture('search/results.json'));
      expect(() => results.valueOrNull!.games.clear(), throwsUnsupportedError);
    });
  });

  group('AC3: every error fixture maps to its failure', () {
    for (final MapEntry(key: path, value: (status, failure))
        in _errorFixtures.entries) {
      test('$path with $status gives $failure', () {
        // No Retry-After and no retries, so only the mapping is tested.
        final adapter = FakeHttpAdapter([
          respond(status, body: contractFixture(path)),
        ]);
        final client = GamesRemoteDataSource(
          fakeClient(
            adapter,
            random: FixedRandom(0),
            policy: const RetryPolicy(maxRetries: 0),
          ),
        );
        final t = runFake(() => client.fetchGame(13));
        expect(t.result.failureOrNull, failure);
      });
    }
  });

  group('AC4: every malformed fixture gives the unexpected failure', () {
    final malformed = _allFixtures().where(
      (p) => p.startsWith('malformed/') && !_isHealth(p),
    );
    for (final path in malformed) {
      test(path, () {
        final body = contractFixture(path);
        final json = _json(path);
        final name = path.substring('malformed/'.length);
        final Failure? failure;
        if (name.startsWith('lookup_')) {
          failure = _lookup(body, json).failureOrNull;
        } else if (name.startsWith('search_')) {
          failure = _search(body).failureOrNull;
        } else if (name.startsWith('game_detail_')) {
          failure = _detail(body, json).failureOrNull;
        } else if (name.startsWith('game_summary_')) {
          failure = _search(_inSearch(body)).failureOrNull;
        } else if (name.startsWith('error_')) {
          // A broken error envelope still maps by its status; its code is
          // unknown.
          final adapter = FakeHttpAdapter([respond(400, body: body)]);
          failure = runFake(() => _source(adapter).fetchGame(13))
              .result
              .failureOrNull;
          expect(failure, const InvalidInputFailure(InvalidInputCode.unknown));
          return;
        } else {
          fail('no endpoint for $path');
        }
        expect(failure, const UnexpectedFailure());
      });
    }
  });

  test('every fixture file is covered by a test above', () {
    final handled = {
      ..._lookupFixtures,
      ..._searchFixtures,
      ..._detailFixtures,
      ..._summaryFixtures,
      ..._errorFixtures.keys,
    };
    final all = _allFixtures();
    expect(all, isNotEmpty);
    final unhandled = [
      for (final path in all)
        if (!handled.contains(path) &&
            !path.startsWith('malformed/') &&
            !_isHealth(path))
          path,
    ];
    expect(unhandled, isEmpty, reason: 'add these fixtures to this test');
    // Every listed fixture exists, so a renamed file is noticed too.
    expect(handled.difference(all.toSet()), isEmpty);
  });
}
