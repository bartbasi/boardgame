// T-028 review R1-S2: bggUrl reaches the domain only as an https link to
// boardgamegeek.com (decisions.md 2026-10-14, T-018). Anything else breaks
// the contract and gives UnexpectedFailure.
import 'dart:convert';

import 'package:board_game_collector/core/domain/result.dart';
import 'package:board_game_collector/features/game_detail/data/game_dto_mapper.dart';
import 'package:board_game_collector/features/game_detail/data/games_remote_data_source.dart';
import 'package:board_game_collector/features/scanner/domain/barcode.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_http.dart';

const List<String> _accepted = [
  'https://boardgamegeek.com/boardgame/13',
  'https://BoardGameGeek.com/boardgame/13',
  'https://boardgamegeek.com:443/boardgame/13',
  // The path is the backend's to choose (api_contract README).
  'https://boardgamegeek.com/boardgame/13/catan',
  'https://boardgamegeek.com/',
];

const List<String> _refused = [
  '',
  'boardgamegeek.com/boardgame/13',
  '/boardgame/13',
  'http://boardgamegeek.com/boardgame/13',
  'ftp://boardgamegeek.com/boardgame/13',
  'javascript:alert(1)',
  'https://www.boardgamegeek.com/boardgame/13',
  'https://boardgamegeek.com.evil.test/boardgame/13',
  'https://evil.test/boardgamegeek.com/boardgame/13',
  'https://ebay.com/itm/1',
  'https://user@boardgamegeek.com/boardgame/13',
  'https://boardgamegeek.com:8443/boardgame/13',
  'https://[::1/',
  'https:///boardgame/13',
];

GamesRemoteDataSource _source(FakeHttpAdapter adapter) =>
    GamesRemoteDataSource(fakeClient(adapter, random: FixedRandom(0)));

Map<String, dynamic> _summary(String url) => {
  'bggId': 13,
  'name': 'Catan',
  'yearPublished': 1995,
  'bggUrl': url,
};

void main() {
  group('checkedBggUrl', () {
    for (final url in _accepted) {
      test('accepts "$url" unchanged', () {
        expect(checkedBggUrl(url), url);
      });
    }
    for (final url in _refused) {
      test('refuses "$url"', () {
        expect(() => checkedBggUrl(url), throwsFormatException);
      });
    }
  });

  group('a bad bggUrl from the backend is the unexpected failure', () {
    const bad = 'https://evil.test/boardgame/13';

    test('in a lookup game', () {
      final body = jsonEncode({
        'code': '0036000291452',
        'status': 'matched',
        'games': [_summary(bad)],
      });
      final adapter = FakeHttpAdapter([respond(200, body: body)]);
      final t = runFake(
        () =>
            _source(adapter)
                .lookupBarcode(Barcode.parse('036000291452').valueOrNull!),
      );
      expect(t.result.failureOrNull, const UnexpectedFailure());
      expect(adapter.requests, hasLength(1));
    });

    test('in one search result among good ones', () {
      final body = jsonEncode({
        'query': 'catan',
        'games': [
          _summary('https://boardgamegeek.com/boardgame/13'),
          _summary('http://boardgamegeek.com/boardgame/13'),
        ],
      });
      final adapter = FakeHttpAdapter([respond(200, body: body)]);
      final t = runFake(() => _source(adapter).searchGames('catan'));
      expect(t.result.failureOrNull, const UnexpectedFailure());
    });

    test('in game details', () {
      final json = jsonDecode(
        contractFixture('game_detail/full.json'),
      ) as Map<String, dynamic>;
      json['bggUrl'] = bad;
      final adapter = FakeHttpAdapter([respond(200, body: jsonEncode(json))]);
      final t = runFake(() => _source(adapter).fetchGame(13));
      expect(t.result.failureOrNull, const UnexpectedFailure());
    });

    test('a good bggUrl still maps', () {
      final adapter = FakeHttpAdapter([
        respond(200, body: contractFixture('game_detail/full.json')),
      ]);
      final t = runFake(() => _source(adapter).fetchGame(13));
      expect(
        t.result.valueOrNull?.bggUrl,
        'https://boardgamegeek.com/boardgame/13',
      );
      expect(t.result, isA<Ok<Object>>());
    });
  });
}
