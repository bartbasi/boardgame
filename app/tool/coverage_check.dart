// Strict line coverage gate for lib/core/ and the domain and data layers of
// every feature (T-014 AC4, docs/decisions.md 2026-10-12). Same rules as the
// server gate, server/tool/coverage_gate.dart (T-011).
//
// Usage, from app/:
//   dart run tool/coverage_check.dart [--lcov coverage/lcov.info] [--min 80]
//   dart run tool/coverage_check.dart --write-imports
//
// Why an imports test: `flutter test --coverage` reports only libraries that
// some test loads, so an untested file would be invisible. The generated test
// test/coverage_imports_test.dart imports every file in scope, so every file
// is loaded. Coverage (package:coverage, run by flutter_tools with
// checkIgnoredLines) then leaves a loaded file out of lcov.info only when it
// has a `coverage:ignore-file` marker or no executable lines.
//
// The gate fails when:
//   - test/coverage_imports_test.dart is missing or out of date (a new file
//     in scope would otherwise not be loaded); fix with --write-imports;
//   - a file in scope has executable lines but no test runs any of them;
//   - a domain or data file has a `coverage:ignore-file` marker and is not in
//     [ignoreFileAllowlist] (the decision exempts only generated files);
//   - total line coverage of the files in scope is below the minimum, or
//     nothing in scope has executable lines.
//
// Exempt files, printed with their reason on every run:
//   - generated: named *.g.dart or *.freezed.dart AND starting with the
//     `// GENERATED CODE - DO NOT MODIFY BY HAND` header;
//   - coverage:ignore-file marker (lib/core only, or allowlisted);
//   - no executable lines: loaded by the imports test but absent from lcov,
//     with no ignore-file marker (for example an abstract interface).
// Files with coverage:ignore-start, ignore-end, or ignore-line markers are
// listed with a count, since those lines never reach the report.
//
// Exit codes: 0 pass, 1 gate failed, 2 bad arguments or a missing lcov file.
import 'dart:io';

/// Where the generated imports test lives, relative to app/.
const importsTestPath = 'test/coverage_imports_test.dart';

/// Domain and data files allowed to carry `coverage:ignore-file`, with the
/// reason. Adding one needs a reviewed reason; the list starts empty.
const Map<String, String> ignoreFileAllowlist = {};

/// Whether [path] is in lib/core/ or a feature's domain or data layer.
bool isInLayer(String path) {
  final p = normalizePath(path);
  if (!p.endsWith('.dart')) return false;
  return p.startsWith('lib/core/') || isDomainOrData(p);
}

/// Whether [path] is in a feature's domain or data layer.
bool isDomainOrData(String path) =>
    RegExp(r'^lib/features/[^/]+/(domain|data)/').hasMatch(normalizePath(path));

/// Path-only scope: in a layer and not named like a generated file. The gate
/// itself uses [isGenerated], which also needs the header.
bool isInScope(String path) {
  final p = normalizePath(path);
  if (p.endsWith('.g.dart') || p.endsWith('.freezed.dart')) return false;
  return isInLayer(p);
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

/// The header build_runner (Riverpod, freezed, json_serializable) writes at
/// the top of every generated file.
const generatedHeader = '// GENERATED CODE - DO NOT MODIFY BY HAND';

/// Whether [path] is a generated file: named `*.g.dart` or `*.freezed.dart`
/// AND carrying [generatedHeader] in its first five lines, so renaming a
/// hand-written file is not enough (same rule as the server gate).
bool isGenerated(String path, String source) =>
    (path.endsWith('.g.dart') || path.endsWith('.freezed.dart')) &&
    source
        .split('\n')
        .take(5)
        .any((line) => line.trim().startsWith(generatedHeader));

/// The per-line patterns package:coverage uses (coverage 1.15.1,
/// lib/src/util.dart lines 62 to 65). A line counts when it contains a match;
/// the `$` means the marker must end its line, so prose that mentions a
/// marker does not count.
final ignoreFilePattern = RegExp(r'//\s*coverage:ignore-file[\w\d\s]*$');
final ignoreStartPattern = RegExp(r'//\s*coverage:ignore-start[\w\d\s]*$');
final ignoreEndPattern = RegExp(r'//\s*coverage:ignore-end[\w\d\s]*$');
final ignoreLinePattern = RegExp(r'//\s*coverage:ignore-line[\w\d\s]*$');

/// Whether package:coverage drops the whole file.
bool hasIgnoreFile(String source) =>
    source.split('\n').any((line) => line.contains(ignoreFilePattern));

/// How many lines carry an ignore-start, ignore-end, or ignore-line marker.
int ignoreMarkerCount(String source) => source
    .split('\n')
    .where(
      (line) =>
          line.contains(ignoreStartPattern) ||
          line.contains(ignoreEndPattern) ||
          line.contains(ignoreLinePattern),
    )
    .length;

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

/// Outcome of the coverage numbers for the files in scope.
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

/// Applies the coverage numbers to an lcov report. Without [generated], files
/// are scoped by path ([isInScope]); with it, every file in a layer counts
/// unless it is in [generated] (checked by header, see [isGenerated]).
CoverageResult checkCoverage(
  String lcov, {
  double minPercent = 80,
  Set<String>? generated,
}) {
  bool keep(String p) =>
      generated == null ? isInScope(p) : isInLayer(p) && !generated.contains(p);
  final files = parseLcov(lcov).where((f) => keep(f.path)).toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  return CoverageResult(files, minPercent);
}

/// Source of every file in a layer under [libDir], keyed by `lib/...` path.
/// Paths are taken relative to libDir, so folders above it never matter.
Map<String, String> layerSources(Directory libDir) {
  if (!libDir.existsSync()) return const {};
  final prefix = libDir.path.length + 1;
  final sources = <String, String>{};
  for (final entity in libDir.listSync(recursive: true)) {
    if (entity is! File) continue;
    final path = 'lib/${entity.path.substring(prefix).replaceAll(r'\', '/')}';
    if (isInLayer(path)) sources[path] = entity.readAsStringSync();
  }
  return sources;
}

/// The files in [sources] the gate counts: all but generated ones, sorted.
List<String> scopeFiles(Map<String, String> sources) => [
  for (final MapEntry(key: path, value: source) in sources.entries)
    if (!isGenerated(path, source)) path,
]..sort();

/// Every file in scope under [libDir], as sorted `lib/...` paths.
List<String> filesInScope(Directory libDir) => scopeFiles(layerSources(libDir));

/// Files in scope under [libDir] that the report does not mention and that
/// have no ignore-file marker. With an up-to-date imports test these are the
/// files with no executable lines.
List<String> unloadedFiles(Directory libDir, CoverageResult result) {
  final sources = layerSources(libDir);
  final reported = result.files.map((f) => f.path).toSet();
  return [
    for (final path in scopeFiles(sources))
      if (!reported.contains(path) && !hasIgnoreFile(sources[path]!)) path,
  ];
}

/// Everything the gate found, ready to print.
class GateOutcome {
  GateOutcome({
    required this.result,
    required this.noExecutableLines,
    required this.exempt,
    required this.markers,
    required this.errors,
  });

  final CoverageResult result;

  /// Loaded files absent from lcov without an ignore-file marker.
  final List<String> noExecutableLines;

  /// Other exempt files (generated, allowed ignore-file) and the reason.
  final Map<String, String> exempt;

  /// Files with ignore-start, ignore-end, or ignore-line markers, and the
  /// number of marker lines.
  final Map<String, int> markers;

  /// Failures beyond the coverage numbers.
  final List<String> errors;

  bool get passed => result.passed && errors.isEmpty;

  String get report => formatReport(
    result,
    noExecutableLines,
    exempt: exempt,
    markers: markers,
    errors: errors,
  );
}

/// Runs every rule on an lcov report and the [sources] of all files in a
/// layer (see [layerSources]).
GateOutcome evaluateGate(
  String lcov,
  Map<String, String> sources, {
  double minPercent = 80,
  Map<String, String> allowlist = ignoreFileAllowlist,
}) {
  final generated = {
    for (final MapEntry(key: path, value: source) in sources.entries)
      if (isGenerated(path, source)) path,
  };
  final result = checkCoverage(
    lcov,
    minPercent: minPercent,
    generated: generated,
  );
  final reported = result.files.map((f) => f.path).toSet();
  final exempt = <String, String>{
    for (final path in generated) path: 'generated (GENERATED CODE header)',
  };
  final noLines = <String>[];
  final errors = <String>[];
  final markers = <String, int>{};
  for (final path in scopeFiles(sources)) {
    final source = sources[path]!;
    final count = ignoreMarkerCount(source);
    if (count > 0) markers[path] = count;
    if (reported.contains(path)) continue;
    if (!hasIgnoreFile(source)) {
      noLines.add(path);
    } else if (!isDomainOrData(path)) {
      exempt[path] = 'coverage:ignore-file marker';
    } else if (allowlist.containsKey(path)) {
      exempt[path] =
          'coverage:ignore-file marker, allowlisted: '
          '${allowlist[path]}';
    } else {
      errors.add(
        'coverage:ignore-file marker in a domain or data file: $path. Only '
        'generated files may be exempt (docs/decisions.md 2026-10-12); test '
        'it, or add it to ignoreFileAllowlist with a reviewed reason.',
      );
    }
  }
  return GateOutcome(
    result: result,
    noExecutableLines: noLines,
    exempt: Map.fromEntries(
      exempt.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    ),
    markers: markers,
    errors: errors,
  );
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

/// Human-readable report: one line per file, exemptions, markers, failures,
/// then the verdict. Failure lines start with `FAIL`.
String formatReport(
  CoverageResult result,
  List<String> unloaded, {
  Map<String, String> exempt = const {},
  Map<String, int> markers = const {},
  List<String> errors = const [],
}) {
  final b = StringBuffer()
    ..writeln('Line coverage, lib/core/ and lib/features/*/{domain,data}/:');
  for (final f in result.files) {
    if (f.found == 0) {
      // Every line was removed by coverage:ignore markers or is not code.
      b.writeln('  100.0%  0/0  ${f.path}  (n/a, no executable lines left)');
      continue;
    }
    final pct = f.hit * 100 / f.found;
    b.writeln(
      '  ${pct.toStringAsFixed(1).padLeft(5)}%  ${f.hit}/${f.found}  ${f.path}',
    );
  }
  b.writeln('Exempt files: ${exempt.length + unloaded.length}');
  for (final MapEntry(key: path, value: reason) in exempt.entries) {
    b.writeln('  $reason: $path');
  }
  for (final path in unloaded) {
    b.writeln('  no executable lines: $path');
  }
  if (markers.isNotEmpty) {
    b.writeln('Files with coverage:ignore-start/end/line markers:');
    for (final MapEntry(key: path, value: count) in markers.entries) {
      b.writeln('  $count marker line(s): $path');
    }
  }
  for (final path in result.untested) {
    b.writeln('FAIL: no test runs any line of $path');
  }
  for (final error in errors) {
    b.writeln('FAIL: $error');
  }
  final percent = result.percent;
  if (percent == null) {
    b.writeln('FAIL: no executable lines in scope.');
  } else {
    final passed = result.passed && errors.isEmpty;
    final untested = result.untested.length;
    b.writeln(
      '${passed ? 'PASS' : 'FAIL'}: ${percent.toStringAsFixed(1)}% '
      '(${result.hit}/${result.found} lines), '
      'minimum ${result.minPercent.toStringAsFixed(0)}%'
      '${untested == 0 ? '' : ', $untested untested file(s)'}.',
    );
  }
  return b.toString();
}

/// `::error::` annotations for every failure line in [report].
String annotations(String report) => [
  for (final line in report.split('\n'))
    if (line.startsWith('FAIL')) '::error::$line\n',
].join();

/// Markdown for the GitHub step summary.
String stepSummary(String report) =>
    '### App coverage gate\n\n```\n${report.trimRight()}\n```\n';

/// Writes or checks the imports test. Returns null when it is up to date (or
/// was written), otherwise the message to show. [root] is the package folder
/// (app/); it defaults to the current folder.
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
  return '$importsTestPath is missing or out of date, so some files in '
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
  final importsError = syncImportsTest(write: false);
  final gate = evaluateGate(
    file.readAsStringSync(),
    layerSources(Directory('lib')),
    minPercent: minPercent,
  );
  final outcome = importsError == null
      ? gate
      : GateOutcome(
          result: gate.result,
          noExecutableLines: gate.noExecutableLines,
          exempt: gate.exempt,
          markers: gate.markers,
          errors: [...gate.errors, importsError],
        );
  final report = outcome.report;
  stdout
    ..write(report)
    ..write(annotations(report));
  final summaryPath = Platform.environment['GITHUB_STEP_SUMMARY'];
  if (summaryPath != null && summaryPath.isNotEmpty) {
    File(summaryPath)
        .writeAsStringSync(stepSummary(report), mode: FileMode.append);
  }
  exitCode = outcome.passed ? 0 : 1;
}
