// T-028 QA round 2: bggUrl variants. The app opens this link outside the
// app, so anything that is not an https link to boardgamegeek.com must be
// refused in all four answers (summary in lookup and search, detail).
import 'dart:convert';

import 'package:board_game_collector/core/domain/result.dart';
import 'package:board_game_collector/features/game_detail/data/game_dto_mapper.dart';
import 'package:board_game_collector/features/game_detail/data/games_remote_data_source.dart';
import 'package:board_game_collector/features/scanner/domain/barcode.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_http.dart';

/// Links that must be accepted, as sent.
const List<String> _accepted = [
  'https://boardgamegeek.com/boardgame/13',
  'https://BOARDGAMEGEEK.COM/boardgame/13',
  'HTTPS://boardgamegeek.com/boardgame/13',
  'HtTpS://BoardGameGeek.com/boardgame/13',
  'https://boardgamegeek.com:443/boardgame/13',
  'https://boardgamegeek.com',
  'https://boardgamegeek.com/boardgame/13?x=1#top',
  'https://boardgamegeek.com/boardgame/13/caf%C3%A9',
];

/// Links that must be refused.
const Map<String, String> _refused = {
  'http': 'http://boardgamegeek.com/boardgame/13',
  'http uppercase': 'HTTP://BOARDGAMEGEEK.COM/boardgame/13',
  'trailing dot host': 'https://boardgamegeek.com./boardgame/13',
  'port 8443': 'https://boardgamegeek.com:8443/boardgame/13',
  'port 80': 'https://boardgamegeek.com:80/boardgame/13',
  'port 0': 'https://boardgamegeek.com:0/boardgame/13',
  'user info': 'https://user@boardgamegeek.com/boardgame/13',
  'user and password': 'https://user:pw@boardgamegeek.com/boardgame/13',
  'host as user info': 'https://boardgamegeek.com@evil.example/boardgame/13',
  'host and port as user info': 'https://boardgamegeek.com:443@evil.example/',
  'suffix host': 'https://boardgamegeek.com.evil.example/boardgame/13',
  'prefix host': 'https://evilboardgamegeek.com/boardgame/13',
  'subdomain': 'https://api.boardgamegeek.com/boardgame/13',
  'www': 'https://www.boardgamegeek.com/boardgame/13',
  'hyphen look-alike': 'https://boardgame-geek.com/boardgame/13',
  'IDN Cyrillic a': 'https://boаrdgamegeek.com/boardgame/13',
  'IDN Cyrillic o': 'https://bоardgamegeek.com/boardgame/13',
  'IDN fullwidth dot': 'https://boardgamegeek．com/boardgame/13',
  'IDN ideographic dot': 'https://boardgamegeek。com/boardgame/13',
  'punycode look-alike': 'https://xn--boardgamegeek-9x0e.com/boardgame/13',
  'zero width space': 'https://board​gamegeek.com/boardgame/13',
  'relative path': '/boardgame/13',
  'relative no slash': 'boardgame/13',
  'host only': 'boardgamegeek.com/boardgame/13',
  'scheme relative': '//boardgamegeek.com/boardgame/13',
  'empty': '',
  'whitespace only': '   ',
  'leading space': ' https://boardgamegeek.com/boardgame/13',
  'leading newline': '\nhttps://boardgamegeek.com/boardgame/13',
  'leading tab': '\thttps://boardgamegeek.com/boardgame/13',
  'space in host': 'https://boardgamegeek .com/boardgame/13',
  'backslash after host': r'https://evil.example\@boardgamegeek.com/x',
  'backslash scheme': r'https:\boardgamegeek.com\boardgame\13',
  'tab inside scheme': 'ht\ttps://boardgamegeek.com/boardgame/13',
  'newline in host': 'https://boardgamegeek.com\n.evil.example/',
  'ipv4': 'https://127.0.0.1/boardgame/13',
  'ipv6': 'https://[::1]/boardgame/13',
  'localhost': 'https://localhost/boardgame/13',
  'javascript': 'javascript:alert(1)',
  'data': 'data:text/html,hi',
  'file': 'file:///etc/passwd',
  'intent': 'intent://boardgamegeek.com/#Intent;scheme=https;end',
  'mailto': 'mailto:a@boardgamegeek.com',
  'ebay': 'https://www.ebay.com/itm/1',
  'https no slashes': 'https:boardgamegeek.com/boardgame/13',
  'https one slash': 'https:/boardgamegeek.com/boardgame/13',
  'https four slashes': 'https:////boardgamegeek.com/boardgame/13',
  'bgg in query': 'https://evil.example/?u=https://boardgamegeek.com/',
  'bgg in fragment': 'https://evil.example/#boardgamegeek.com',
};

Map<String, dynamic> _summary(String url) => {
  'bggId': 13,
  'name': 'Catan',
  'yearPublished': 1995,
  'bggUrl': url,
};

GamesRemoteDataSource _source(FakeHttpAdapter a) =>
    GamesRemoteDataSource(fakeClient(a, random: FixedRandom(0)));

/// Serves [url] in each of the four answers and returns the four results.
Map<String, Result<Object>> _all(String url) {
  final detail = jsonDecode(
    contractFixture('game_detail/full.json'),
  ) as Map<String, dynamic>..['bggUrl'] = url;
  final lookup = jsonEncode({
    'code': '0036000291452',
    'status': 'matched',
    'games': [_summary(url)],
  });
  final search = jsonEncode({
    'query': 'catan',
    'games': [_summary(url)],
  });
  Result<Object> run(
    String body,
    Future<Result<Object>> Function(GamesRemoteDataSource) call,
  ) {
    final adapter = FakeHttpAdapter([respond(200, body: body)]);
    final t = runFake(() => call(_source(adapter)));
    expect(adapter.requests, hasLength(1), reason: 'never retried');
    return t.result;
  }

  return {
    'lookup': run(
      lookup,
      (s) => s.lookupBarcode(Barcode.parse('036000291452').valueOrNull!),
    ),
    'search': run(search, (s) => s.searchGames('catan')),
    'detail': run(jsonEncode(detail), (s) => s.fetchGame(13)),
  };
}

void main() {
  sameHostTests();
  group('accepted links', () {
    for (final url in _accepted) {
      test('checkedBggUrl accepts ${jsonEncode(url)}', () {
        expect(checkedBggUrl(url), url);
      });
    }
    test('all three answers carry an accepted link through unchanged', () {
      for (final url in _accepted) {
        final results = _all(url);
        for (final e in results.entries) {
          expect(e.value.isOk, isTrue, reason: '${e.key} ${jsonEncode(url)}');
        }
      }
    });
  });

  group('refused links give UnexpectedFailure in every answer', () {
    for (final e in _refused.entries) {
      test('${e.key}: ${jsonEncode(e.value)}', () {
        expect(
          () => checkedBggUrl(e.value),
          throwsFormatException,
          reason: 'checkedBggUrl',
        );
        final results = _all(e.value);
        for (final r in results.entries) {
          expect(
            r.value.failureOrNull,
            const UnexpectedFailure(),
            reason: r.key,
          );
        }
      });
    }
  });

  group('one bad link spoils the whole answer', () {
    test('a good game first and a bad one last in a search', () {
      final body = jsonEncode({
        'query': 'catan',
        'games': [
          _summary('https://boardgamegeek.com/boardgame/13'),
          _summary('https://boardgamegeek.com/boardgame/14'),
          _summary('https://boardgamegeek.com.evil.example/boardgame/15'),
        ],
      });
      final adapter = FakeHttpAdapter([respond(200, body: body)]);
      final t = runFake(() => _source(adapter).searchGames('catan'));
      expect(t.result.failureOrNull, const UnexpectedFailure());
    });

    test('a bad link in a candidates lookup', () {
      final body = jsonEncode({
        'code': '0036000291452',
        'status': 'candidates',
        'games': [
          _summary('https://boardgamegeek.com/boardgame/13'),
          _summary('http://boardgamegeek.com/boardgame/14'),
        ],
      });
      final adapter = FakeHttpAdapter([respond(200, body: body)]);
      final t = runFake(
        () =>
            _source(adapter)
                .lookupBarcode(Barcode.parse('036000291452').valueOrNull!),
      );
      expect(t.result.failureOrNull, const UnexpectedFailure());
    });

    test('a non-string bggUrl is the unexpected failure', () {
      for (final bad in [null, 5, true, <Object>[], <String, Object>{}]) {
        final body = jsonEncode({
          'query': 'catan',
          'games': [
            {..._summary('x'), 'bggUrl': bad},
          ],
        });
        final adapter = FakeHttpAdapter([respond(200, body: body)]);
        final t = runFake(() => _source(adapter).searchGames('catan'));
        expect(
          t.result.failureOrNull,
          const UnexpectedFailure(),
          reason: '$bad',
        );
      }
    });
  });
}

/// Odd links that Dart's Uri still reads as host boardgamegeek.com on
/// port 443. They are accepted, which is safe because the host is BGG
/// whichever way a parser reads them (T-028 QA round 2 observations).
const Map<String, String> _sameHost = {
  'empty user info': 'https://@boardgamegeek.com/boardgame/13',
  'trailing space': 'https://boardgamegeek.com/boardgame/13 ',
  'trailing newline': 'https://boardgamegeek.com/boardgame/13\n',
  'backslash after host': r'https://boardgamegeek.com\.evil.example/x',
};

void sameHostTests() {
  group('odd links that still point at boardgamegeek.com', () {
    for (final e in _sameHost.entries) {
      test('${e.key}: the host stays boardgamegeek.com', () {
        final url = checkedBggUrl(e.value);
        final uri = Uri.parse(url);
        expect(uri.scheme, 'https');
        expect(uri.host, 'boardgamegeek.com');
        expect(uri.userInfo, isEmpty);
        expect(uri.port, 443);
      });
    }
  });
}
