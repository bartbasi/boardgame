// T-028: the games remote data source, tested against the api_contract
// fixtures and the fake HTTP adapter (the server endpoints are not built
// yet). Every call runs in fake time with jitter fixed at 0.
import 'dart:io';

import 'package:board_game_collector/core/data/network/api_client.dart';
import 'package:board_game_collector/core/data/network/retry_policy.dart';
import 'package:board_game_collector/core/domain/result.dart';
import 'package:board_game_collector/features/game_detail/data/games_remote_data_source.dart';
import 'package:board_game_collector/features/game_detail/domain/barcode_lookup.dart';
import 'package:board_game_collector/features/game_detail/domain/game_details.dart';
import 'package:board_game_collector/features/game_detail/domain/game_search_results.dart';
import 'package:board_game_collector/features/game_detail/domain/game_summary.dart';
import 'package:board_game_collector/features/scanner/domain/barcode.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_http.dart';

Barcode _barcode(String code) => Barcode.parse(code).valueOrNull!;

GamesRemoteDataSource _source(FakeHttpAdapter adapter) =>
    GamesRemoteDataSource(fakeClient(adapter, random: FixedRandom(0)));

/// One of the three endpoints, called with the inputs from AC1.
enum _Endpoint {
  lookup('/v1/lookup/barcode/0036000291452'),
  search('/v1/games/search'),
  detail('/v1/games/13');

  const _Endpoint(this.path);

  final String path;

  Future<Result<Object>> send(
    GamesRemoteDataSource source, {
    CancelToken? cancelToken,
  }) => switch (this) {
    _Endpoint.lookup => source.lookupBarcode(
      _barcode('036000291452'),
      cancelToken: cancelToken,
    ),
    _Endpoint.search => source.searchGames(
      'Café & Co',
      cancelToken: cancelToken,
    ),
    _Endpoint.detail => source.fetchGame(13, cancelToken: cancelToken),
  };

  /// A valid 200 body for this endpoint.
  String get okBody => switch (this) {
    _Endpoint.lookup => contractFixture('lookup/matched.json'),
    _Endpoint.search => contractFixture('search/results.json'),
    _Endpoint.detail => contractFixture('game_detail/full.json'),
  };
}

Timed<Object> _call(
  _Endpoint endpoint,
  FakeHttpAdapter adapter, {
  CancelToken? cancelToken,
}) => runFake(() => endpoint.send(_source(adapter), cancelToken: cancelToken));

void main() {
  group('AC1: requests go to the right path on the configured base URL', () {
    test('a lookup for 036000291452 asks for the 13-digit code', () {
      final adapter = FakeHttpAdapter([
        respond(200, body: contractFixture('lookup/matched.json')),
      ]);
      final t = runFake(
        () => _source(adapter).lookupBarcode(_barcode('036000291452')),
      );
      expect(t.result.isOk, isTrue, reason: '${t.result}');
      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(
        request.uri.toString(),
        '$testBaseUrl/v1/lookup/barcode/0036000291452',
      );
      expect(request.uri.hasQuery, isFalse);
    });

    test('an EAN-8 and an EAN-13 are sent as their 13-digit keys', () {
      for (final (code, key) in [
        ('96385074', '0000096385074'),
        ('4006381333931', '4006381333931'),
      ]) {
        final adapter = FakeHttpAdapter([
          respond(200, body: '{"code":"$key","status":"none","games":[]}'),
        ]);
        final t = runFake(() => _source(adapter).lookupBarcode(_barcode(code)));
        expect(t.result.isOk, isTrue, reason: '$code: ${t.result}');
        expect(adapter.requests.single.uri.path, '/v1/lookup/barcode/$key');
      }
    });

    test('a search for "Café & Co" carries exactly that text in q', () {
      final adapter = FakeHttpAdapter([
        respond(200, body: contractFixture('search/results.json')),
      ]);
      final t = runFake(() => _source(adapter).searchGames('Café & Co'));
      expect(t.result.isOk, isTrue, reason: '${t.result}');
      final uri = adapter.requests.single.uri;
      expect(uri.scheme, 'https');
      expect(uri.host, 'api.example.test');
      expect(uri.path, '/v1/games/search');
      // The ampersand and the accent are encoded, so the query has one
      // parameter whose decoded value is the exact text.
      expect(uri.query, 'q=Caf%C3%A9+%26+Co');
      expect(uri.queryParametersAll, {
        'q': ['Café & Co'],
      });
    });

    test('search text is sent unchanged: spaces, symbols, and unicode', () {
      for (final query in ['  catan  ', 'a+b=c?#/', '7 Wonders: Duel', '三国']) {
        final adapter = FakeHttpAdapter([
          respond(200, body: contractFixture('search/empty.json')),
        ]);
        runFake(() => _source(adapter).searchGames(query));
        final uri = adapter.requests.single.uri;
        expect(uri.path, '/v1/games/search', reason: query);
        expect(uri.queryParametersAll, {
          'q': [query],
        }, reason: query);
        expect(uri.hasFragment, isFalse, reason: query);
      }
    });

    test('a detail request for bggId 13 goes to /v1/games/13', () {
      final adapter = FakeHttpAdapter([
        respond(200, body: contractFixture('game_detail/full.json')),
      ]);
      final t = runFake(() => _source(adapter).fetchGame(13));
      expect(t.result.isOk, isTrue, reason: '${t.result}');
      expect(
        adapter.requests.single.uri.toString(),
        '$testBaseUrl/v1/games/13',
      );
    });

    test('a base URL with a path prefix keeps it', () {
      final adapter = FakeHttpAdapter([
        respond(200, body: contractFixture('game_detail/full.json')),
      ]);
      runFake(
        () => GamesRemoteDataSource(
          fakeClient(adapter, baseUrl: 'https://api.example.test/prefix'),
        ).fetchGame(13),
      );
      expect(
        adapter.requests.single.uri.toString(),
        'https://api.example.test/prefix/v1/games/13',
      );
    });

    test('a bggId below 1 is refused without a request', () {
      for (final id in [0, -1]) {
        final adapter = FakeHttpAdapter([respond(200)]);
        final t = runFake(() => _source(adapter).fetchGame(id));
        expect(
          t.result,
          const Err<GameDetails>(
            InvalidInputFailure(InvalidInputCode.invalidBggId),
          ),
        );
        expect(adapter.requests, isEmpty);
      }
    });

    test('the cancel token reaches the client for every endpoint', () {
      for (final endpoint in _Endpoint.values) {
        final adapter = FakeHttpAdapter([respond(200, body: endpoint.okBody)]);
        final token = CancelToken()..cancel();
        final t = _call(endpoint, adapter, cancelToken: token);
        expect(t.result.failureOrNull, const CancelledFailure());
        expect(adapter.requests, isEmpty, reason: endpoint.name);
      }
    });
  });

  group('AC1: a 200 maps to the domain entity', () {
    test('lookup: matched with one game', () {
      final adapter = FakeHttpAdapter([
        respond(200, body: contractFixture('lookup/matched.json')),
      ]);
      final t = runFake(
        () => _source(adapter).lookupBarcode(_barcode('036000291452')),
      );
      expect(
        t.result,
        const Ok(
          BarcodeLookup(
            gtin13: '0036000291452',
            status: BarcodeLookupStatus.matched,
            games: [
              GameSummary(
                bggId: 13,
                name: 'Catan',
                yearPublished: 1995,
                bggUrl: 'https://boardgamegeek.com/boardgame/13',
              ),
            ],
          ),
        ),
      );
    });

    test('search: the backend query and results in order', () {
      final adapter = FakeHttpAdapter([
        respond(200, body: contractFixture('search/results.json')),
      ]);
      final t = runFake(() => _source(adapter).searchGames('Catan '));
      expect(
        t.result,
        const Ok(
          GameSearchResults(
            query: 'catan',
            games: [
              GameSummary(
                bggId: 13,
                name: 'Catan',
                yearPublished: 1995,
                bggUrl: 'https://boardgamegeek.com/boardgame/13',
              ),
              GameSummary(
                bggId: 424242,
                name: 'Example Game With No Year',
                bggUrl: 'https://boardgamegeek.com/boardgame/424242',
              ),
            ],
          ),
        ),
      );
    });

    test('search: no results is an empty list, not a failure', () {
      final adapter = FakeHttpAdapter([
        respond(200, body: contractFixture('search/empty.json')),
      ]);
      final t = runFake(() => _source(adapter).searchGames('zzzz'));
      expect(t.result.valueOrNull?.games, isEmpty);
    });
  });

  group('AC3: error answers map to the matching failure', () {
    // (name, handlers, failure, request count, fake time taken). Retryable
    // failures are retried until the 20 s deadline or the 4th attempt.
    final cases = <(String, List<FakeHandler>, Failure, int, Duration)>[
      (
        '400 invalid_barcode',
        [respond(400, body: contractFixture('error/invalid_barcode.json'))],
        const InvalidInputFailure(InvalidInputCode.invalidBarcode),
        1,
        Duration.zero,
      ),
      (
        '400 invalid_query',
        [respond(400, body: contractFixture('error/invalid_query.json'))],
        const InvalidInputFailure(InvalidInputCode.invalidQuery),
        1,
        Duration.zero,
      ),
      (
        '400 invalid_bgg_id',
        [respond(400, body: contractFixture('error/invalid_bgg_id.json'))],
        const InvalidInputFailure(InvalidInputCode.invalidBggId),
        1,
        Duration.zero,
      ),
      (
        '404 not_found',
        [respond(404, body: contractFixture('error/not_found.json'))],
        const NotFoundFailure(),
        1,
        Duration.zero,
      ),
      (
        // A 30 s wait would pass the 20 s call deadline, so the client
        // returns at once and carries the wait for the screen.
        '429 rate_limited with Retry-After 30',
        [
          respond(
            429,
            body: contractFixture('error/rate_limited.json'),
            headers: {'Retry-After': '30'},
          ),
        ],
        const RateLimitedFailure(retryAfter: Duration(seconds: 30)),
        1,
        Duration.zero,
      ),
      (
        '503 upstream_unavailable with Retry-After 1',
        [
          respond(
            503,
            body: contractFixture('error/upstream_unavailable.json'),
            headers: {'Retry-After': '1'},
          ),
        ],
        const ServiceUnavailableFailure(),
        4,
        const Duration(seconds: 3),
      ),
      (
        '500 internal_error (not retried)',
        [respond(500, body: contractFixture('error/internal_error.json'))],
        const UnexpectedFailure(),
        1,
        Duration.zero,
      ),
      (
        'a receive timeout on every attempt',
        [failWith(DioExceptionType.receiveTimeout)],
        const TimeoutFailure(),
        4,
        Duration.zero,
      ),
      (
        // The 20 s call deadline ends a request that never answers.
        'a server that never answers',
        [hang()],
        const TimeoutFailure(),
        1,
        const RetryPolicy().totalTimeout,
      ),
      (
        'no connection (connection error)',
        [failWith(DioExceptionType.connectionError)],
        const NoConnectionFailure(),
        4,
        Duration.zero,
      ),
      (
        'no connection (socket exception)',
        [
          failWith(
            DioExceptionType.unknown,
            error: const SocketException('Network is unreachable'),
          ),
        ],
        const NoConnectionFailure(),
        4,
        Duration.zero,
      ),
    ];

    for (final endpoint in _Endpoint.values) {
      for (final (name, handlers, failure, requests, elapsed) in cases) {
        test('${endpoint.name}: $name gives $failure', () {
          final adapter = FakeHttpAdapter(handlers);
          final t = _call(endpoint, adapter);
          expect(t.result.failureOrNull, failure);
          expect(adapter.requests, hasLength(requests));
          expect(
            adapter.requests.every((r) => r.uri.path == endpoint.path),
            isTrue,
          );
          expect(t.elapsed, elapsed);
        });
      }
    }

    test('a 503 then a 200 returns the 200', () {
      for (final endpoint in _Endpoint.values) {
        final adapter = FakeHttpAdapter([
          respond(
            503,
            body: contractFixture('error/upstream_unavailable.json'),
          ),
          respond(200, body: endpoint.okBody),
        ]);
        final t = _call(endpoint, adapter);
        expect(t.result.isOk, isTrue, reason: '${endpoint.name}: ${t.result}');
        expect(adapter.requests, hasLength(2));
      }
    });
  });

  group('AC4: a 200 that breaks the contract is the unexpected failure', () {
    final bodies = <String, String>{
      'not JSON': '<html>Bad gateway</html>',
      'a JSON array': '[]',
      'a JSON string': '"ok"',
      'an empty object': '{}',
      'an empty body': '',
      'an error envelope': contractFixture('error/not_found.json'),
    };
    for (final endpoint in _Endpoint.values) {
      for (final entry in bodies.entries) {
        test('${endpoint.name}: ${entry.key}', () {
          final adapter = FakeHttpAdapter([respond(200, body: entry.value)]);
          final t = _call(endpoint, adapter);
          expect(t.result.failureOrNull, const UnexpectedFailure());
          expect(adapter.requests, hasLength(1), reason: 'not retried');
        });
      }
    }

    test("one endpoint's body is refused by another", () {
      final cases = {
        _Endpoint.lookup: contractFixture('search/results.json'),
        _Endpoint.search: contractFixture('game_detail/full.json'),
        _Endpoint.detail: contractFixture('lookup/matched.json'),
      };
      for (final MapEntry(key: endpoint, value: body) in cases.entries) {
        final t = _call(endpoint, FakeHttpAdapter([respond(200, body: body)]));
        expect(
          t.result.failureOrNull,
          const UnexpectedFailure(),
          reason: endpoint.name,
        );
      }
    });

    test('a lookup answer for another code is refused', () {
      final adapter = FakeHttpAdapter([
        respond(200, body: contractFixture('lookup/none.json')),
      ]);
      // lookup/none.json answers for 4006381333931.
      final t = runFake(
        () => _source(adapter).lookupBarcode(_barcode('036000291452')),
      );
      expect(t.result, const Err<BarcodeLookup>(UnexpectedFailure()));
    });

    test('details for another game are refused', () {
      final adapter = FakeHttpAdapter([
        respond(200, body: contractFixture('game_detail/minimal.json')),
      ]);
      // game_detail/minimal.json is bggId 424242.
      final t = runFake(() => _source(adapter).fetchGame(13));
      expect(t.result, const Err<GameDetails>(UnexpectedFailure()));
    });

    test('a body over the size limit is refused (AC7)', () {
      final big = 'x' * (ApiClient.defaultMaxResponseBytes + 1);
      final adapter = FakeHttpAdapter([
        respond(200, body: '{"query":"q","games":[],"pad":"$big"}'),
      ]);
      final t = runFake(() => _source(adapter).searchGames('q'));
      expect(t.result, const Err<GameSearchResults>(UnexpectedFailure()));
    });
  });
}
