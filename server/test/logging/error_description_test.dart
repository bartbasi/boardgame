import 'dart:io';

import 'package:boardgame_server/boardgame_server.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

import '../support/harness.dart';

void main() {
  group('describeError (T-008 review R1-S1)', () {
    test('FormatException keeps its message but drops the source input', () {
      final error = FormatException(
        'Invalid radix-10 number',
        'secret-barcode-0123',
        3,
      );

      expect(describeError(error), 'FormatException: Invalid radix-10 number');
    });

    test('a FormatException from int.parse does not log the input', () {
      Object? caught;
      try {
        int.parse('secret-bgg-id');
      } catch (e) {
        caught = e;
      }

      expect(describeError(caught!), isNot(contains('secret')));
    });

    test('HttpException drops its URI, which holds the query string', () {
      final error = HttpException(
        'Connection closed',
        uri: Uri.parse('https://api.example.com/search?q=secret&key=k123'),
      );

      final text = describeError(error);

      expect(text, 'HttpException: Connection closed');
    });

    test('SocketException keeps only its message', () {
      const error = SocketException(
        'Connection refused',
        address: null,
        port: 443,
      );

      expect(describeError(error), 'SocketException: Connection refused');
    });

    test('other errors have URL query strings and user info redacted', () {
      final error = StateError(
        'GET https://user:pass@boardgamegeek.com/xmlapi2/search?query=secret '
        'failed; retry https://x.example/a?token=abc, then stop',
      );

      final text = describeError(error);

      expect(text, isNot(contains('secret')));
      expect(text, isNot(contains('token=abc')));
      expect(text, isNot(contains('user:pass')));
      // T-020 AC8: the path is redacted too (it was kept before T-020).
      // Since round 2 (R1-M1) a URL runs to whitespace, so the comma after
      // the second URL is redacted with it.
      expect(text, isNot(contains('xmlapi2')));
      expect(
        text,
        'Bad state: GET https://<redacted>@boardgamegeek.com/<redacted>'
        '?<redacted> failed; retry https://x.example/<redacted>?<redacted> '
        'then stop',
      );
    });

    test('characters legal in a host or path cannot end the redaction early '
        '(T-020 R1-M1)', () {
      final cases = {
        'http://h.example/a,secret-123': 'http://h.example/<redacted>',
        'http://h.example/a;secret-123': 'http://h.example/<redacted>',
        'http://h.example/a)secret-123': 'http://h.example/<redacted>',
        'http://h.example/a"secret-123': 'http://h.example/<redacted>',
        'http://[2001:db8::1]:8080/v1/games/secret-123':
            'http://[2001:db8::1]:8080/<redacted>',
        'http://[::1]/v1/games/secret-123': 'http://[::1]/<redacted>',
        // A client-chosen Host that is not a plain name is redacted too.
        'http://x;y/v1/games/secret-123': 'http://<redacted>/<redacted>',
        'http://secret-123,x': 'http://<redacted>',
        'http://h.example?q=a,secret-123': 'http://h.example?<redacted>',
        'http://h.example/a?q=1#x,secret-123':
            'http://h.example/<redacted>?<redacted>',
        'http://h.example#a,secret-123': 'http://h.example#<redacted>',
        'http://h.example/?q=secret-123': 'http://h.example/?<redacted>',
        'http://h.example:8080': 'http://h.example:8080',
        'http://u:secret-123@h.example': 'http://<redacted>@h.example',
      };
      for (final MapEntry(:key, :value) in cases.entries) {
        expect(
          describeError(StateError('failed $key now')),
          'Bad state: failed $value now',
          reason: key,
        );
      }
    });

    test('a query string in prose runs to whitespace (T-020 R1-M1)', () {
      expect(
        describeError(StateError('guard failed ?q=a,secret-123 later')),
        'Bad state: guard failed ?<redacted> later',
      );
      expect(
        describeError(StateError('x ?q=a;secret-123')),
        'Bad state: x ?<redacted>',
      );
    });

    test('URL paths are redacted, keeping scheme and host (T-020 AC8)', () {
      expect(
        describeError(
          StateError('guard failed for http://localhost/v1/games/secret-123'),
        ),
        'Bad state: guard failed for http://localhost/<redacted>',
      );
      expect(
        describeError(StateError('x https://h.example:8443/a/b#frag-secret y')),
        'Bad state: x https://h.example:8443/<redacted>#<redacted> y',
      );
      expect(
        describeError(
          StateError('root http://h.example/ and http://h.example'),
        ),
        'Bad state: root http://h.example/ and http://h.example',
      );
    });

    test('ArgumentError logs only name and message, never the invalid value '
        '(T-020 AC8)', () {
      expect(
        describeError(ArgumentError.value('secret-123', 'bggId')),
        'ArgumentError (bggId): Invalid argument',
      );
      expect(
        describeError(
          ArgumentError.value('secret-123', 'bggId', 'must be a number'),
        ),
        'ArgumentError (bggId): must be a number',
      );
      expect(
        describeError(ArgumentError('plain message')),
        'ArgumentError: plain message',
      );
      expect(
        describeError(RangeError.value(987654, 'page', 'too far')),
        'RangeError (page): too far',
      );
      expect(
        describeError(RangeError.range(987654, 1, 5, 'page')),
        isNot(contains('987654')),
      );
      expect(
        describeError(IndexError.withLength(987654, 3, indexable: 'secret')),
        allOf(isNot(contains('987654')), isNot(contains('secret'))),
      );
    });

    test('an error without URLs is kept as is', () {
      expect(
        describeError(StateError('line1\nline2')),
        'Bad state: line1\nline2',
      );
    });

    test('long descriptions are cut to the maximum length', () {
      final text = describeError(StateError('x' * 1000));

      expect(text.length, maxErrorDescriptionLength + 3);
      expect(text, endsWith('...'));
    });

    test('a driver PgException keeps only its type and severity, never the '
        'parameter value its message quotes (T-019 review R1-S2)', () {
      // postgres 3.5.20 text_codec.dart and type_registry.dart throw this
      // text with the parameter value in it.
      final error = PgException(
        "Could not infer type of value 'secret-barcode-0123'.",
      );
      expect(error.toString(), contains('secret-barcode-0123'));

      expect(describeError(error), 'PgException: error');
      expect(
        describeError(
          PgException('connection lost: secret', severity: Severity.fatal),
        ),
        'PgException: fatal',
      );
    });

    test('Logger.error writes errorType, the description, and the stack', () {
      final logs = LogCapture();

      logs.logger().error(
        'failed',
        error: const FormatException('Unexpected character', 'secret-body'),
        stackTrace: StackTrace.current,
      );

      final record = logs.records.single;
      expect(record['errorType'], 'FormatException');
      expect(record['error'], 'FormatException: Unexpected character');
      expect(record['stack'], isA<String>());
      expect(logs.lines.single, isNot(contains('secret')));
    });
  });
}
