// AC9 (T-012): user-facing strings come from lib/l10n/app_en.arb with keys
// from docs/ux/copy.md. AC9 is proved by manual review; these checks back it
// up. Runs from the app/ folder.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Keys that exist only for the T-012 placeholders. They are not in copy.md
/// and are removed when the real screens replace the placeholders.
const String _skeletonPrefix = 'dev';

/// copy.md key (`scanner.denied.title`) to arb key (`scannerDeniedTitle`).
String arbKeyFor(String copyKey) {
  final parts = copyKey.split('.');
  return parts.first +
      parts.skip(1).map((p) => p[0].toUpperCase() + p.substring(1)).join();
}

/// Rows of the copy tables: `| key.name | String |`.
Map<String, String> readCopyTable(String markdown) {
  final row = RegExp(
    r'^\|\s*([a-z][A-Za-z0-9]*(?:\.[A-Za-z0-9]+)+)\s*\|\s*(.*?)\s*\|\s*$',
  );
  return {
    for (final line in const LineSplitter().convert(markdown))
      if (row.firstMatch(line) case final match?)
        arbKeyFor(match.group(1)!): match.group(2)!,
  };
}

/// String literals passed straight to the usual text parameters. `\s*`
/// spans newlines, so literals that dart format wraps onto the next line are
/// found too.
final RegExp _hardCoded = RegExp(
  r'''(?:\b(?:Text|Text\.rich|Tooltip|SnackBar|TextSpan)\(\s*|\b(?:label|tooltip|semanticLabel|semanticsLabel|title|message|text|hintText|labelText|helperText|errorText):\s*)r?['"]''',
);

/// 1-based line numbers where a hard-coded string literal match starts in
/// [source]. Reads the whole text, not one line at a time.
List<int> hardCodedStringLines(String source) => [
  for (final match in _hardCoded.allMatches(source))
    '\n'.allMatches(source.substring(0, match.start)).length + 1,
];

void main() {
  final arb = jsonDecode(
    File('lib/l10n/app_en.arb').readAsStringSync(),
  ) as Map<String, Object?>;
  final messages = {
    for (final entry in arb.entries)
      if (!entry.key.startsWith('@')) entry.key: entry.value! as String,
  };

  test('arbKeyFor turns dotted copy keys into camelCase', () {
    expect(arbKeyFor('scanner.denied.title'), 'scannerDeniedTitle');
    expect(arbKeyFor('nav.scanLabel'), 'navScanLabel');
  });

  test('every arb key and string matches docs/ux/copy.md', () {
    final copy = readCopyTable(File('../docs/ux/copy.md').readAsStringSync());
    expect(copy, isNotEmpty);
    for (final entry in messages.entries) {
      if (entry.key.startsWith(_skeletonPrefix)) continue;
      expect(copy, contains(entry.key), reason: '${entry.key} not in copy.md');
      expect(entry.value, copy[entry.key], reason: entry.key);
    }
  });

  test('every arb message has a description', () {
    for (final key in messages.keys) {
      final meta = arb['@$key'] as Map<String, Object?>?;
      expect(meta?['description'], isA<String>(), reason: key);
    }
  });

  group('hardCodedStringLines', () {
    test('finds a literal on the same line', () {
      expect(hardCodedStringLines("Text('Hello')"), [1]);
      expect(hardCodedStringLines('x(label: "Hi")'), [1]);
    });

    test('finds a literal that dart format wrapped onto the next line', () {
      const source = '''
final a = Text(
  'This is a long sentence that dart format moved to its own line.',
);
final b = NavigationDestination(
  label:
      'Another long label that was wrapped after the colon',
);
''';
      expect(hardCodedStringLines(source), [1, 5]);
    });

    test('finds raw strings and TextSpan text', () {
      expect(hardCodedStringLines("Text(r'Raw')"), [1]);
      expect(hardCodedStringLines("TextSpan(text: 'Span')"), [1]);
    });

    test('ignores localized strings', () {
      expect(hardCodedStringLines('Text(l10n.navScan)'), isEmpty);
      expect(
        hardCodedStringLines('Text(\n  l10n.devPlaceholderItem(number),\n)'),
        isEmpty,
      );
    });
  });

  test('no widget in lib/ has a hard-coded user-facing string', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      final path = entity.path.replaceAll(r'\', '/');
      if (entity is! File ||
          !path.endsWith('.dart') ||
          path.endsWith('.g.dart') ||
          path.startsWith('lib/l10n/')) {
        continue;
      }
      for (final line in hardCodedStringLines(entity.readAsStringSync())) {
        offenders.add('$path:$line');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
