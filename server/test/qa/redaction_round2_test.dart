import 'package:boardgame_server/boardgame_server.dart';
import 'package:test/test.dart';

/// QA round 2 for T-020: URL redaction from `scheme://` to whitespace with a
/// strict host check. Pure Dart.
String d(String message) => describeError(StateError(message));
const _p = 'Bad state: ';

void main() {
  const secret = 'secret-123';

  group('exact output', () {
    final cases = <String, String>{
      'https://h.example': 'https://h.example',
      'https://h.example/': 'https://h.example/',
      'https://h.example/a': 'https://h.example/<redacted>',
      'https://h.example/a/b/c': 'https://h.example/<redacted>',
      'https://h.example?q=1': 'https://h.example?<redacted>',
      'https://h.example/?q=1': 'https://h.example/?<redacted>',
      'https://h.example/a?q=1': 'https://h.example/<redacted>?<redacted>',
      'https://h.example#f': 'https://h.example#<redacted>',
      'https://h.example/#f': 'https://h.example/#<redacted>',
      'https://h.example/a#f': 'https://h.example/<redacted>#<redacted>',
      'https://h.example/a?q=1#f': 'https://h.example/<redacted>?<redacted>',
      'https://h.example:8443/a': 'https://h.example:8443/<redacted>',
      'https://h.example:99999': 'https://h.example:99999',
      'https://127.0.0.1:80/a': 'https://127.0.0.1:80/<redacted>',
      'https://[::1]/a': 'https://[::1]/<redacted>',
      'https://[2001:db8::1]:8080/a': 'https://[2001:db8::1]:8080/<redacted>',
      'https://[::ffff:1.2.3.4]/a': 'https://[::ffff:1.2.3.4]/<redacted>',
      'HTTPS://H.EXAMPLE/a': 'HTTPS://H.EXAMPLE/<redacted>',
      'HtTp://h/a': 'HtTp://h/<redacted>',
      'https://xn--mnchen-3ya.de/a': 'https://xn--mnchen-3ya.de/<redacted>',
      'https://u@h.example/a': 'https://<redacted>@h.example/<redacted>',
      'https://u:p@h.example/a': 'https://<redacted>@h.example/<redacted>',
      'https://u:p@w@h.example/a': 'https://<redacted>@h.example/<redacted>',
      'https://u:p:q@h.example:81/a':
          'https://<redacted>@h.example:81/<redacted>',
      'https://:p@h.example': 'https://<redacted>@h.example',
      'https://@h.example': 'https://<redacted>@h.example',
      'https://u@': 'https://<redacted>@',
      'postgres://u:p@db:5432/app': 'postgres://<redacted>@db:5432/<redacted>',
      'ws://h.example/socket?t=1': 'ws://h.example/<redacted>?<redacted>',
      'ftp://h/a': 'ftp://h/<redacted>',
      'file:///etc/passwd': 'file:///<redacted>',
      'https://': 'https://',
      'https:///a': 'https:///<redacted>',
      'a+b-c.d://h/x': 'a+b-c.d://h/<redacted>',
    };
    cases.forEach((input, expected) {
      test(input, () {
        expect(d(input), '$_p$expected');
      });
    });
  });

  group('hosts that are not plain are redacted whole', () {
    for (final host in [
      'x;y',
      'a b'.replaceAll(' ', '%20'),
      '[::1',
      '::1]',
      '[::1]]',
      '[]',
      '[zz]',
      '[::1%25eth0]',
      'h_x',
      'h,x',
      'h(x)',
      'h"x',
      "h'x",
      'h<x>',
      'h\\x',
      'h:',
      'h:abc',
      'h:123456',
      'h:80:80',
      'münchen.de',
      '例え.jp',
      'h.example\u0000',
      'h\u00e9',
      '$secret,x',
      '$secret;x',
      '$secret)x',
      '$secret|x',
      '$secret!x',
      '$secret=x',
      '$secret*x',
      '$secret\$x',
      '$secret~x',
      '$secret%41',
    ]) {
      test('host "$host"', () {
        final text = d('failed https://$host/path-$secret?x=$secret more');
        expect(text, contains('https://<redacted>'));
        expect(text, isNot(contains('secret')), reason: text);
        expect(text, isNot(contains(host)), reason: text);
      });
    }

    test('a space inside what would be a host ends the URL there', () {
      // "a b" is two words; only the first belongs to the URL.
      final text = d('https://a b/secret-9');
      expect(text, contains('https://a'));
      expect(text, contains('b/secret-9'), reason: 'prose after whitespace');
    });
  });

  group('user info', () {
    test('never shown, with @ and : and other characters in it', () {
      for (final info in [
        'user',
        'user:pw',
        'user:p@ss',
        'u:p:q:r',
        '%40:%3A',
        '$secret:$secret',
        'a@b@c',
        ':',
        '@',
        'üser:päss',
        '[x]:y',
      ]) {
        final text = d('https://$info@h.example/a');
        expect(text, isNot(contains('secret')), reason: info);
        expect(text, isNot(contains('pw')), reason: info);
        expect(text, isNot(contains('user')), reason: info);
        expect(text, isNot(contains('ss')), reason: info);
        expect(text, contains('@h.example'), reason: info);
      }
    });

    test('an unencoded slash in a password ends the authority early', () {
      // https://user:pa/ss@h.example/x is not a valid URL. The scanner sees
      // the authority "user:pa" and keeps it only if it looks like host:port.
      final text = d('https://user:pa/ss@h.example/x');
      expect(text, isNot(contains('pa/ss')));
      expect(text, isNot(contains('user')), reason: text);
    });

    test(
      'a numeric "password" before a slash looks like a port (observed)',
      () {
        // user:12345/ss@h.example: authority "user:12345" matches host:port.
        final text = d('https://user:12345/ss@h.example/x');
        expect(text, isNot(contains('ss@h.example')), reason: text);
      },
    );
  });

  group('shape of the surrounding text', () {
    test('URL at the start, middle, and end of the message', () {
      expect(d('https://h/a'), '${_p}https://h/<redacted>');
      expect(d('x https://h/a y'), '${_p}x https://h/<redacted> y');
      expect(d('x https://h/a'), '${_p}x https://h/<redacted>');
    });

    test('several URLs in one message', () {
      final text = d(
        'a https://h1/secret-1 b http://u:p@h2:81/secret-2?x=secret-3 c '
        'ws://h3/secret-4#secret-5 d',
      );
      expect(text, isNot(contains('secret')));
      expect(text, contains('h1'));
      expect(text, contains('h2:81'));
      expect(text, contains('h3'));
      expect(text, endsWith(' d'));
      expect(text, contains(' b '));
    });

    test('adjacent URLs with no space are one URL (fully redacted)', () {
      final text = d('https://h1/a,https://h2/secret-1');
      expect(text, isNot(contains('secret')));
    });

    test('punctuation around a URL is swallowed up to whitespace', () {
      for (final wrap in [
        '(%s)',
        '"%s"',
        "'%s'",
        '<%s>',
        '[%s]',
        '%s.',
        '%s,',
      ]) {
        final text = d(
          'see ${wrap.replaceFirst('%s', 'https://h.example/a/$secret')} end',
        );
        expect(text, isNot(contains('secret')), reason: wrap);
        expect(text, endsWith(' end'), reason: wrap);
      }
    });

    test('a scheme glued to preceding letters is part of the scheme', () {
      final text = d('xhttps://h.example/$secret');
      expect(text, isNot(contains('secret')));
    });

    test('text without a scheme is left alone (documented limit)', () {
      expect(d('games/123 not a url'), '${_p}games/123 not a url');
      expect(d('h.example/path'), '${_p}h.example/path');
      expect(d('mailto:a@b.example'), '${_p}mailto:a@b.example');
    });

    test('a query in prose runs to whitespace', () {
      expect(d('bad ?q=a,b;c)d now'), '${_p}bad ?<redacted> now');
      expect(d('x?q=$secret'), isNot(contains('secret')));
    });

    test('control characters inside a URL path are redacted with it', () {
      final text = d('https://h.example/a\u0000$secret\u0001b');
      expect(text, isNot(contains('secret')));
    });
  });

  group('size and truncation', () {
    test('a one-million-character URL is handled quickly', () {
      final watch = Stopwatch()..start();
      final text = d('https://h.example/${'a' * 1000000}$secret');
      expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
      expect(text, 'Bad state: https://h.example/<redacted>');
    });

    test('a very long host is redacted or kept short, never leaked', () {
      final text = d('https://${'a' * 5000}.example/$secret');
      expect(text, isNot(contains('secret')));
      expect(text.length, lessThanOrEqualTo(maxErrorDescriptionLength + 3));
    });

    test('a hundred thousand URLs in one message finish quickly', () {
      final watch = Stopwatch()..start();
      final text = d(
        List.generate(100000, (i) => 'https://h$i/$secret').join(' '),
      );
      expect(watch.elapsed, lessThan(const Duration(seconds: 3)));
      expect(text, isNot(contains('secret')));
    });

    test('truncation counts redacted text, so a secret cannot reappear', () {
      final text = d('${'x' * 280} https://h.example/$secret-and-more');
      expect(text.length, lessThanOrEqualTo(maxErrorDescriptionLength + 3));
      expect(text, isNot(contains('secret')));
    });

    test('a host that is 253 plain characters is kept; the path is not', () {
      final host = '${'a' * 60}.${'b' * 60}.${'c' * 60}.${'d' * 60}';
      final text = d('https://$host/$secret');
      expect(text, isNot(contains('secret')));
    });
  });

  group('other error kinds still pass through the same redaction', () {
    test('FormatException message with a URL', () {
      expect(
        describeError(
          FormatException('bad https://u:p@h/x?y=$secret', 'src', 1),
        ),
        'FormatException: bad https://<redacted>@h/<redacted>?<redacted>',
      );
    });

    test('ArgumentError message with a URL', () {
      expect(
        describeError(ArgumentError.value('v', 'url', 'bad https://h/$secret')),
        'ArgumentError (url): bad https://h/<redacted>',
      );
    });

    test('a nested exception text with a URL', () {
      final text = describeError(
        Exception('wrapped: ${StateError('https://h:99/$secret')}'),
      );
      expect(text, isNot(contains('secret')));
    });
  });
}
