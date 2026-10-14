import 'package:boardgame_server/boardgame_server.dart';
import 'package:test/test.dart';

const _valid = {
  'DATABASE_HOST': 'postgres',
  'DATABASE_PORT': '5433',
  'DATABASE_NAME': 'boardgame',
  'DATABASE_USER': 'app',
  'DATABASE_PASSWORD': 'pw-Unit-T019-77',
  'DATABASE_POOL_MAX': '7',
};

ConfigException _failure(Map<String, String> env) {
  try {
    DatabaseConfig.load(env);
  } on ConfigException catch (e) {
    return e;
  }
  fail('expected ConfigException');
}

void main() {
  group('DatabaseConfig.load (T-019 AC4)', () {
    test('reads every variable', () {
      final config = DatabaseConfig.load(_valid);
      expect(config.host, 'postgres');
      expect(config.port, 5433);
      expect(config.name, 'boardgame');
      expect(config.user, 'app');
      expect(config.password, 'pw-Unit-T019-77');
      expect(config.poolMax, 7);
    });

    test('DATABASE_PORT defaults to 5432 when missing or empty', () {
      expect(
        DatabaseConfig.load({..._valid}..remove('DATABASE_PORT')).port,
        5432,
      );
      expect(DatabaseConfig.load({..._valid, 'DATABASE_PORT': ' '}).port, 5432);
    });

    test('each required variable is named when missing, all in one error', () {
      final e = _failure({});
      expect(e.problems, hasLength(4));
      for (final key in [
        'DATABASE_HOST',
        'DATABASE_NAME',
        'DATABASE_USER',
        'DATABASE_PASSWORD',
      ]) {
        expect(e.message, contains('$key is missing'));
      }
    });

    for (final (key, bad) in [
      ('DATABASE_HOST', 'two words'),
      ('DATABASE_HOST', 'a/b'),
      ('DATABASE_HOST', 'h' * 254),
      ('DATABASE_PORT', '0'),
      ('DATABASE_PORT', '65536'),
      ('DATABASE_PORT', 'abc'),
      ('DATABASE_NAME', 'n' * 64),
      ('DATABASE_NAME', 'tab\there'),
      ('DATABASE_USER', 'é' * 32), // 64 bytes in UTF-8
    ]) {
      test('$key=${bad.length > 20 ? '<${bad.length} chars>' : bad} is '
          'invalid and not echoed', () {
        final e = _failure({..._valid, key: bad});
        expect(e.problems.single, startsWith('$key is invalid'));
        expect(e.message, isNot(contains(bad)));
      });
    }

    test('a 63-byte name and an IPv6 host are accepted', () {
      final config = DatabaseConfig.load({
        ..._valid,
        'DATABASE_NAME': 'n' * 63,
        'DATABASE_HOST': '[::1]',
      });
      expect(config.name, hasLength(63));
      expect(config.host, '[::1]');
    });

    test('the password is never in an error, even when every other value '
        'is invalid', () {
      final e = _failure({
        'DATABASE_HOST': 'bad host',
        'DATABASE_PORT': 'x',
        'DATABASE_NAME': '',
        'DATABASE_USER': '',
        'DATABASE_PASSWORD': 'pw-Unit-T019-77',
        'DATABASE_POOL_MAX': 'y',
      });
      expect(e.message, isNot(contains('pw-Unit-T019-77')));
      expect(e.toString(), isNot(contains('pw-Unit-T019-77')));
      expect(e.message, isNot(contains('DATABASE_PASSWORD')));
    });

    test('a password of only spaces counts as missing', () {
      final e = _failure({..._valid, 'DATABASE_PASSWORD': '   '});
      expect(
        e.problems.single,
        'DATABASE_PASSWORD is missing; it must be set.',
      );
    });

    test('a password keeps its spaces and special characters', () {
      final config = DatabaseConfig.load({
        ..._valid,
        'DATABASE_PASSWORD': ' p@ss w0rd# ',
      });
      expect(config.password, ' p@ss w0rd# ');
    });

    test('toString redacts the password', () {
      final text = DatabaseConfig.load(_valid).toString();
      expect(text, contains('<redacted>'));
      expect(text, isNot(contains('pw-Unit-T019-77')));
      expect(text, contains('postgres'));
    });
  });

  group('DATABASE_POOL_MAX (T-019 AC5)', () {
    test('defaults to 5 when missing or empty', () {
      expect(DatabaseConfig.defaultPoolMax, 5);
      expect(
        DatabaseConfig.load({..._valid}..remove('DATABASE_POOL_MAX')).poolMax,
        5,
      );
      expect(
        DatabaseConfig.load({..._valid, 'DATABASE_POOL_MAX': ''}).poolMax,
        5,
      );
    });

    test('comes from config, from 1 to 20', () {
      for (final n in [1, 2, 12, 20]) {
        expect(
          DatabaseConfig.load({..._valid, 'DATABASE_POOL_MAX': '$n'}).poolMax,
          n,
        );
      }
    });

    for (final bad in ['0', '21', '-1', '5.0', 'five', '100000']) {
      test('DATABASE_POOL_MAX=$bad is invalid', () {
        final e = _failure({..._valid, 'DATABASE_POOL_MAX': bad});
        expect(e.problems.single, startsWith('DATABASE_POOL_MAX is invalid'));
        expect(e.problems.single, contains('1 to 20'));
      });
    }
  });
}
