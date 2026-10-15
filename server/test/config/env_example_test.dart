import 'dart:collection';
import 'dart:io';

import 'package:boardgame_server/boardgame_server.dart';
import 'package:test/test.dart';

/// A map that records every key the config loader asks for.
class _RecordingMap extends MapBase<String, String> {
  _RecordingMap(this._inner);

  final Map<String, String> _inner;
  final Set<String> readKeys = {};

  @override
  String? operator [](Object? key) {
    if (key is String) readKeys.add(key);
    return _inner[key];
  }

  @override
  void operator []=(String key, String value) => _inner[key] = value;

  @override
  void clear() => _inner.clear();

  @override
  Iterable<String> get keys {
    fail('The config loader must read variables by name, not list them.');
  }

  @override
  String? remove(Object? key) => _inner.remove(key);
}

/// Optional variables documented as commented-out `# KEY=value` lines, so
/// that copying the file unchanged leaves them unset (T-084 review R1-G2).
Map<String, String> _parseCommentedVariables(String text) => {
  for (final match in RegExp(
    r'^# ([A-Z][A-Z0-9_]*)=(\S+)$',
    multiLine: true,
  ).allMatches(text.replaceAll('\r', '')))
    match[1]!: match[2]!,
};

/// Parses KEY=value lines; skips blank lines and # comments.
Map<String, String> _parseEnvFile(String text) {
  final result = <String, String>{};
  for (final raw in text.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final eq = line.indexOf('=');
    if (eq <= 0) fail('Malformed line in .env.example: "$line"');
    final key = line.substring(0, eq).trim();
    if (result.containsKey(key)) fail('Duplicate key in .env.example: $key');
    result[key] = line.substring(eq + 1).trim();
  }
  return result;
}

void main() {
  // `dart test` runs with the package root (server/) as working directory.
  final exampleText = File('.env.example').readAsStringSync();
  final example = _parseEnvFile(exampleText);
  final commented = _parseCommentedVariables(exampleText);

  group('.env.example (T-008 AC6)', () {
    test('lists exactly the variables the config loaders read (T-008 AC6, '
        'T-019 AC4)', () {
      final recording = _RecordingMap({});
      expect(() => Config.load(recording), throwsA(isA<ConfigException>()));
      expect(
        () => DatabaseConfig.load(recording),
        throwsA(isA<ConfigException>()),
      );
      // Optional pair (T-084): with neither set it returns null.
      expect(EbayAccountDeletionConfig.load(recording), isNull);

      expect(recording.readKeys, isNotEmpty);
      expect(
        example.keys.toSet().intersection(commented.keys.toSet()),
        isEmpty,
      );
      expect({...example.keys, ...commented.keys}, recording.readKeys);
    });

    test('its values form a valid config, so it is a working template', () {
      expect(() => Config.load(example), returnsNormally);
      expect(() => DatabaseConfig.load(example), returnsNormally);
      // Copied unchanged, the eBay endpoint stays off (review R1-G2).
      expect(EbayAccountDeletionConfig.load(example), isNull);
    });

    test(
      'the eBay account deletion pair is documented commented out, and '
      'its placeholders form a valid pair once uncommented (T-084 R1-G2)',
      () {
        expect(commented.keys.toSet(), {
          ebayAccountDeletionTokenVariable,
          ebayAccountDeletionUrlVariable,
        });
        expect(example.keys, isNot(contains(ebayAccountDeletionTokenVariable)));
        expect(example.keys, isNot(contains(ebayAccountDeletionUrlVariable)));
        expect(EbayAccountDeletionConfig.load(commented), isNotNull);
      },
    );

    test('every key is UPPER_SNAKE_CASE with a non-empty placeholder', () {
      for (final MapEntry(:key, :value) in example.entries) {
        expect(key, matches(RegExp(r'^[A-Z][A-Z0-9_]*$')));
        expect(value, isNotEmpty, reason: '$key needs a placeholder value');
      }
    });

    test('is committed but a real .env is git-ignored', () async {
      ProcessResult inRepo;
      try {
        inRepo = await Process.run('git', [
          'rev-parse',
          '--is-inside-work-tree',
        ]);
      } on ProcessException {
        markTestSkipped('git is not installed');
        return;
      }
      if (inRepo.exitCode != 0) {
        markTestSkipped('not inside a git work tree');
        return;
      }
      final result = await Process.run('git', [
        'check-ignore',
        '--no-index',
        '-q',
        '.env',
      ]);
      expect(result.exitCode, 0, reason: 'server/.env must be git-ignored');

      final example = await Process.run('git', [
        'check-ignore',
        '--no-index',
        '-q',
        '.env.example',
      ]);
      expect(example.exitCode, 1, reason: '.env.example must not be ignored');
    });
  });

  group('only the config loader reads the environment', () {
    test('Platform.environment appears only in bin/server.dart, once', () {
      final hits = <String>[];
      for (final dir in ['lib', 'bin']) {
        for (final entity in Directory(dir).listSync(recursive: true)) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;
          final count = 'Platform.environment'
              .allMatches(entity.readAsStringSync())
              .length;
          for (var i = 0; i < count; i++) {
            hits.add(entity.uri.pathSegments.last);
          }
        }
      }
      expect(hits, ['server.dart']);
    });
  });
}
