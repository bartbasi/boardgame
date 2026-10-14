// T-028 QA round 1: edge cases for the games remote data source.
import 'dart:convert';
import 'dart:io';

import 'package:api_contract/api_contract.dart';
import 'package:board_game_collector/core/domain/result.dart';
import 'package:board_game_collector/features/game_detail/data/games_remote_data_source.dart';
import 'package:board_game_collector/features/game_detail/domain/barcode_lookup.dart';
import 'package:board_game_collector/features/scanner/domain/barcode.dart';
import 'package:flutter_test/flutter_test.dart';

import '../architecture/api_contract_imports.dart';
import '../helpers/fake_http.dart';

Barcode _barcode(String code) => Barcode.parse(code).valueOrNull!;

GamesRemoteDataSource _source(FakeHttpAdapter adapter) =>
    GamesRemoteDataSource(fakeClient(adapter, random: FixedRandom(0)));

String _error(String code) => jsonEncode({
  'error': {'code': code, 'message': 'x'},
});

Timed<Object> _detail(FakeHttpAdapter adapter, [int id = 13]) =>
    runFake(() => _source(adapter).fetchGame(id));

Timed<Object> _lookup(
  FakeHttpAdapter adapter, [
  String code = '036000291452',
]) => runFake(() => _source(adapter).lookupBarcode(_barcode(code)));

Timed<Object> _search(FakeHttpAdapter adapter) =>
    runFake(() => _source(adapter).searchGames('catan'));

Failure? _failure(Timed<Object> t) => (t.result).failureOrNull;

String _detailJson({int bggId = 13}) {
  final map = jsonDecode(
    contractFixture('game_detail/full.json'),
  ) as Map<String, dynamic>;
  map['bggId'] = bggId;
  return jsonEncode(map);
}

String _lookupJson(String code, String status, {List<int> ids = const [13]}) =>
    jsonEncode({
      'code': code,
      'status': status,
      'games': [
        for (final id in ids)
          {
            'bggId': id,
            'name': 'G$id',
            'yearPublished': 2000,
            'bggUrl': 'https://boardgamegeek.com/boardgame/$id',
          },
      ],
    });

void main() {
  group('every ErrorCode on every status', () {
    // The status decides the failure; only a 400 reads the error code.
    final statusCases = <int, Object Function(ErrorCode)>{
      400: (code) => InvalidInputFailure(switch (code) {
        ErrorCode.invalidBarcode => InvalidInputCode.invalidBarcode,
        ErrorCode.invalidQuery => InvalidInputCode.invalidQuery,
        ErrorCode.invalidBggId => InvalidInputCode.invalidBggId,
        _ => InvalidInputCode.unknown,
      }),
      404: (_) => const NotFoundFailure(),
      500: (_) => const UnexpectedFailure(),
    };
    for (final code in ErrorCode.values) {
      for (final MapEntry(key: status, value: expected)
          in statusCases.entries) {
        test('${code.wireName} on $status', () {
          final adapter = FakeHttpAdapter([
            respond(status, body: _error(code.wireName)),
          ]);
          expect(_failure(_detail(adapter)), expected(code));
        });
      }
    }

    test('an unseen wire code on a 400 is InvalidInputCode.unknown', () {
      final adapter = FakeHttpAdapter([
        respond(400, body: _error('some_future_code')),
      ]);
      expect(
        _failure(_detail(adapter)),
        const InvalidInputFailure(InvalidInputCode.unknown),
      );
    });

    test('every error fixture served at its natural status on all three '
        'endpoints', () {
      final table = <String, (int, Object)>{
        'invalid_barcode': (
          400,
          const InvalidInputFailure(InvalidInputCode.invalidBarcode),
        ),
        'invalid_query': (
          400,
          const InvalidInputFailure(InvalidInputCode.invalidQuery),
        ),
        'invalid_bgg_id': (
          400,
          const InvalidInputFailure(InvalidInputCode.invalidBggId),
        ),
        'not_found': (404, const NotFoundFailure()),
        'internal_error': (500, const UnexpectedFailure()),
        'upstream_unavailable': (503, const ServiceUnavailableFailure()),
      };
      for (final MapEntry(key: name, value: (status, expected))
          in table.entries) {
        for (final call in [_detail, _lookup, _search]) {
          final adapter = FakeHttpAdapter([
            respond(status, body: contractFixture('error/$name.json')),
          ]);
          expect(_failure(call(adapter)), expected, reason: name);
        }
      }
      // Every error fixture file is in the table (or is rate_limited).
      final files = Directory('../packages/api_contract/test/fixtures/error')
          .listSync()
          .map((f) => f.uri.pathSegments.last.replaceAll('.json', ''))
          .toSet();
      expect(files, {...table.keys, 'rate_limited'});
    });

    test('statuses outside the table: 401, 403, 408, 410, 418, 502, 504', () {
      final expected = <int, Object>{
        401: const AccessDeniedFailure(),
        403: const AccessDeniedFailure(),
        408: const TimeoutFailure(),
        410: const NotFoundFailure(),
        418: const UnexpectedFailure(),
        502: const ServiceUnavailableFailure(),
        504: const ServiceUnavailableFailure(),
      };
      for (final MapEntry(key: status, value: failure) in expected.entries) {
        final adapter = FakeHttpAdapter([respond(status, body: '{}')]);
        expect(_failure(_detail(adapter)), failure, reason: '$status');
      }
    });
  });

  group('malformed bodies never throw', () {
    final bodies = <String, String>{
      'truncated JSON': '{"bggId": 13, "name": "Cat',
      'trailing garbage': '${_detailJson()}x',
      'BOM prefix': '﻿${_detailJson()}',
      'NaN literal': '{"bggId": NaN}',
      'null': 'null',
      'true': 'true',
      'number': '12',
      'string': '"ok"',
      'array of objects': '[{"bggId":13}]',
      'empty object': '{}',
      'whitespace only': '   \n',
      'HTML page': '<html><body>Bad gateway</body></html>',
      'deep nesting': '${'[' * 5000}${']' * 5000}',
      'huge bggId': '{"bggId": ${'9' * 400}}',
      'bggId as string': _detailJson().replaceFirst(
        '"bggId":13',
        '"bggId":"13"',
      ),
      'duplicate keys': _detailJson().replaceFirst('{', '{"bggId": 14,'),
    };
    for (final MapEntry(key: name, value: body) in bodies.entries) {
      for (final entry in <String, Timed<Object> Function(FakeHttpAdapter)>{
        'detail': _detail,
        'lookup': _lookup,
        'search': _search,
      }.entries) {
        test('$name on ${entry.key}', () {
          final adapter = FakeHttpAdapter([respond(200, body: body)]);
          final t = entry.value(adapter);
          final r = t.result;
          // A duplicate key is last-wins JSON; everything else is unexpected.
          if ((name == 'duplicate keys' || name == 'BOM prefix') &&
              entry.key == 'detail') {
            expect(r.isOk || r.failureOrNull is UnexpectedFailure, isTrue);
          } else {
            expect(r.failureOrNull, const UnexpectedFailure(), reason: body);
          }
          expect(adapter.requests, hasLength(1), reason: 'not retried');
        });
      }
    }
  });

  group('answers for something else are the unexpected failure', () {
    test('detail for another id (14 for 13)', () {
      final adapter = FakeHttpAdapter([
        respond(200, body: _detailJson(bggId: 14)),
      ]);
      expect(_failure(_detail(adapter)), const UnexpectedFailure());
    });

    test('detail id matches only exactly (130 for 13, 1 for 11)', () {
      expect(
        _failure(
          _detail(
            FakeHttpAdapter([respond(200, body: _detailJson(bggId: 130))]),
          ),
        ),
        const UnexpectedFailure(),
      );
      expect(
        _failure(
          _detail(
            FakeHttpAdapter([respond(200, body: _detailJson(bggId: 1))]),
            11,
          ),
        ),
        const UnexpectedFailure(),
      );
    });

    test('lookup answering another valid code', () {
      final adapter = FakeHttpAdapter([
        respond(200, body: _lookupJson('4006381333931', 'matched')),
      ]);
      expect(_failure(_lookup(adapter)), const UnexpectedFailure());
    });

    test('lookup answering the code without the leading zero is unexpected '
        '(12 digits breaks the contract)', () {
      final adapter = FakeHttpAdapter([
        respond(200, body: _lookupJson('036000291452', 'matched')),
      ]);
      expect(_failure(_lookup(adapter)), const UnexpectedFailure());
    });

    test('lookup for EAN-8 and UPC-A answer with their 13-digit key', () {
      final ean8 = FakeHttpAdapter([
        respond(200, body: _lookupJson('0000096385074', 'none', ids: [])),
      ]);
      final t8 = _lookup(ean8, '96385074');
      expect(ean8.requests.single.uri.path, '/v1/lookup/barcode/0000096385074');
      expect((t8.result).isOk, isTrue);

      final upc = FakeHttpAdapter([
        respond(200, body: _lookupJson('0036000291452', 'matched')),
      ]);
      final tu = _lookup(upc);
      expect((tu.result).isOk, isTrue);
    });

    test('lookup answer for the neighbouring code (last digit changed)', () {
      final adapter = FakeHttpAdapter([
        respond(200, body: _lookupJson('0036000291453', 'matched')),
      ]);
      expect(_failure(_lookup(adapter)), const UnexpectedFailure());
    });
  });

  group('the unknown lookup status is never a match', () {
    test('unknown with one game stays unknown, not matched', () {
      final adapter = FakeHttpAdapter([
        respond(200, body: _lookupJson('0036000291452', 'brand_new')),
      ]);
      final lookup =
          (_lookup(adapter).result as Result<BarcodeLookup>).valueOrNull!;
      expect(lookup.status, BarcodeLookupStatus.unknown);
      expect(lookup.status, isNot(BarcodeLookupStatus.matched));
      expect(lookup.games, hasLength(1));
    });

    test('the fixture with two games stays unknown', () {
      final adapter = FakeHttpAdapter([
        respond(
          200,
          body: contractFixture('variants/lookup_unknown_status.json'),
        ),
      ]);
      final lookup =
          (_lookup(adapter).result as Result<BarcodeLookup>).valueOrNull!;
      expect(lookup.status, BarcodeLookupStatus.unknown);
      expect(lookup.games, hasLength(2));
    });

    test('unknown with no games', () {
      final adapter = FakeHttpAdapter([
        respond(200, body: _lookupJson('0036000291452', 'weird', ids: [])),
      ]);
      final lookup =
          (_lookup(adapter).result as Result<BarcodeLookup>).valueOrNull!;
      expect(lookup.status, BarcodeLookupStatus.unknown);
      expect(lookup.games, isEmpty);
    });

    test('a non-string or empty status: null breaks the contract, "" and 5 '
        'read as unknown (never matched)', () {
      for (final status in ['""', 'null', '5', 'true', '[]']) {
        final body = _lookupJson(
          '0036000291452',
          'x',
        ).replaceFirst('"status":"x"', '"status":$status');
        final adapter = FakeHttpAdapter([respond(200, body: body)]);
        final r = _lookup(adapter).result;
        final lookup = r.valueOrNull as BarcodeLookup?;
        // Whatever it is, it is never a confirmed match.
        expect(
          lookup?.status,
          anyOf(isNull, BarcodeLookupStatus.unknown),
          reason: status,
        );
      }
    });

    test('a matched status with two games breaks the contract', () {
      final adapter = FakeHttpAdapter([
        respond(
          200,
          body: _lookupJson('0036000291452', 'matched', ids: [13, 14]),
        ),
      ]);
      expect(_failure(_lookup(adapter)), const UnexpectedFailure());
    });
  });

  group('game id below 1 sends no request', () {
    for (final id in [0, -1, -13, -2147483648, -9223372036854775808]) {
      test('fetchGame($id)', () {
        final adapter = FakeHttpAdapter([respond(200, body: _detailJson())]);
        final t = _detail(adapter, id);
        expect(
          _failure(t),
          const InvalidInputFailure(InvalidInputCode.invalidBggId),
        );
        expect(adapter.requests, isEmpty);
      });
    }

    test('large ids are sent as the plain number', () {
      for (final id in [1, 2147483647, 9007199254740991]) {
        final adapter = FakeHttpAdapter([
          respond(200, body: _detailJson(bggId: id)),
        ]);
        final t = _detail(adapter, id);
        expect(adapter.requests.single.uri.path, '/v1/games/$id');
        expect((t.result).isOk, isTrue, reason: '$id');
      }
    });
  });

  group('429 with every Retry-After form', () {
    final cases = <String, Duration?>{
      '30': const Duration(seconds: 30),
      '0': Duration.zero,
      '2': const Duration(seconds: 2),
      '  2  ': const Duration(seconds: 2),
      '120': const Duration(minutes: 2),
      'abc': null,
      '': null,
      '-1': null,
      '1.5': null,
      '2s': null,
    };
    for (final MapEntry(key: header, value: wait) in cases.entries) {
      test('Retry-After "$header"', () {
        final adapter = FakeHttpAdapter([
          respond(
            429,
            body: contractFixture('error/rate_limited.json'),
            headers: {'Retry-After': header},
          ),
        ]);
        final t = _lookup(adapter);
        final failure = _failure(t);
        expect(failure, isA<RateLimitedFailure>());
        expect((failure! as RateLimitedFailure).retryAfter, wait);
        // Waits above the 20 s deadline end the call at once.
        if (wait != null && wait > const Duration(seconds: 20)) {
          expect(adapter.requests, hasLength(1));
        }
        expect(t.elapsed, lessThanOrEqualTo(const Duration(seconds: 21)));
      });
    }

    test('an HTTP date 5 s ahead is read as about 5 s', () {
      final adapter = FakeHttpAdapter([
        respond(
          429,
          headers: {
            'Retry-After': HttpDate.format(
              fakeStart.add(const Duration(seconds: 5)),
            ),
          },
        ),
      ]);
      final failure = _failure(_lookup(adapter)) as RateLimitedFailure;
      expect(failure.retryAfter, isNotNull);
      expect(failure.retryAfter! <= const Duration(seconds: 5), isTrue);
    });

    test('no header: four requests, no retryAfter', () {
      final adapter = FakeHttpAdapter([respond(429)]);
      final failure = _failure(_lookup(adapter)) as RateLimitedFailure;
      expect(failure.retryAfter, isNull);
      expect(adapter.requests, hasLength(4));
    });

    test('429 once, then a valid answer: the data source returns it', () {
      final adapter = FakeHttpAdapter([
        respond(429, headers: {'Retry-After': '1'}),
        respond(200, body: contractFixture('lookup/matched.json')),
      ]);
      final t = _lookup(adapter);
      expect((t.result).isOk, isTrue);
      expect(adapter.requests, hasLength(2));
      expect(t.elapsed, greaterThanOrEqualTo(const Duration(seconds: 1)));
    });
  });

  group('api_contract imports check against files outside data/', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('contract_imports_'));
    tearDown(() => tmp.deleteSync(recursive: true));

    void write(String relative, String source) {
      final file = File('${tmp.path}/lib/$relative')
        ..createSync(recursive: true);
      file.writeAsStringSync(source);
    }

    const import = "import 'package:api_contract/api_contract.dart';\n";

    test('files outside the data layer are caught, data files pass', () {
      write('features/a/domain/leak.dart', import);
      write('features/a/presentation/leak.dart', import);
      write('features/a/data/ok.dart', import);
      write('core/data/network/ok.dart', import);
      write('core/domain/leak.dart', import);
      write('core/widgets/leak.dart', import);
      write('app/leak.dart', import);
      write('main.dart', import);
      write('features/a/data_models/leak.dart', import);
      write('features/data/leak.dart', import);
      write('data/leak.dart', import);
      write('features/a/domain/data/leak.dart', import);
      final violations = checkContractImports(Directory('${tmp.path}/lib'));
      final files = {for (final v in violations) v.file};
      expect(
        files,
        containsAll({
          'features/a/domain/leak.dart',
          'features/a/presentation/leak.dart',
          'core/domain/leak.dart',
          'core/widgets/leak.dart',
          'app/leak.dart',
          'main.dart',
          'features/a/data_models/leak.dart',
          'data/leak.dart',
        }),
      );
      expect(files, isNot(contains('features/a/data/ok.dart')));
      expect(files, isNot(contains('core/data/network/ok.dart')));
    });

    test('a data folder nested under domain is not the data layer', () {
      write('features/a/domain/data/leak.dart', import);
      final files = {
        for (final v in checkContractImports(Directory('${tmp.path}/lib')))
          v.file,
      };
      expect(files, contains('features/a/domain/data/leak.dart'));
    });

    test('features/data/x.dart (no feature name) is not the data layer', () {
      write('features/data/leak.dart', import);
      final files = {
        for (final v in checkContractImports(Directory('${tmp.path}/lib')))
          v.file,
      };
      expect(files, contains('features/data/leak.dart'));
    });

    test(
      'src imports, double quotes, show/as, and deferred are all caught',
      () {
        write(
          'features/a/domain/a.dart',
          "import 'package:api_contract/src/game_summary.dart';\n",
        );
        write(
          'features/a/domain/b.dart',
          'import "package:api_contract/api_contract.dart" show HealthResponse;\n',
        );
        write(
          'features/a/domain/c.dart',
          "import 'package:api_contract/api_contract.dart' as api;\n",
        );
        write(
          'features/a/domain/d.dart',
          "import 'package:api_contract/api_contract.dart' deferred as api;\n",
        );
        write(
          'features/a/domain/e.dart',
          "import\n    'package:api_contract/api_contract.dart';\n",
        );
        final files = {
          for (final v in checkContractImports(Directory('${tmp.path}/lib')))
            v.file,
        };
        expect(files, {
          'features/a/domain/a.dart',
          'features/a/domain/b.dart',
          'features/a/domain/c.dart',
          'features/a/domain/d.dart',
          'features/a/domain/e.dart',
        });
      },
    );

    test('exports are caught even inside the data layer, multi-line too', () {
      write(
        'features/a/data/e1.dart',
        "export 'package:api_contract/api_contract.dart';\n",
      );
      write(
        'features/a/data/e2.dart',
        "export\n  'package:api_contract/api_contract.dart' show Failure;\n",
      );
      final files = {
        for (final v in checkContractImports(Directory('${tmp.path}/lib')))
          v.file,
      };
      expect(files, {'features/a/data/e1.dart', 'features/a/data/e2.dart'});
    });

    test('comments and strings that mention the package are not imports', () {
      write(
        'features/a/domain/ok.dart',
        "// import 'package:api_contract/api_contract.dart';\n"
            "/* import 'package:api_contract/api_contract.dart'; */\n"
            "const s = \"import 'package:api_contract/api_contract.dart';\";\n",
      );
      expect(checkContractImports(Directory('${tmp.path}/lib')), isEmpty);
    });

    test('other packages and similarly named packages are fine', () {
      write(
        'features/a/domain/ok.dart',
        "import 'package:api_contract_extras/x.dart';\n"
            "import 'package:other/api_contract/x.dart';\n"
            "import '../data/api_contract.dart';\n",
      );
      expect(checkContractImports(Directory('${tmp.path}/lib')), isEmpty);
    });

    test('a missing lib folder is no violation, not a crash', () {
      expect(checkContractImports(Directory('${tmp.path}/nothing')), isEmpty);
    });
  });
}
