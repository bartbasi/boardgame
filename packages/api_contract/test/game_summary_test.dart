import 'package:api_contract/api_contract.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

/// T-018 AC2 and AC9: game summary fields and the server-built BGG URL.
void main() {
  group('GameSummary round trip (T-018 AC2, AC9)', () {
    for (final path in listFixtures('game_summary')) {
      test('$path decodes and encodes back to the same JSON', () {
        final json = readFixture(path);
        expect(GameSummary.fromJson(json).toJson(), equals(json));
      });
    }

    test('full.json has every field, including the BGG page URL', () {
      final game = GameSummary.fromJson(readFixture('game_summary/full.json'));
      expect(
        game,
        const GameSummary(
          bggId: 13,
          name: 'Catan',
          yearPublished: 1995,
          thumbnailUrl: 'https://images.example.invalid/13-thumbnail.jpg',
          bggUrl: 'https://boardgamegeek.com/boardgame/13',
        ),
      );
    });

    test('minimal.json has no year and no thumbnail', () {
      final game = GameSummary.fromJson(
        readFixture('game_summary/minimal.json'),
      );
      expect(game.yearPublished, isNull);
      expect(game.thumbnailUrl, isNull);
      expect(game.bggUrl, 'https://boardgamegeek.com/boardgame/424242');
    });

    test('optional fields that are absent decode as null', () {
      final game = GameSummary.fromJson({
        'bggId': 1,
        'name': 'n',
        'bggUrl': 'https://boardgamegeek.com/boardgame/1',
      });
      expect(game.yearPublished, isNull);
      expect(game.thumbnailUrl, isNull);
      expect(game.toJson(), containsPair('yearPublished', null));
      expect(game.toJson(), containsPair('thumbnailUrl', null));
    });
  });

  group('GameSummary bggId must be a positive whole number (T-018 AC2)', () {
    final cases = {
      'malformed/game_summary_bgg_id_zero.json': 'bggId',
      'malformed/game_summary_bgg_id_negative.json': 'bggId',
      'malformed/game_summary_bgg_id_string.json': 'bggId',
      'malformed/game_summary_bgg_id_fraction.json': 'bggId',
      'malformed/game_summary_name_missing.json': 'name',
      'malformed/game_summary_bgg_url_null.json': 'bggUrl',
      'malformed/game_summary_year_fraction.json': 'yearPublished',
      'malformed/game_summary_thumbnail_number.json': 'thumbnailUrl',
    };
    cases.forEach((path, key) {
      test('$path throws CheckedFromJsonException for $key', () {
        expect(
          () => GameSummary.fromJson(readFixture(path)),
          throwsA(
            isA<CheckedFromJsonException>().having((e) => e.key, 'key', key),
          ),
        );
      });
    });

    test('a missing bggId fails naming bggId', () {
      expect(
        () => GameSummary.fromJson({'name': 'n', 'bggUrl': 'u'}),
        throwsA(
          isA<CheckedFromJsonException>().having((e) => e.key, 'key', 'bggId'),
        ),
      );
    });

    test('the error message does not echo the rejected value', () {
      try {
        GameSummary.fromJson(
          readFixture('malformed/game_summary_bgg_id_negative.json'),
        );
        fail('expected CheckedFromJsonException');
      } on CheckedFromJsonException catch (e) {
        expect(e.innerError.toString(), isNot(contains('-13')));
      }
    });

    test('a whole-valued double such as 13.0 decodes as 13', () {
      final game = GameSummary.fromJson(
        readFixture('variants/game_summary_whole_double_id.json'),
      );
      expect(game.bggId, 13);
      expect(game.toJson()['bggId'], isA<int>());
    });

    test('infinity and NaN are not whole numbers', () {
      for (final bad in [double.infinity, double.nan]) {
        expect(
          () =>
              GameSummary.fromJson({'bggId': bad, 'name': 'n', 'bggUrl': 'u'}),
          throwsA(isA<CheckedFromJsonException>()),
        );
      }
    });

    test('doubles beyond 2^53 are rejected, not clamped (B1)', () {
      for (final bad in [1e300, 9007199254740992.0, -1e300]) {
        expect(
          () =>
              GameSummary.fromJson({'bggId': bad, 'name': 'n', 'bggUrl': 'u'}),
          throwsA(
            isA<CheckedFromJsonException>().having(
              (e) => e.key,
              'key',
              'bggId',
            ),
          ),
          reason: '$bad',
        );
      }
    });

    test('the largest exact double, 2^53 - 1, is accepted', () {
      final game = GameSummary.fromJson({
        'bggId': 9007199254740991.0,
        'name': 'n',
        'bggUrl': 'u',
      });
      expect(game.bggId, 9007199254740991);
    });

    test('the largest 32-bit id is accepted', () {
      final game = GameSummary.fromJson({
        'bggId': 2147483647,
        'name': 'n',
        'bggUrl': 'u',
      });
      expect(game.bggId, 2147483647);
    });
  });

  group('GameSummary yearPublished', () {
    test('negative years and year 0 decode (whole numbers)', () {
      for (final year in [-2200, 0, 2026]) {
        final game = GameSummary.fromJson({
          'bggId': 1,
          'name': 'n',
          'bggUrl': 'u',
          'yearPublished': year,
        });
        expect(game.yearPublished, year);
      }
    });

    test('a string year fails naming yearPublished', () {
      expect(
        () => GameSummary.fromJson({
          'bggId': 1,
          'name': 'n',
          'bggUrl': 'u',
          'yearPublished': '1995',
        }),
        throwsA(
          isA<CheckedFromJsonException>().having(
            (e) => e.key,
            'key',
            'yearPublished',
          ),
        ),
      );
    });
  });

  group('GameSummary value semantics', () {
    test('equality, hashCode, copyWith, and toString', () {
      const a = GameSummary(bggId: 13, name: 'Catan', bggUrl: 'u');
      const b = GameSummary(bggId: 13, name: 'Catan', bggUrl: 'u');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.copyWith(yearPublished: 1995).yearPublished, 1995);
      expect(a.copyWith(name: 'Other'), isNot(a));
      expect(a.toString(), contains('Catan'));
    });
  });
}
