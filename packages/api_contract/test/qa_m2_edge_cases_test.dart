import 'dart:convert';

import 'package:api_contract/api_contract.dart';
import 'package:test/test.dart';

/// QA edge cases for the T-018 M2 DTOs, beyond the developer's tests.
Map<String, dynamic> game([Map<String, dynamic> over = const {}]) => {
  'bggId': 13,
  'name': 'Catan',
  'yearPublished': 1995,
  'bggUrl': 'https://boardgamegeek.com/boardgame/13',
  ...over,
};

Map<String, dynamic> detail([Map<String, dynamic> over = const {}]) => {
  'bggId': 13,
  'name': 'Catan',
  'bggUrl': 'https://boardgamegeek.com/boardgame/13',
  'fetchedAt': '2026-10-13T08:15:30.000Z',
  ...over,
};

Map<String, dynamic> lookup(
  String status,
  int n, [
  String code = '0036000291452',
]) => {
  'code': code,
  'status': status,
  'games': List.generate(n, (i) => game({'bggId': i + 1})),
};

Matcher failsOn(String key) =>
    throwsA(isA<CheckedFromJsonException>().having((e) => e.key, 'key', key));

void main() {
  group('unknown fields at every nesting level are ignored', () {
    test('lookup top level and nested game', () {
      final r = LookupResponse.fromJson({
        ...lookup('matched', 0),
        'extra': 1,
        'games': [
          game({
            'extra': {'a': 1},
            'more': <int>[],
          }),
        ],
      });
      expect(r.games.single.name, 'Catan');
      expect(r.toJson().containsKey('extra'), isFalse);
      expect((r.toJson()['games'] as List).single, isNot(contains('extra')));
    });
    test('search nested game', () {
      final r = SearchResponse.fromJson({
        'query': 'q',
        'x': 1,
        'games': [
          game({'x': 1}),
        ],
      });
      expect(r.games, hasLength(1));
    });
    test('detail', () {
      expect(GameDetailResponse.fromJson(detail({'x': 1})).bggId, 13);
    });
  });

  group('missing optional fields and null vs absent', () {
    test('summary: absent equals explicit null', () {
      final a = GameSummary.fromJson({'bggId': 1, 'name': 'n', 'bggUrl': 'u'});
      final b = GameSummary.fromJson(
        game({'bggId': 1, 'name': 'n', 'bggUrl': 'u', 'yearPublished': null}),
      );
      expect(a, b);
      expect(a.yearPublished, isNull);
    });
    test('summary toJson writes explicit nulls', () {
      final j = GameSummary.fromJson({'bggId': 1, 'name': 'n', 'bggUrl': 'u'})
          .toJson();
      expect(j.containsKey('yearPublished'), isTrue);
      // No image URL field exists (T-018 R2-M1, PRD Q5).
      expect(j.containsKey('thumbnailUrl'), isFalse);
    });
    test('detail: absent equals null, lists default empty', () {
      final a = GameDetailResponse.fromJson(detail());
      final b = GameDetailResponse.fromJson(
        detail({
          'yearPublished': null,
          'minPlayers': null,
          'maxPlayers': null,
          'minPlayTimeMinutes': null,
          'maxPlayTimeMinutes': null,
          'description': null,
          'designers': null,
          'publishers': null,
        }),
      );
      expect(a, b);
      expect(a.designers, isEmpty);
      expect(a.publishers, isEmpty);
    });
    test('detail toJson writes explicit nulls and empty lists', () {
      final j = GameDetailResponse.fromJson(detail()).toJson();
      expect(j['designers'], <String>[]);
      expect(j['publishers'], <String>[]);
      for (final k in [
        'yearPublished',
        'minPlayers',
        'maxPlayers',
        'minPlayTimeMinutes',
        'maxPlayTimeMinutes',
        'description',
      ]) {
        expect(j.containsKey(k) && j[k] == null, isTrue, reason: k);
      }
    });
    test('empty designers/publishers lists stay empty', () {
      final d = GameDetailResponse.fromJson(
        detail({'designers': <String>[], 'publishers': <String>[]}),
      );
      expect(d.designers, isEmpty);
    });
    test('empty-string description is kept, not turned into null', () {
      expect(
        GameDetailResponse.fromJson(detail({'description': ''})).description,
        '',
      );
    });
  });

  group('wrong types', () {
    test('summary', () {
      expect(() => GameSummary.fromJson(game({'name': 5})), failsOn('name'));
      expect(() => GameSummary.fromJson(game({'name': null})), failsOn('name'));
      expect(
        () => GameSummary.fromJson(game({'bggUrl': 5})),
        failsOn('bggUrl'),
      );
      expect(
        () => GameSummary.fromJson(game({'yearPublished': '1995'})),
        failsOn('yearPublished'),
      );
      expect(
        () => GameSummary.fromJson(game({'yearPublished': true})),
        failsOn('yearPublished'),
      );
      expect(
        () => GameSummary.fromJson(game({'bggId': null})),
        failsOn('bggId'),
      );
      expect(
        () => GameSummary.fromJson(game({'bggId': true})),
        failsOn('bggId'),
      );
      expect(
        () => GameSummary.fromJson(
          game({
            'bggId': [1],
          }),
        ),
        failsOn('bggId'),
      );
    });
    test('search', () {
      expect(
        () => SearchResponse.fromJson({'query': 1, 'games': <Object>[]}),
        failsOn('query'),
      );
      expect(
        () => SearchResponse.fromJson({
          'query': 'q',
          'games': <String, Object>{},
        }),
        failsOn('games'),
      );
      expect(
        () => SearchResponse.fromJson({
          'query': 'q',
          'games': [null],
        }),
        throwsA(anything),
      );
      expect(
        () => SearchResponse.fromJson({
          'query': 'q',
          'games': ['x'],
        }),
        throwsA(anything),
      );
    });
    test('lookup', () {
      expect(
        () => LookupResponse.fromJson({...lookup('none', 0), 'games': 'x'}),
        failsOn('games'),
      );
      expect(
        () => LookupResponse.fromJson({...lookup('none', 0), 'status': null}),
        failsOn('status'),
      );
    });
    test('detail', () {
      expect(
        () => GameDetailResponse.fromJson(detail({'designers': 'x'})),
        failsOn('designers'),
      );
      expect(
        () => GameDetailResponse.fromJson(
          detail({
            'designers': [1],
          }),
        ),
        failsOn('designers'),
      );
      expect(
        () => GameDetailResponse.fromJson(detail({'minPlayers': '2'})),
        failsOn('minPlayers'),
      );
      expect(
        () => GameDetailResponse.fromJson(detail({'name': null})),
        failsOn('name'),
      );
      expect(
        () => GameDetailResponse.fromJson(detail({'bggUrl': null})),
        failsOn('bggUrl'),
      );
    });
  });

  group('zero, negative, fractional, huge counts', () {
    for (final field in [
      'minPlayers',
      'maxPlayers',
      'minPlayTimeMinutes',
      'maxPlayTimeMinutes',
    ]) {
      for (final bad in [0, -1, -100, 1.5, 0.0, -0.0, 2.0000001]) {
        test('$field=$bad rejected', () {
          expect(
            () => GameDetailResponse.fromJson(detail({field: bad})),
            failsOn(field),
          );
        });
      }
      test('$field=3.0 accepted as 3, writes 3', () {
        final d = GameDetailResponse.fromJson(detail({field: 3.0}));
        expect(d.toJson()[field], 3);
      });
    }
    test('bggId boundary 1 accepted, 0 and -1 rejected', () {
      expect(GameSummary.fromJson(game({'bggId': 1})).bggId, 1);
      expect(() => GameSummary.fromJson(game({'bggId': 0})), failsOn('bggId'));
      expect(() => GameSummary.fromJson(game({'bggId': -1})), failsOn('bggId'));
    });
    test('very large bggId (2^53) accepted', () {
      expect(
        GameSummary.fromJson(game({'bggId': 9007199254740992})).bggId,
        9007199254740992,
      );
    });
    test('error text never echoes the rejected value', () {
      try {
        GameSummary.fromJson(game({'bggId': 987654321.5}));
        fail('should throw');
      } on CheckedFromJsonException catch (e) {
        expect(e.toString(), isNot(contains('987654321')));
      }
    });
    test(
      'year: zero, negative and whole double accepted; fraction rejected',
      () {
        expect(
          GameSummary.fromJson(game({'yearPublished': 0})).yearPublished,
          0,
        );
        expect(
          GameSummary.fromJson(game({'yearPublished': -500})).yearPublished,
          -500,
        );
        expect(
          GameSummary.fromJson(game({'yearPublished': 1995.0})).yearPublished,
          1995,
        );
        expect(
          () => GameSummary.fromJson(game({'yearPublished': 1995.5})),
          failsOn('yearPublished'),
        );
      },
    );
    test(
      'min greater than max is accepted (contract does not cross-check)',
      () {
        final d = GameDetailResponse.fromJson(
          detail({'minPlayers': 5, 'maxPlayers': 2}),
        );
        expect(d.minPlayers, 5);
      },
    );
    test(
      'absurd count 1e300 is not silently clamped to int max (T-018-B1)',
      () {
        // 1e300 is a whole-valued double. toInt() clamps on the VM.
        Object? result;
        try {
          result = GameDetailResponse.fromJson(detail({'minPlayers': 1e300}))
              .minPlayers;
        } on CheckedFromJsonException {
          return;
        }
        expect(result, isNot(9223372036854775807), reason: 'clamped silently');
      },
    );
  });

  group('fetchedAt', () {
    test('Z, +00:00 and -00:00-style forms decode to UTC', () {
      for (final s in [
        '2026-10-13T08:15:30Z',
        '2026-10-13T08:15:30.123456Z',
        '2026-10-13T08:15:30+00:00',
      ]) {
        final d = GameDetailResponse.fromJson(detail({'fetchedAt': s}));
        expect(d.fetchedAt.isUtc, isTrue, reason: s);
      }
    });
    test('non-UTC offset is converted to the same instant in UTC', () {
      final d = GameDetailResponse.fromJson(
        detail({'fetchedAt': '2026-10-13T10:15:30+02:00'}),
      );
      expect(d.fetchedAt, DateTime.utc(2026, 10, 13, 8, 15, 30));
      expect(d.toJson()['fetchedAt'], endsWith('Z'));
    });
    test(
      'impossible calendar date (month 13, day 45) is rejected (T-018-B2)',
      () {
        expect(
          () => GameDetailResponse.fromJson(
            detail({'fetchedAt': '2026-13-45T00:00:00Z'}),
          ),
          failsOn('fetchedAt'),
        );
      },
    );
    test('no zone, date only, and garbage are rejected', () {
      for (final s in ['2026-10-13T08:15:30', '2026-10-13', '', 'yesterday']) {
        expect(
          () => GameDetailResponse.fromJson(detail({'fetchedAt': s})),
          failsOn('fetchedAt'),
          reason: s,
        );
      }
    });
    test('null and number rejected', () {
      expect(
        () => GameDetailResponse.fromJson(detail({'fetchedAt': null})),
        failsOn('fetchedAt'),
      );
      expect(
        () => GameDetailResponse.fromJson(detail({'fetchedAt': 1760343330})),
        failsOn('fetchedAt'),
      );
    });
    test('a local DateTime built in code is written as UTC with Z', () {
      final d = GameDetailResponse(
        bggId: 1,
        name: 'n',
        bggUrl: 'u',
        fetchedAt: DateTime(2026, 10, 13, 8),
      );
      expect(d.toJson()['fetchedAt'], endsWith('Z'));
    });
  });

  group('lookup codes', () {
    for (final code in [
      '',
      '12345678',
      '036000291452',
      '00360002914520',
      '003600029145a',
      '００３６０００２９１４５２',
      ' 0036000291452',
      '0036000291452\n',
      '0036000291452 ',
    ]) {
      test('code "${code.replaceAll('\n', r'\n')}" rejected', () {
        expect(
          () => LookupResponse.fromJson(lookup('none', 0, code)),
          failsOn('code'),
        );
      });
    }
    test('13 zeros accepted (form check only)', () {
      expect(
        LookupResponse.fromJson(lookup('none', 0, '0000000000000')).code,
        '0000000000000',
      );
    });
    test('leading zeros preserved', () {
      expect(LookupResponse.fromJson(lookup('none', 0)).code, startsWith('00'));
    });
    test('Arabic-Indic digits rejected', () {
      expect(
        () => LookupResponse.fromJson(lookup('none', 0, '٠٠٣٦٠٠٠٢٩١٤٥٢')),
        failsOn('code'),
      );
    });
  });

  group('status and games count', () {
    final cases = <String, List<int>>{
      'matched': [1],
      'candidates': [1, 2, 3],
      'none': [0],
      'unavailable': [0],
      'unknown': [0, 1, 2, 3],
    };
    cases.forEach((status, ok) {
      for (var n = 0; n <= 3; n++) {
        test('$status with $n games ${ok.contains(n) ? "ok" : "rejected"}', () {
          if (ok.contains(n)) {
            expect(
              LookupResponse.fromJson(lookup(status, n)).games,
              hasLength(n),
            );
          } else {
            expect(
              () => LookupResponse.fromJson(lookup(status, n)),
              failsOn('games'),
            );
          }
        });
      }
    });
    test('literal "unknown" on the wire decodes to unknown', () {
      expect(
        LookupResponse.fromJson(lookup('unknown', 1)).status,
        LookupStatus.unknown,
      );
    });
    for (final s in [
      'future_status',
      '',
      'MATCHED',
      'Matched',
      'matched ',
      'camelCase',
    ]) {
      test('status "$s" decodes to unknown with any count', () {
        expect(
          LookupResponse.fromJson(lookup(s, 2)).status,
          LookupStatus.unknown,
        );
        expect(
          LookupResponse.fromJson(lookup(s, 0)).status,
          LookupStatus.unknown,
        );
      });
    }
    test('unknown status encodes as "unknown"', () {
      expect(
        LookupResponse.fromJson(lookup('zzz', 0)).toJson()['status'],
        'unknown',
      );
    });
    test('wire names are unique snake_case', () {
      final names = LookupStatus.values.map((s) => s.wireName).toList();
      expect(names.toSet(), hasLength(names.length));
      expect(names, [
        'matched',
        'candidates',
        'none',
        'unavailable',
        'unknown',
      ]);
    });
    test('count error text does not leak game names', () {
      try {
        LookupResponse.fromJson(lookup('none', 2));
        fail('should throw');
      } on CheckedFromJsonException catch (e) {
        expect(e.toString(), isNot(contains('Catan')));
      }
    });
    test('invalid game inside candidates fails on bggId', () {
      final j = lookup('candidates', 2);
      (j['games'] as List)[1] = game({'bggId': 0});
      expect(() => LookupResponse.fromJson(j), failsOn('bggId'));
    });
  });

  group('unicode and very long text', () {
    const long = 'é日本語🎲';
    test('summary name unicode round trips through JSON text', () {
      final g = GameSummary.fromJson(
        game({'name': 'Brass: Birmingham 🎲 日本語 Ünïcode​'}),
      );
      final again = GameSummary.fromJson(
        jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>,
      );
      expect(again, g);
    });
    test('very long names (1 MB) round trip in summary, detail, search', () {
      final name = long * 100000;
      final g = GameSummary.fromJson(game({'name': name}));
      expect(g.name, hasLength(name.length));
      final d = GameDetailResponse.fromJson(
        detail({
          'name': name,
          'description': name,
          'designers': [name],
          'publishers': [name],
        }),
      );
      expect(
        GameDetailResponse.fromJson(
          jsonDecode(jsonEncode(d.toJson())) as Map<String, dynamic>,
        ),
        d,
      );
      final s = SearchResponse.fromJson({
        'query': name,
        'games': [g.toJson()],
      });
      expect(s.query, name);
    });
    test('empty name and empty query are accepted as strings', () {
      expect(GameSummary.fromJson(game({'name': ''})).name, '');
      expect(
        SearchResponse.fromJson({'query': '', 'games': <Object>[]}).games,
        isEmpty,
      );
    });
    test('many designers (10k) round trip', () {
      final names = List.generate(10000, (i) => 'D$i');
      final d = GameDetailResponse.fromJson(detail({'designers': names}));
      expect(d.designers, names);
    });
    test('designers with empty string entry is kept', () {
      expect(
        GameDetailResponse.fromJson(
          detail({
            'designers': [''],
          }),
        ).designers,
        [''],
      );
    });
  });

  group('immutability and equality', () {
    test('decoded lists are unmodifiable', () {
      final d = GameDetailResponse.fromJson(
        detail({
          'designers': ['a'],
        }),
      );
      expect(() => d.designers.add('b'), throwsUnsupportedError);
      expect(() => d.publishers.add('b'), throwsUnsupportedError);
      final s = SearchResponse.fromJson({
        'query': 'q',
        'games': [game()],
      });
      expect(
        () => s.games.add(GameSummary.fromJson(game())),
        throwsUnsupportedError,
      );
    });
    test('equal inputs are equal with equal hashCode', () {
      expect(
        GameDetailResponse.fromJson(detail()),
        GameDetailResponse.fromJson(detail()),
      );
      expect(
        GameDetailResponse.fromJson(detail()).hashCode,
        GameDetailResponse.fromJson(detail()).hashCode,
      );
    });
    test(
      'mutating the source JSON after decode does not change the object',
      () {
        final src = detail({
          'designers': ['a'],
        });
        final d = GameDetailResponse.fromJson(src);
        (src['designers'] as List).add('b');
        expect(d.designers, ['a']);
      },
    );
  });

  group('malformed top-level input', () {
    test('empty object fails on first required field', () {
      expect(
        () => GameSummary.fromJson({}),
        throwsA(isA<CheckedFromJsonException>()),
      );
      expect(
        () => SearchResponse.fromJson({}),
        throwsA(isA<CheckedFromJsonException>()),
      );
      expect(
        () => LookupResponse.fromJson({}),
        throwsA(isA<CheckedFromJsonException>()),
      );
      expect(
        () => GameDetailResponse.fromJson({}),
        throwsA(isA<CheckedFromJsonException>()),
      );
    });
  });
}
