import 'package:boardgame_server/boardgame_server.dart';
import 'package:test/test.dart';

const _valid = {'PORT': '8080', 'LOG_LEVEL': 'info'};

ConfigException _failure(Map<String, String> environment) {
  try {
    Config.load(environment);
  } on ConfigException catch (e) {
    return e;
  }
  fail('Config.load did not throw for $environment');
}

void main() {
  group('Config.load', () {
    test('reads a valid environment', () {
      final config = Config.load(_valid);

      expect(config.port, 8080);
      expect(config.logLevel, LogLevel.info);
    });

    test('accepts every log level name', () {
      for (final level in LogLevel.values) {
        final config = Config.load({..._valid, 'LOG_LEVEL': level.name});
        expect(config.logLevel, level);
      }
    });

    test('accepts ports 1 and 65535 and trims whitespace', () {
      expect(Config.load({..._valid, 'PORT': '1'}).port, 1);
      expect(Config.load({..._valid, 'PORT': ' 65535 '}).port, 65535);
    });

    test('ignores unrelated variables', () {
      final config = Config.load({..._valid, 'PATH': '/usr/bin', 'HOME': '/'});

      expect(config.port, 8080);
    });
  });

  group('missing variables (T-008 AC4)', () {
    test('PORT unset fails and names PORT', () {
      final error = _failure({'LOG_LEVEL': 'info'});

      expect(error.problems, hasLength(1));
      expect(error.message, contains('PORT is missing'));
    });

    test('an empty or blank value counts as missing', () {
      expect(
        _failure({..._valid, 'PORT': ''}).message,
        contains('PORT is missing'),
      );
      expect(
        _failure({..._valid, 'LOG_LEVEL': '   '}).message,
        contains('LOG_LEVEL is missing'),
      );
    });

    test('one message names every missing or invalid variable', () {
      final error = _failure({'LOG_LEVEL': 'loud'});

      expect(error.problems, hasLength(2));
      expect(error.message, contains('PORT is missing'));
      expect(error.message, contains('LOG_LEVEL is invalid'));
      expect(error.message, isNot(contains('\n')));
    });

    test('an empty environment names both variables', () {
      final error = _failure({});

      expect(error.message, contains('PORT'));
      expect(error.message, contains('LOG_LEVEL'));
      expect(
        error.toString(),
        startsWith('ConfigException: Invalid configuration:'),
      );
    });

    test('the message never contains a variable value', () {
      const secretPort = 'port-secret-9f3a';
      const secretLevel = 'level-secret-7c1d';

      final error = _failure({'PORT': secretPort, 'LOG_LEVEL': secretLevel});

      expect(error.message, isNot(contains(secretPort)));
      expect(error.message, isNot(contains(secretLevel)));
      expect(error.message, isNot(contains('secret')));
    });
  });

  group('invalid values (T-008 AC5)', () {
    for (final port in [
      'abc',
      '0',
      '65536',
      '-1',
      '80.5',
      '1e3',
      '0x50',
      '999999',
    ]) {
      test('PORT=$port fails naming PORT and its allowed range', () {
        final error = _failure({..._valid, 'PORT': port});

        expect(
          error.problems.single,
          'PORT is invalid; it must be an integer from 1 to 65535.',
        );
      });
    }

    for (final level in ['loud', 'INFO', 'warn', 'trace']) {
      test(
        'LOG_LEVEL=$level fails naming LOG_LEVEL and its allowed values',
        () {
          final error = _failure({..._valid, 'LOG_LEVEL': level});

          expect(
            error.problems.single,
            'LOG_LEVEL is invalid; it must be one of: debug, info, warning, error.',
          );
        },
      );
    }
  });
}
