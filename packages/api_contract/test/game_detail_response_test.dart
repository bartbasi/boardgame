import 'package:api_contract/api_contract.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

/// T-018 AC4 and AC9: game detail fields, nullable where BGG may omit them,
/// fetchedAt in UTC, and the server-built BGG URL.
void main() {
  group('GameDetailResponse round trip (T-018 AC4, AC9)', () {
    for (final path in listFixtures('game_detail')) {
      test('$path decodes and encodes back to the same JSON', () {
        final json = readFixture(path);
        expect(GameDetailResponse.fromJson(json).toJson(), equals(json));
      });
    }

    test('full.json has every field', () {
      final game = GameDetailResponse.fromJson(
        readFixture('game_detail/full.json'),
      );
      expect(game.bggId, 13);
      expect(game.name, 'Catan');
      expect(game.yearPublished, 1995);
      expect(game.minPlayers, 3);
      expect(game.maxPlayers, 4);
      expect(game.minPlayTimeMinutes, 60);
      expect(game.maxPlayTimeMinutes, 120);
      expect(game.designers, ['Example Designer']);
      expect(game.publishers, ['Example Publisher A', 'Example Publisher B']);
      expect(game.description, contains('\n\nSecond paragraph'));
      expect(game.description, contains('日本語'));
      expect(game.bggUrl, 'https://boardgamegeek.com/boardgame/13');
      expect(game.fetchedAt, DateTime.utc(2026, 10, 13, 8, 15, 30));
      expect(game.fetchedAt.isUtc, isTrue);
    });
  });

  group('Every optional field missing (T-018 AC4)', () {
    final expected = GameDetailResponse(
      bggId: 424242,
      name: 'Example Game With No Details',
      bggUrl: 'https://boardgamegeek.com/boardgame/424242',
      fetchedAt: DateTime.utc(2026, 10, 6, 23, 59, 59),
    );

    test('minimal.json (explicit nulls and empty lists) decodes', () {
      final game = GameDetailResponse.fromJson(
        readFixture('game_detail/minimal.json'),
      );
      expect(game, expected);
    });

    test('absent keys decode the same as explicit nulls', () {
      final game = GameDetailResponse.fromJson(
        readFixture('variants/game_detail_optional_fields_absent.json'),
      );
      expect(game, expected);
      expect(game.toJson(), readFixture('game_detail/minimal.json'));
    });

    test('null designers and publishers decode as empty lists', () {
      final game = GameDetailResponse.fromJson(
        readFixture('variants/game_detail_lists_null.json'),
      );
      expect(game.designers, isEmpty);
      expect(game.publishers, isEmpty);
    });

    test('missing values are null, never 0 or an empty string', () {
      final game = GameDetailResponse.fromJson(
        readFixture('variants/game_detail_optional_fields_absent.json'),
      );
      for (final value in [
        game.yearPublished,
        game.minPlayers,
        game.maxPlayers,
        game.minPlayTimeMinutes,
        game.maxPlayTimeMinutes,
        game.description,
      ]) {
        expect(value, isNull);
      }
    });
  });

  group('fetchedAt is an ISO 8601 UTC timestamp (T-018 AC4)', () {
    test('an explicit offset is accepted and converted to UTC', () {
      final game = GameDetailResponse.fromJson(
        readFixture('variants/game_detail_fetched_at_offset.json'),
      );
      expect(game.fetchedAt, DateTime.utc(2026, 10, 13, 8, 15, 30));
      expect(game.toJson()['fetchedAt'], '2026-10-13T08:15:30.000Z');
    });

    test('a local DateTime is encoded in UTC with a Z suffix', () {
      final local = DateTime(2026, 10, 13, 8, 15, 30);
      final json = GameDetailResponse(
        bggId: 1,
        name: 'n',
        bggUrl: 'u',
        fetchedAt: local,
      ).toJson();
      expect(json['fetchedAt'], local.toUtc().toIso8601String());
      expect(json['fetchedAt'] as String, endsWith('Z'));
    });

    test('microseconds survive a round trip', () {
      final at = DateTime.utc(2026, 10, 13, 8, 15, 30, 123, 456);
      final json = GameDetailResponse(
        bggId: 1,
        name: 'n',
        bggUrl: 'u',
        fetchedAt: at,
      ).toJson();
      expect(GameDetailResponse.fromJson(json).fetchedAt, at);
    });
  });

  group('GameDetailResponse invalid input (T-018 AC4)', () {
    final cases = {
      'malformed/game_detail_fetched_at_missing.json': 'fetchedAt',
      'malformed/game_detail_fetched_at_no_zone.json': 'fetchedAt',
      'malformed/game_detail_fetched_at_not_a_date.json': 'fetchedAt',
      'malformed/game_detail_fetched_at_number.json': 'fetchedAt',
      'malformed/game_detail_min_players_zero.json': 'minPlayers',
      'malformed/game_detail_max_play_time_string.json': 'maxPlayTimeMinutes',
      'malformed/game_detail_designers_null_entry.json': 'designers',
      'malformed/game_detail_publishers_string.json': 'publishers',
      'malformed/game_detail_description_number.json': 'description',
    };
    cases.forEach((path, key) {
      test('$path throws CheckedFromJsonException for $key', () {
        expect(
          () => GameDetailResponse.fromJson(readFixture(path)),
          throwsA(
            isA<CheckedFromJsonException>().having((e) => e.key, 'key', key),
          ),
        );
      });
    });

    test('every positive count field rejects 0 and negatives', () {
      final full = readFixture('game_detail/full.json');
      for (final key in [
        'bggId',
        'minPlayers',
        'maxPlayers',
        'minPlayTimeMinutes',
        'maxPlayTimeMinutes',
      ]) {
        for (final bad in [0, -1]) {
          expect(
            () => GameDetailResponse.fromJson({...full, key: bad}),
            throwsA(
              isA<CheckedFromJsonException>().having((e) => e.key, 'key', key),
            ),
            reason: '$key = $bad',
          );
        }
      }
    });

    test('a missing name or bggUrl fails naming the field', () {
      final full = readFixture('game_detail/full.json');
      for (final key in ['name', 'bggUrl', 'bggId']) {
        expect(
          () => GameDetailResponse.fromJson({...full}..remove(key)),
          throwsA(
            isA<CheckedFromJsonException>().having((e) => e.key, 'key', key),
          ),
        );
      }
    });
  });

  group('GameDetailResponse unknown fields', () {
    test('extra fields are ignored', () {
      final game = GameDetailResponse.fromJson(
        readFixture('variants/game_detail_extra_field.json'),
      );
      expect(game.toJson(), readFixture('game_detail/full.json'));
    });
  });

  group('GameDetailResponse value semantics', () {
    test('equality, copyWith, toString, and unmodifiable lists', () {
      final a = GameDetailResponse.fromJson(
        readFixture('game_detail/full.json'),
      );
      final b = GameDetailResponse.fromJson(
        readFixture('game_detail/full.json'),
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.copyWith(maxPlayers: 6).maxPlayers, 6);
      expect(a.copyWith(designers: const []), isNot(a));
      expect(a.toString(), contains('Catan'));
      expect(() => a.designers.add('x'), throwsUnsupportedError);
    });
  });
}
