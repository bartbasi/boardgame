// Fails CI when line coverage of the domain and data layers and lib/core/ is
// below the minimum (T-014 AC4).
//
// Usage, from app/:
//   dart run tool/coverage_check.dart [--lcov coverage/lcov.info] [--min 80]
//
// Exit codes: 0 pass, 1 coverage below the minimum or nothing in scope,
// 2 bad arguments or a missing lcov file.
//
// Files in scope that no test loads are absent from lcov.info. They are listed
// as warnings, not counted, because files with no executable lines (for
// example abstract repository interfaces) are absent too.
import 'dart:io';

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
/// `lib/core/a.dart`, so Windows and Linux reports compare equal.
String normalizePath(String path) {
  final p = path.replaceAll(r'\', '/');
  if (p.startsWith('lib/')) return p;
  final i = p.lastIndexOf('/lib/');
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

  bool get passed => percent != null && percent! >= minPercent;
}

/// Applies the gate to an lcov report.
CoverageResult checkCoverage(String lcov, {double minPercent = 80}) {
  final files = parseLcov(lcov).where((f) => isInScope(f.path)).toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  return CoverageResult(files, minPercent);
}

/// In-scope files under [libDir] that the report does not mention.
List<String> unloadedFiles(Directory libDir, CoverageResult result) {
  if (!libDir.existsSync()) return const [];
  final reported = result.files.map((f) => f.path).toSet();
  final missing = <String>[];
  for (final entity in libDir.listSync(recursive: true)) {
    if (entity is! File) continue;
    final path = normalizePath(entity.path);
    if (isInScope(path) && !reported.contains(path)) missing.add(path);
  }
  return missing..sort();
}

/// Human-readable report; one line per file, then the total.
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
    b.writeln('  warning: no test loads $path');
  }
  final percent = result.percent;
  if (percent == null) {
    b.writeln('FAIL: no executable lines in scope.');
  } else {
    final verdict = result.passed ? 'PASS' : 'FAIL';
    b.writeln(
      '$verdict: ${percent.toStringAsFixed(1)}% '
      '(${result.hit}/${result.found} lines), '
      'minimum ${result.minPercent.toStringAsFixed(0)}%.',
    );
  }
  return b.toString();
}

void main(List<String> args) {
  var lcovPath = 'coverage/lcov.info';
  var minPercent = 80.0;
  for (var i = 0; i < args.length; i++) {
    final value = i + 1 < args.length ? args[i + 1] : null;
    switch (args[i]) {
      case '--lcov' when value != null:
        lcovPath = value;
        i++;
      case '--min' when value != null && double.tryParse(value) != null:
        minPercent = double.parse(value);
        i++;
      default:
        stderr.writeln('Unknown or incomplete argument: ${args[i]}');
        exitCode = 2;
        return;
    }
  }
  final file = File(lcovPath);
  if (!file.existsSync()) {
    stderr.writeln('No coverage report at $lcovPath.');
    exitCode = 2;
    return;
  }
  final result = checkCoverage(file.readAsStringSync(), minPercent: minPercent);
  stdout.write(formatReport(result, unloadedFiles(Directory('lib'), result)));
  exitCode = result.passed ? 0 : 1;
}
