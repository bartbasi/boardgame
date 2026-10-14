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
      expect(text, contains('search?<redacted>'));
      expect(text, contains('https://<redacted>@boardgamegeek.com'));
      expect(text, contains('then stop'));
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
