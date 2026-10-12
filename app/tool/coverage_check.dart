// Strict line coverage gate for lib/core/ and the domain and data layers of
// every feature (T-014 AC4, docs/decisions.md 2026-10-12).
//
// Usage, from app/:
//   dart run tool/coverage_check.dart [--lcov coverage/lcov.info] [--min 80]
//   dart run tool/coverage_check.dart --write-imports
//
// Why an imports test: `flutter test --coverage` reports only libraries that
// some test loads, so an untested file would be invisible. The generated test
// test/coverage_imports_test.dart imports every file in scope, so every file
// is loaded. A file in scope that is still absent from lcov.info then has no
// executable lines (for example an abstract repository interface), and that
// is the only kind of file allowed to be absent.
//
// The gate fails when:
//   - test/coverage_imports_test.dart is missing or out of date (a new file
//     in scope would otherwise not be loaded); fix with --write-imports;
//   - a file in scope has executable lines but no test runs any of them;
//   - total line coverage of the files in scope is below the minimum, or
//     nothing in scope has executable lines.
// Generated files (*.g.dart, *.freezed.dart) are out of scope.
//
// Exit codes: 0 pass, 1 gate failed, 2 bad arguments or a missing lcov file.
import 'dart:io';

/// Where the generated imports test lives, relative to app/.
const importsTestPath = 'test/coverage_imports_test.dart';

/// Files counted towards the coverage gate: lib/core/ and the domain and data
/// layers of every feature. Generated files are left out.
bool isInScope(String path) {
  final p = normalizePath(path);
  if (!p.endsWith('.dart')) return false;
  if (p.endsWith('.g.dart') || p.endsWith('.freezed.dart')) return false;
  return p.startsWith('lib/core/') ||
      RegExp(r'^lib/features/[^/]+/(domain|data)/').hasMatch(p);
}

/// Turns `C:\x\app\lib\core\a.dart` or `lib\core\a.dart` into
/// `lib/core/a.dart`, so Windows and Linux reports compare equal. Cuts at the
/// first `/lib/`, the package's own lib folder, so a nested folder named lib
/// inside it keeps its layer prefix.
String normalizePath(String path) {
  final p = path.replaceAll(r'\', '/');
  if (p.startsWith('lib/')) return p;
  final i = p.indexOf('/lib/');
  return i < 0 ? p : p.substring(i + 1);
}

/// Covered and total executable lines for one file.
class FileCoverage {
  FileCoverage(this.path, this.hit, this.found);

  final String path;
  final int hit;
  final int found;
}

/// Parses an lcov tracefile. Lines are counted from `DA:` records; a line
/// that appears twice in one file counts once and is hit if any record hit it.
List<FileCoverage> parseLcov(String content) {
  final result = <FileCoverage>[];
  String? current;
  var lines = <int, bool>{};
  for (final raw in content.split('\n')) {
    final line = raw.trim();
    if (line.startsWith('SF:')) {
      current = normalizePath(line.substring(3));
      lines = <int, bool>{};
    } else if (line.startsWith('DA:') && current != null) {
      final parts = line.substring(3).split(',');
      if (parts.length < 2) continue;
      final number = int.tryParse(parts[0]);
      final hits = int.tryParse(parts[1]);
      if (number == null || hits == null) continue;
      lines[number] = (lines[number] ?? false) || hits > 0;
    } else if (line == 'end_of_record' && current != null) {
      final hit = lines.values.where((h) => h).length;
      result.add(FileCoverage(current, hit, lines.length));
      current = null;
    }
  }
  return result;
}

/// Outcome of the gate for the files in scope.
class CoverageResult {
  CoverageResult(this.files, this.minPercent);

  final List<FileCoverage> files;
  final double minPercent;

  int get hit => files.fold(0, (sum, f) => sum + f.hit);
  int get found => files.fold(0, (sum, f) => sum + f.found);

  /// Line coverage in percent, or null when no executable line is in scope.
  double? get percent => found == 0 ? null : hit * 100 / found;

  /// Files with executable lines of which no test runs a single one.
  List<String> get untested => [
    for (final f in files)
      if (f.found > 0 && f.hit == 0) f.path,
  ];

  bool get passed =>
      percent != null && percent! >= minPercent && untested.isEmpty;
}

/// Applies the gate to an lcov report.
CoverageResult checkCoverage(String lcov, {double minPercent = 80}) {
  final files = parseLcov(lcov).where((f) => isInScope(f.path)).toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  return CoverageResult(files, minPercent);
}

/// Every file in scope under [libDir], as sorted `lib/...` paths.
List<String> filesInScope(Directory libDir) {
  if (!libDir.existsSync()) return const [];
  // Paths are taken relative to libDir, so folders above it never matter.
  final prefix = libDir.path.length + 1;
  final paths = [
    for (final entity in libDir.listSync(recursive: true))
      if (entity is File)
        'lib/${entity.path.substring(prefix).replaceAll(r'\', '/')}',
  ];
  return paths.where(isInScope).toList()..sort();
}

/// Files in scope under [libDir] that the report does not mention. With an
/// up-to-date imports test these are the files with no executable lines.
List<String> unloadedFiles(Directory libDir, CoverageResult result) {
  final reported = result.files.map((f) => f.path).toSet();
  return [
    for (final path in filesInScope(libDir))
      if (!reported.contains(path)) path,
  ];
}

/// The package name from a pubspec.yaml, or null if there is none.
String? packageName(String pubspec) =>
    RegExp(r'^name:\s*(\S+)', multiLine: true).firstMatch(pubspec)?.group(1);

/// Source of the generated test that imports every file in [files].
String importsTestSource(String package, List<String> files) {
  final b = StringBuffer()
    ..writeln(
      '// GENERATED by `dart run tool/coverage_check.dart '
      '--write-imports`. Do not edit.',
    )
    ..writeln('//')
    ..writeln(
      '// Imports every file the coverage gate checks, so files that '
      'no other test',
    )
    ..writeln('// loads still show up in coverage/lcov.info (T-014).')
    ..writeln('// ignore_for_file: unused_import')
    ..writeln();
  // No `as` prefixes: dart format never splits a plain import, so the
  // generated file stays format clean. Unused imports cannot clash.
  for (final path in files) {
    b.writeln("import 'package:$package/${path.substring('lib/'.length)}';");
  }
  if (files.isNotEmpty) b.writeln();
  b
    ..writeln("import 'package:flutter_test/flutter_test.dart';")
    ..writeln()
    ..writeln('void main() {')
    ..writeln("  test('every file in the coverage gate loads', () {});")
    ..writeln('}');
  return b.toString();
}

/// True when [actual] matches [expected], ignoring CRLF line ends.
bool sameSource(String actual, String expected) =>
    actual.replaceAll('\r\n', '\n') == expected;

/// Human-readable report: one line per file, problems, then the verdict.
String formatReport(CoverageResult result, List<String> unloaded) {
  final b = StringBuffer()
    ..writeln('Line coverage, lib/core/ and lib/features/*/{domain,data}/:');
  for (final f in result.files) {
    final pct = f.found == 0 ? 100.0 : f.hit * 100 / f.found;
    b.writeln(
      '  ${pct.toStringAsFixed(1).padLeft(5)}%  ${f.hit}/${f.found}  ${f.path}',
    );
  }
  for (final path in unloaded) {
    b.writeln('  no executable lines: $path');
  }
  for (final path in result.untested) {
    b.writeln('  FAIL: no test runs any line of $path');
  }
  final percent = result.percent;
  if (percent == null) {
    b.writeln('FAIL: no executable lines in scope.');
  } else {
    final verdict = result.passed ? 'PASS' : 'FAIL';
    b.writeln(
      '$verdict: ${percent.toStringAsFixed(1)}% '
      '(${result.hit}/${result.found} lines), '
      'minimum ${result.minPercent.toStringAsFixed(0)}%'
      '${result.untested.isEmpty ? '' : ', ${result.untested.length} untested file(s)'}.',
    );
  }
  return b.toString();
}

/// Writes or checks the imports test. Returns null when it is up to date (or
/// was written), otherwise the message to show.
/// [root] is the package folder (app/); it defaults to the current folder.
String? syncImportsTest({required bool write, String root = '.'}) {
  final pubspec = File('$root/pubspec.yaml');
  final name = pubspec.existsSync()
      ? packageName(pubspec.readAsStringSync())
      : null;
  if (name == null) return 'No package name in $root/pubspec.yaml.';
  final expected = importsTestSource(
    name,
    filesInScope(Directory('$root/lib')),
  );
  final file = File('$root/$importsTestPath');
  if (write) {
    file
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(expected);
    return null;
  }
  if (file.existsSync() && sameSource(file.readAsStringSync(), expected)) {
    return null;
  }
  return 'FAIL: $importsTestPath is missing or out of date, so some files in '
      'scope may not be loaded. Run `dart run tool/coverage_check.dart '
      '--write-imports`, run the tests again, and commit the file.';
}

void main(List<String> args) {
  var lcovPath = 'coverage/lcov.info';
  var minPercent = 80.0;
  var writeImports = false;
  for (var i = 0; i < args.length; i++) {
    final value = i + 1 < args.length ? args[i + 1] : null;
    switch (args[i]) {
      case '--lcov' when value != null:
        lcovPath = value;
        i++;
      case '--min' when value != null && double.tryParse(value) != null:
        minPercent = double.parse(value);
        i++;
      case '--write-imports':
        writeImports = true;
      default:
        stderr.writeln('Unknown or incomplete argument: ${args[i]}');
        exitCode = 2;
        return;
    }
  }
  if (writeImports) {
    final error = syncImportsTest(write: true);
    if (error != null) {
      stderr.writeln(error);
      exitCode = 1;
    } else {
      stdout.writeln('Wrote $importsTestPath.');
    }
    return;
  }
  final file = File(lcovPath);
  if (!file.existsSync()) {
    stderr.writeln('No coverage report at $lcovPath.');
    exitCode = 2;
    return;
  }
  final result = checkCoverage(file.readAsStringSync(), minPercent: minPercent);
  stdout.write(formatReport(result, unloadedFiles(Directory('lib'), result)));
  final importsError = syncImportsTest(write: false);
  if (importsError != null) stdout.writeln(importsError);
  exitCode = result.passed && importsError == null ? 0 : 1;
}
