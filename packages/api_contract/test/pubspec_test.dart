import 'dart:io';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// AC1: the package must stay usable by the server, which builds with the
/// plain Dart SDK image and no Flutter SDK (docs/decisions.md, T-004).
void main() {
  group('pubspec has no Flutter dependency (AC1)', () {
    final pubspec =
        loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;

    test('no flutter constraint in environment', () {
      final environment = pubspec['environment'] as YamlMap;
      expect(environment.keys, isNot(contains('flutter')));
    });

    for (final section in ['dependencies', 'dev_dependencies']) {
      test('no Flutter SDK package in $section', () {
        final deps = (pubspec[section] as YamlMap?) ?? YamlMap();
        for (final entry in deps.entries) {
          final value = entry.value;
          final fromSdk = value is YamlMap && value['sdk'] == 'flutter';
          expect(fromSdk, isFalse, reason: '${entry.key} comes from Flutter');
          expect(entry.key, isNot(startsWith('flutter')));
        }
      });
    }

    test('no top-level flutter section', () {
      expect(pubspec.keys, isNot(contains('flutter')));
    });

    test('pubspec.lock resolves no package from the Flutter SDK', () {
      final lock = loadYaml(File('pubspec.lock').readAsStringSync()) as YamlMap;
      final packages = lock['packages'] as YamlMap;
      for (final entry in packages.entries) {
        final info = entry.value as YamlMap;
        expect(
          info['source'],
          isNot('sdk'),
          reason: '${entry.key} is an SDK package',
        );
      }
      final sdks = lock['sdks'] as YamlMap;
      expect(sdks.keys, isNot(contains('flutter')));
    });
  });
}
