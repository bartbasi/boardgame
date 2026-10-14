import 'dart:io';

import 'package:boardgame_server/boardgame_server.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

/// QA round 1 for T-020: configuration bounds, startup exit 78, describeError
/// (AC8), and the Compose agreement. Pure Dart, no database.

Map<String, String> _env([Map<String, String> over = const {}]) => {
  'PORT': '8080',
  'LOG_LEVEL': 'info',
  ...over,
};

class _Odd extends ArgumentError {
  _Odd(super.message, [super.name]) : super();
}

void main() {
  group('RATE_LIMIT_PER_MINUTE', () {
    test('default 60, bounds 1 and 10000, trimmed', () {
      expect(Config.load(_env()).rateLimitPerMinute, 60);
      expect(
        Config.load(_env({'RATE_LIMIT_PER_MINUTE': '1'})).rateLimitPerMinute,
        1,
      );
      expect(
        Config.load(_env({'RATE_LIMIT_PER_MINUTE': '10000'}))
            .rateLimitPerMinute,
        10000,
      );
      expect(
        Config.load(_env({'RATE_LIMIT_PER_MINUTE': ' 30 '})).rateLimitPerMinute,
        30,
      );
      expect(
        Config.load(_env({'RATE_LIMIT_PER_MINUTE': ''})).rateLimitPerMinute,
        60,
      );
    });

    for (final bad in [
      '0',
      '10001',
      '-1',
      '+5',
      '60.5',
      '1e2',
      '0x10',
      'sixty',
      '６０',
      '99999999999999999999',
      '60 60',
    ]) {
      test('"$bad" is rejected, named, and not echoed', () {
        expect(
          () => Config.load(_env({'RATE_LIMIT_PER_MINUTE': bad})),
          throwsA(
            isA<ConfigException>().having(
              (e) => e.message,
              'message',
              allOf(
                contains('RATE_LIMIT_PER_MINUTE'),
                isNot(contains(bad.length < 3 ? 'zzz' : bad)),
              ),
            ),
          ),
        );
      });
    }
  });

  group('RATE_LIMIT_MAX_TRACKED_IPS', () {
    test('default 100000, bounds 1 and 200000', () {
      expect(Config.load(_env()).rateLimitMaxTrackedIps, 100000);
      expect(
        Config.load(_env({'RATE_LIMIT_MAX_TRACKED_IPS': '1'}))
            .rateLimitMaxTrackedIps,
        1,
      );
      expect(
        Config.load(_env({'RATE_LIMIT_MAX_TRACKED_IPS': '200000'}))
            .rateLimitMaxTrackedIps,
        200000,
      );
    });

    for (final bad in ['0', '200001', '-5', '1.5', 'many', '1,000']) {
      test('"$bad" is rejected', () {
        expect(
          () => Config.load(_env({'RATE_LIMIT_MAX_TRACKED_IPS': bad})),
          throwsA(
            isA<ConfigException>().having(
              (e) => e.message,
              'message',
              allOf(
                contains('RATE_LIMIT_MAX_TRACKED_IPS'),
                isNot(contains(bad.length < 3 ? 'zzz' : bad)),
              ),
            ),
          ),
        );
      });
    }
  });

  group('TRUSTED_PROXY_ADDRESSES', () {
    List<InternetAddress> load(String v) =>
        Config.load(_env({'TRUSTED_PROXY_ADDRESSES': v})).trustedProxies;

    test('default none; empty and blank mean none', () {
      expect(Config.load(_env()).trustedProxies, isEmpty);
      expect(load(''), isEmpty);
      expect(load('   '), isEmpty);
    });

    test('one, several, spaces, IPv6 in any case', () {
      expect(load('10.213.7.10'), [InternetAddress('10.213.7.10')]);
      expect(load(' 10.0.0.1 , 10.0.0.2 '), hasLength(2));
      expect(load('2001:DB8::1'), [InternetAddress('2001:db8::1')]);
      expect(load('10.0.0.1,2001:db8::1,::ffff:10.0.0.3'), hasLength(3));
      expect(load('10.0.0.1,10.0.0.1'), hasLength(2), reason: 'duplicates ok');
    });

    test('at most 10 entries', () {
      expect(
        load(List.generate(10, (i) => '10.0.0.${i + 1}').join(',')),
        hasLength(10),
      );
      expect(
        () => load(List.generate(11, (i) => '10.0.0.${i + 1}').join(',')),
        throwsA(isA<ConfigException>()),
      );
    });

    final secretish = '203.0.113.99xyz';
    for (final bad in [
      'caddy',
      'localhost',
      '10.0.0.0/24',
      '10.0.0.1,',
      ',10.0.0.1',
      '10.0.0.1,,10.0.0.2',
      '10.0.0.1 10.0.0.2',
      '10.0.0.1;10.0.0.2',
      '10.0.0.256',
      '10.0.0',
      '10.0.0.1:80',
      '[2001:db8::1]',
      '*',
      '0.0.0.0/0',
      secretish,
      'http://10.0.0.1',
    ]) {
      test('"$bad" is rejected, named, and not echoed', () {
        expect(
          () => load(bad),
          throwsA(
            isA<ConfigException>().having(
              (e) => e.message,
              'message',
              allOf(
                contains('TRUSTED_PROXY_ADDRESSES'),
                isNot(contains(bad.isEmpty ? 'zzz' : bad)),
              ),
            ),
          ),
        );
      });
    }

    test('the parsed list cannot be changed afterwards', () {
      final list = load('10.0.0.1');
      expect(
        () => list.add(InternetAddress('1.1.1.1')),
        throwsUnsupportedError,
      );
    });

    test('all bad settings and PORT are named together in one error', () {
      try {
        Config.load({
          'PORT': 'x',
          'LOG_LEVEL': 'info',
          'RATE_LIMIT_PER_MINUTE': '0',
          'RATE_LIMIT_MAX_TRACKED_IPS': '0',
          'TRUSTED_PROXY_ADDRESSES': secretish,
        });
        fail('should throw');
      } on ConfigException catch (e) {
        expect(e.problems, hasLength(4));
        expect(e.message, isNot(contains(secretish)));
        for (final n in [
          'PORT',
          'RATE_LIMIT_PER_MINUTE',
          'RATE_LIMIT_MAX_TRACKED_IPS',
          'TRUSTED_PROXY_ADDRESSES',
        ]) {
          expect(e.message, contains(n));
        }
      }
    });
  });

  test('startup exits 78 for a bad rate limit setting, naming it, before '
      'touching the database', () async {
    final out = <String>[];
    final err = <String>[];
    final code = await runServer(
      environment: {
        ..._env({
          'RATE_LIMIT_PER_MINUTE': '0',
          'TRUSTED_PROXY_ADDRESSES': 'caddy-secret-host',
        }),
        'DATABASE_HOST': 'db.invalid',
        'DATABASE_NAME': 'n',
        'DATABASE_USER': 'u',
        'DATABASE_PASSWORD': 'p',
      },
      shutdownSignals: const Stream.empty(),
      stdoutLine: out.add,
      stderrLine: err.add,
    );
    expect(code, configErrorExitCode);
    expect(out, isEmpty);
    final line = err.join('\n');
    expect(line, contains('RATE_LIMIT_PER_MINUTE'));
    expect(line, contains('TRUSTED_PROXY_ADDRESSES'));
    expect(line, isNot(contains('caddy-secret-host')));
  });

  group('describeError, T-020 AC8', () {
    test('ArgumentError family: name and message, never the value', () {
      const value = 'secret-123';
      final errors = <Object>[
        ArgumentError.value(value, 'bggId', 'must be a number'),
        ArgumentError.value(value, 'bggId'),
        ArgumentError.value(value),
        ArgumentError(value.replaceAll('secret', 'x')),
        ArgumentError.notNull('bggId'),
        RangeError.range(500, 0, 10, 'index'),
        RangeError.value(500, 'index', 'out of range'),
        IndexError.withLength(7, 3, name: 'i'),
        _Odd('bad', 'bggId'),
      ];
      for (final e in errors) {
        final text = describeError(e);
        expect(text, isNot(contains(value)));
        expect(text, isNot(contains('500')), reason: text);
      }
      expect(
        describeError(ArgumentError.value(value, 'bggId', 'must be a number')),
        'ArgumentError (bggId): must be a number',
      );
      expect(
        describeError(ArgumentError.value(value)),
        contains('Invalid argument'),
      );
      expect(
        describeError(RangeError.range(500, 0, 10, 'index')),
        startsWith('RangeError (index)'),
      );
      expect(
        describeError(IndexError.withLength(7, 3, name: 'i')),
        isNot(contains('7')),
      );
    });

    test('an ArgumentError subclass reports its own type', () {
      expect(describeError(_Odd('bad', 'n')), startsWith('_Odd'));
    });

    test('URLs keep scheme and host only', () {
      expect(
        describeError(
          StateError('failed https://api.example.com/v1/games/secret-123'),
        ),
        'Bad state: failed https://api.example.com/<redacted>',
      );
      expect(
        describeError(
          StateError('https://u:pw@h.example:8443/a/b?q=secret#frag'),
        ),
        allOf(
          startsWith(
            'Bad state: https://<redacted>@h.example:8443/<redacted>?<redacted>',
          ),
          isNot(contains('frag')),
          isNot(contains('pw')),
          isNot(contains('secret')),
        ),
      );
      expect(
        describeError(StateError('see HTTPS://H.example/a/secret-1 now')),
        isNot(contains('secret-1')),
      );
      expect(
        describeError(
          StateError('a http://h1/p1/secret-1 b https://h2/p2/secret-2'),
        ),
        allOf(
          isNot(contains('secret-1')),
          isNot(contains('secret-2')),
          contains('h1'),
          contains('h2'),
        ),
      );
      expect(
        describeError(StateError('https://h.example/')),
        'Bad state: https://h.example/',
      );
      expect(
        describeError(StateError('https://h.example')),
        'Bad state: https://h.example',
      );
      expect(
        describeError(StateError('https://h.example?x=secret')),
        isNot(contains('secret')),
      );
    });

    test('a URL followed by punctuation does not leak the path', () {
      for (final tail in ['.', ',', ')', '"', "'", ';', ']', '}', '>']) {
        final text = describeError(
          StateError('open "https://h.example/v1/games/secret-123"$tail done'),
        );
        expect(
          text,
          isNot(contains('secret-123')),
          reason: 'tail $tail: $text',
        );
      }
    });

    test('FormatException, HttpException, SocketException keep message '
        'only, with URLs reduced', () {
      expect(
        describeError(
          FormatException(
            'bad input https://h.example/secret-123',
            'secret-123',
            3,
          ),
        ),
        allOf(isNot(contains('secret-123')), contains('h.example')),
      );
      expect(
        describeError(
          HttpException(
            'failed',
            uri: Uri.parse('https://h.example/secret-123'),
          ),
        ),
        'HttpException: failed',
      );
      expect(
        describeError(
          SocketException(
            'refused',
            address: InternetAddress('203.0.113.9'),
            port: 5,
          ),
        ),
        isNot(contains('203.0.113.9')),
      );
    });

    test('T-019 PgException and ServerException cases are intact', () {
      expect(
        describeError(PgException('Could not infer type of value secret-123')),
        'PgException: error',
      );
      expect(
        describeError(PgException('x secret', severity: Severity.fatal)),
        'PgException: fatal',
      );
    });

    test('truncation applies after redaction and ends in "..."', () {
      final text = describeError(
        StateError('${'x' * 400} https://h.example/secret-123'),
      );
      expect(text.length, maxErrorDescriptionLength + 3);
      expect(text, endsWith('...'));
      expect(text, isNot(contains('secret-123')));
    });

    test('a very long URL path is redacted quickly', () {
      final watch = Stopwatch()..start();
      final text = describeError(
        StateError('https://h.example/${'a/' * 200000}secret-123'),
      );
      expect(text, isNot(contains('secret-123')));
      expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
    });

    // Suspected gaps: the URL pattern stops at characters that are legal in a
    // path, so text after them stays visible. Left as failing tests when the
    // value is exposed (bug entries in the handoff).
    test('IPv6 literal host: the path after "]" is redacted', () {
      final text = describeError(
        StateError('failed http://[2001:db8::1]:8080/v1/games/secret-123'),
      );
      expect(text, isNot(contains('secret-123')), reason: text);
    });

    test('a path with a comma or parenthesis is redacted as a whole', () {
      for (final path in [
        '/a,secret-123',
        '/a;secret-123',
        '/a)secret-123',
        '/a]secret-123',
      ]) {
        final text = describeError(StateError('failed https://h.example$path'));
        expect(text, isNot(contains('secret-123')), reason: '$path -> $text');
      }
    });
  });

  test('the Compose file, the server setting, and the subnet agree on '
      '10.213.7.10', () {
    final compose = File('../deploy/docker-compose.yml');
    if (!compose.existsSync()) {
      markTestSkipped('deploy/docker-compose.yml is not in this checkout');
      return;
    }
    final text = compose.readAsStringSync();
    expect(
      RegExp(r'TRUSTED_PROXY_ADDRESSES:\s*"10\.213\.7\.10"').hasMatch(text),
      isTrue,
    );
    expect(
      RegExp(
        r'ipv4_address:\s*10\.213\.7\.10\s*$',
        multiLine: true,
      ).hasMatch(text),
      isTrue,
    );
    expect(RegExp(r'subnet:\s*10\.213\.7\.0/24').hasMatch(text), isTrue);
    // No other service pins an address, and nothing else trusts a proxy.
    expect(
      RegExp(r'^ +ipv4_address:', multiLine: true).allMatches(text),
      hasLength(1),
    );
    expect(
      RegExp(
        r'^ +TRUSTED_PROXY_ADDRESSES:',
        multiLine: true,
      ).allMatches(text).length,
      1,
    );
    // The server must not publish a port to the host (Caddy is the front).
    final serverBlock = RegExp(
      r'\n  server:\n(.*?)\n  \w+:\n',
      dotAll: true,
    ).firstMatch(text);
    if (serverBlock != null) {
      expect(serverBlock[1], isNot(contains('ports:')));
    }
    // The server is on the web network (Caddy reaches it there) and the
    // rate limit variables are not overridden away from the defaults.
    expect(text, isNot(contains('RATE_LIMIT_PER_MINUTE: "0"')));
    // .env.example documents every new variable.
    final example = File('.env.example').readAsStringSync();
    for (final n in [
      'RATE_LIMIT_PER_MINUTE',
      'RATE_LIMIT_MAX_TRACKED_IPS',
      'TRUSTED_PROXY_ADDRESSES',
    ]) {
      expect(example, contains(n));
    }
  });
}
