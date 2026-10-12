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

  test('no widget in lib/ has a hard-coded user-facing string', () {
    // String literals passed straight to the usual text parameters.
    final hardCoded = RegExp(
      r'''(?:Text|Tooltip|SnackBar)\(\s*['"]|(?:label|tooltip|semanticLabel|semanticsLabel|title|message|hintText|labelText|helperText|errorText):\s*['"]''',
    );
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      final path = entity.path.replaceAll(r'\', '/');
      if (entity is! File ||
          !path.endsWith('.dart') ||
          path.endsWith('.g.dart') ||
          path.startsWith('lib/l10n/')) {
        continue;
      }
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (hardCoded.hasMatch(lines[i])) offenders.add('$path:${i + 1}');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
