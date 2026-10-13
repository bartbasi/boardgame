import 'package:api_contract/api_contract.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

/// T-018 AC1: the barcode lookup response has the normalized GTIN-13 code,
/// a status, and a list of game summaries that fits the status.
void main() {
  group('LookupResponse round trip, one fixture per status (T-018 AC1)', () {
    final known = LookupStatus.values.where((s) => s != LookupStatus.unknown);

    test('there is one fixture for every known status', () {
      expect(
        listFixtures('lookup').toSet(),
        known.map((s) => 'lookup/${s.wireName}.json').toSet(),
      );
    });

    for (final status in known) {
      final path = 'lookup/${status.wireName}.json';
      test('$path decodes to $status and encodes back the same', () {
        final json = readFixture(path);
        final response = LookupResponse.fromJson(json);
        expect(response.status, status);
        expect(response.code, hasLength(13));
        expect(response.toJson(), equals(json));
      });
    }

    test('matched carries exactly one game', () {
      final r = LookupResponse.fromJson(readFixture('lookup/matched.json'));
      expect(r.code, '0036000291452');
      expect(r.games.single.bggId, 13);
    });

    test('candidates keeps the server order', () {
      final r = LookupResponse.fromJson(readFixture('lookup/candidates.json'));
      expect(r.games.map((g) => g.bggId), [13, 822, 424242]);
    });

    test('none and unavailable carry an empty list', () {
      for (final path in ['lookup/none.json', 'lookup/unavailable.json']) {
        expect(LookupResponse.fromJson(readFixture(path)).games, isEmpty);
      }
    });
  });

  group('LookupStatus forward compatibility (T-018 AC1)', () {
    test('an unknown status decodes to unknown and keeps its games', () {
      final r = LookupResponse.fromJson(
        readFixture('variants/lookup_unknown_status.json'),
      );
      expect(r.status, LookupStatus.unknown);
      expect(r.games, hasLength(2));
    });

    test('an unknown status with no games is also accepted', () {
      final r = LookupResponse.fromJson({
        'code': '0036000291452',
        'status': 'brand_new_status',
        'games': <Object>[],
      });
      expect(r.status, LookupStatus.unknown);
    });

    test('status matching is case sensitive', () {
      final r = LookupResponse.fromJson({
        'code': '0036000291452',
        'status': 'NONE',
        'games': <Object>[],
      });
      expect(r.status, LookupStatus.unknown);
    });

    test('wire names are the documented snake_case values', () {
      expect(LookupStatus.values.map((s) => s.wireName).toList(), [
        'matched',
        'candidates',
        'none',
        'unavailable',
        'unknown',
      ]);
    });
  });

  group('LookupResponse invalid input (T-018 AC1)', () {
    final cases = {
      'malformed/lookup_code_twelve_digits.json': 'code',
      'malformed/lookup_code_number.json': 'code',
      'malformed/lookup_code_letter.json': 'code',
      'malformed/lookup_status_missing.json': 'status',
      'malformed/lookup_games_null.json': 'games',
      'malformed/lookup_matched_no_games.json': 'games',
      'malformed/lookup_matched_two_games.json': 'games',
      'malformed/lookup_candidates_no_games.json': 'games',
      'malformed/lookup_none_with_games.json': 'games',
      'malformed/lookup_unavailable_with_games.json': 'games',
    };
    cases.forEach((path, key) {
      test('$path throws CheckedFromJsonException for $key', () {
        expect(
          () => LookupResponse.fromJson(readFixture(path)),
          throwsA(
            isA<CheckedFromJsonException>().having((e) => e.key, 'key', key),
          ),
        );
      });
    });

    test('a status and games mismatch names the class and the rule', () {
      try {
        LookupResponse.fromJson(
          readFixture('malformed/lookup_none_with_games.json'),
        );
        fail('expected CheckedFromJsonException');
      } on CheckedFromJsonException catch (e) {
        expect(e.className, 'LookupResponse');
        expect(e.message, 'status none needs an empty games list, got 1');
      }
    });

    test('a 14-digit code is rejected', () {
      expect(
        () => LookupResponse.fromJson({
          'code': '00036000291452',
          'status': 'none',
          'games': <Object>[],
        }),
        throwsA(
          isA<CheckedFromJsonException>().having((e) => e.key, 'key', 'code'),
        ),
      );
    });

    test('non-ASCII digits are rejected', () {
      expect(
        () => LookupResponse.fromJson({
          'code': '００３６０００２９１４５２',
          'status': 'none',
          'games': <Object>[],
        }),
        throwsA(isA<CheckedFromJsonException>()),
      );
    });
  });

  group('LookupResponse value semantics', () {
    test('equality, copyWith, and toString', () {
      final a = LookupResponse.fromJson(readFixture('lookup/matched.json'));
      final b = LookupResponse.fromJson(readFixture('lookup/matched.json'));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.copyWith(status: LookupStatus.none).status, LookupStatus.none);
      expect(a.toString(), contains('matched'));
    });
  });
}
