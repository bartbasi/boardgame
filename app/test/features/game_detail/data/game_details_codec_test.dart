// T-029: game details are cached as the backend's game detail JSON and
// read back through the same decoder and mapper as a fresh answer.
import 'dart:convert';

import 'package:api_contract/api_contract.dart' show CheckedFromJsonException;
import 'package:board_game_collector/features/game_detail/data/game_details_codec.dart';
import 'package:board_game_collector/features/game_detail/domain/game_details.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_games.dart';

void main() {
  group('round trip', () {
    for (final fixture in [
      'game_detail/full.json',
      'game_detail/minimal.json',
      'variants/game_detail_optional_fields_absent.json',
    ]) {
      test(fixture, () {
        final details = detailsFixture(fixture);
        expect(decodeCachedDetails(encodeCachedDetails(details)), details);
      });
    }

    test('the cached JSON has the contract field names and a UTC time', () {
      final json = jsonDecode(
        encodeCachedDetails(detailsFixture('game_detail/full.json')),
      ) as Map<String, dynamic>;
      expect(json['bggId'], 13);
      expect(json['name'], 'Catan');
      expect(json['minPlayTimeMinutes'], 60);
      expect(json['fetchedAt'], '2026-10-13T08:15:30.000Z');
    });

    test('a fixture file read as cached text decodes', () {
      expect(
        decodeCachedDetails(
          '{"bggId": 13, "name": "Catan", '
          '"bggUrl": "https://boardgamegeek.com/boardgame/13", '
          '"fetchedAt": "2026-10-13T08:15:30.000Z"}',
        ),
        GameDetails(
          bggId: 13,
          name: 'Catan',
          designers: const [],
          publishers: const [],
          bggUrl: 'https://boardgamegeek.com/boardgame/13',
          fetchedAt: DateTime.utc(2026, 10, 13, 8, 15, 30),
        ),
      );
    });
  });

  group('unusable cached text throws', () {
    test('not JSON', () {
      expect(() => decodeCachedDetails('{"bggId": 13'), throwsFormatException);
    });

    test('JSON that is not an object', () {
      expect(() => decodeCachedDetails('[1, 2]'), throwsFormatException);
      expect(() => decodeCachedDetails('null'), throwsFormatException);
    });

    test('a missing required field', () {
      expect(
        () => decodeCachedDetails('{"bggId": 13, "name": "Catan"}'),
        throwsA(isA<CheckedFromJsonException>()),
      );
    });

    test('a BGG link to another host', () {
      final details = detailsFixture('game_detail/full.json')
          .copyWith(bggUrl: 'https://evil.example/boardgame/13');
      expect(
        () => decodeCachedDetails(encodeCachedDetails(details)),
        throwsFormatException,
      );
    });
  });
}
