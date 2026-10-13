import 'package:api_contract/api_contract.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

/// T-018 AC3: the search response has the normalized query and a list of
/// game summaries.
void main() {
  group('SearchResponse round trip (T-018 AC3)', () {
    for (final path in listFixtures('search')) {
      test('$path decodes and encodes back to the same JSON', () {
        final json = readFixture(path);
        expect(SearchResponse.fromJson(json).toJson(), equals(json));
      });
    }

    test('results.json has the query and the games in order', () {
      final response = SearchResponse.fromJson(
        readFixture('search/results.json'),
      );
      expect(response.query, 'catan');
      expect(response.games.map((g) => g.bggId), [13, 424242]);
      expect(response.games.first.name, 'Catan');
      expect(response.games.last.yearPublished, isNull);
    });

    test('empty.json is a valid response with no games', () {
      final response = SearchResponse.fromJson(
        readFixture('search/empty.json'),
      );
      expect(response.games, isEmpty);
    });
  });

  group('SearchResponse invalid input (T-018 AC3)', () {
    final cases = {
      'malformed/search_query_missing.json': 'query',
      'malformed/search_games_missing.json': 'games',
      'malformed/search_game_bgg_id_zero.json': 'bggId',
    };
    cases.forEach((path, key) {
      test('$path throws CheckedFromJsonException for $key', () {
        expect(
          () => SearchResponse.fromJson(readFixture(path)),
          throwsA(
            isA<CheckedFromJsonException>().having((e) => e.key, 'key', key),
          ),
        );
      });
    });

    test('games as an object instead of a list fails naming games', () {
      expect(
        () => SearchResponse.fromJson({
          'query': 'q',
          'games': <String, Object>{},
        }),
        throwsA(
          isA<CheckedFromJsonException>().having((e) => e.key, 'key', 'games'),
        ),
      );
    });
  });

  group('SearchResponse unknown fields', () {
    test('extra fields at both levels are ignored', () {
      final response = SearchResponse.fromJson(
        readFixture('variants/search_extra_field.json'),
      );
      expect(response.toJson(), {
        'query': 'catan',
        'games': [readFixture('search/results.json')['games'][0]],
      });
    });
  });

  group('SearchResponse value semantics', () {
    test('equality, copyWith, toString, and an unmodifiable list', () {
      final a = SearchResponse.fromJson(readFixture('search/results.json'));
      final b = SearchResponse.fromJson(readFixture('search/results.json'));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.copyWith(query: 'x').query, 'x');
      expect(a.toString(), contains('catan'));
      expect(() => a.games.clear(), throwsUnsupportedError);
    });
  });
}
