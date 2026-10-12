import 'dart:convert';

import 'package:boardgame_server/boardgame_server.dart';
import 'package:test/test.dart';

import '../support/harness.dart';

void main() {
  group('Logger', () {
    test('writes one JSON object per call with ts, level, msg, and fields', () {
      final logs = LogCapture();

      logs.logger().info('hello', {'count': 3, 'ok': true, 'none': null});

      expect(logs.records.single, {
        'ts': '2026-10-12T14:30:05.123Z',
        'level': 'info',
        'msg': 'hello',
        'count': 3,
        'ok': true,
        'none': null,
      });
    });

    test('drops lines below the minimum level', () {
      final logs = LogCapture();
      final logger = logs.logger(minLevel: LogLevel.warning);

      logger
        ..debug('d')
        ..info('i')
        ..warning('w')
        ..error('e');

      expect(logs.records.map((r) => r['level']), ['warning', 'error']);
      expect(logger.isEnabled(LogLevel.info), isFalse);
      expect(logger.isEnabled(LogLevel.error), isTrue);
    });

    test('debug lines appear at debug level', () {
      final logs = LogCapture();

      logs.logger().debug('d', {'k': 'v'});

      expect(logs.records.single['level'], 'debug');
      expect(logs.records.single['k'], 'v');
    });

    test('fields cannot overwrite ts, level, or msg', () {
      final logs = LogCapture();

      logs.logger().info('real', {
        'ts': 'fake',
        'level': 'fake',
        'msg': 'fake',
        'extra': 1,
      });

      final record = logs.records.single;
      expect(record['ts'], '2026-10-12T14:30:05.123Z');
      expect(record['level'], 'info');
      expect(record['msg'], 'real');
      expect(record['extra'], 1);
    });

    test('a multi-line stack trace stays on one line', () {
      final logs = LogCapture();
      final trace = StackTrace.fromString('#0 a (x.dart:1)\n#1 b (y.dart:2)\n');

      logs.logger().error(
        'failed',
        error: StateError('bad'),
        stackTrace: trace,
        fields: {'route': '/v1/x'},
      );

      expect(logs.lines.single, isNot(contains('\n')));
      final record = logs.records.single;
      expect(record['error'], 'Bad state: bad');
      expect(record['stack'], trace.toString());
      expect(record['route'], '/v1/x');
    });

    test('values that are not JSON types are written with toString', () {
      final logs = LogCapture();

      logs.logger().info('x', {'duration': const Duration(seconds: 1)});

      expect(logs.records.single['duration'], '0:00:01.000000');
      expect(() => jsonDecode(logs.lines.single), returnsNormally);
    });

    test('LogLevel.tryParse accepts exact names only', () {
      expect(LogLevel.tryParse('warning'), LogLevel.warning);
      expect(LogLevel.tryParse('WARNING'), isNull);
      expect(LogLevel.tryParse(''), isNull);
    });
  });
}
