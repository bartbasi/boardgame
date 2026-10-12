// Line coverage gate for CI (T-011). Uses only dart:io, so any package can run
// it: `dart run ../../server/tool/coverage_gate.dart . 80` from
// packages/api_contract, or `dart run tool/coverage_gate.dart . 80` from server.
//
// Usage: dart run tool/coverage_gate.dart <package dir> <minimum percent>
//
// Reads <package dir>/coverage/lcov.info (written by
// `dart run coverage:test_with_coverage`) and fails (exit 1) when:
//   - line coverage (sum of LH over sum of LF) is below the minimum, or
//   - lcov.info has no coverable lines, or
//   - a file under lib/ is missing from lcov.info. test_with_coverage reports
//     only libraries the tests loaded, so a file no test imports would
//     otherwise not count at all (T-011 review R1-S3).
//
// Files that may be missing (each run prints them all with the reason, and
// writes them to the GitHub step summary):
//   - files marked `// coverage:ignore-file`, matched per line with the
//     coverage package's own pattern (the package skips them too);
//   - generated files: named *.g.dart or *.freezed.dart and starting with the
//     `// GENERATED CODE - DO NOT MODIFY BY HAND` header;
//   - files with only library, import, export, and part directives (barrels).
import 'dart:io';

/// Totals and file list from an lcov.info file.
class LcovSummary {
  LcovSummary(this.linesFound, this.linesHit, this.files);

  final int linesFound;
  final int linesHit;

  /// Paths relative to the package root, with `/` separators.
  final Set<String> files;

  double get percent => linesFound == 0 ? 0 : linesHit * 100 / linesFound;
}

/// Parses [lcov]. `SF:` paths are made relative to [packageRoot] (an absolute
/// path); paths outside it are kept as they are, with `/` separators.
LcovSummary parseLcov(String lcov, String packageRoot) {
  var root = _slashes(packageRoot);
  if (!root.endsWith('/')) root = '$root/';
  var found = 0;
  var hit = 0;
  final files = <String>{};
  for (final raw in lcov.split('\n')) {
    final line = raw.trim();
    if (line.startsWith('SF:')) {
      final path = _slashes(line.substring(3));
      files.add(
        _startsWithPath(path, root) ? path.substring(root.length) : path,
      );
    } else if (line.startsWith('LF:')) {
      found += int.parse(line.substring(3));
    } else if (line.startsWith('LH:')) {
      hit += int.parse(line.substring(3));
    }
  }
  return LcovSummary(found, hit, files);
}

/// The header build_runner (json_serializable, freezed) writes at the top of
/// every generated file.
const generatedHeader = '// GENERATED CODE - DO NOT MODIFY BY HAND';

/// Whether [path] is a generated file: named `*.g.dart` or `*.freezed.dart`
/// AND carrying [generatedHeader] in its first five lines, so renaming a
/// hand-written file is not enough (T-011 review R2-G1).
bool isGenerated(String path, String source) =>
    (path.endsWith('.g.dart') || path.endsWith('.freezed.dart')) &&
    source
        .split('\n')
        .take(5)
        .any((line) => line.trim().startsWith(generatedHeader));

/// The per-line pattern the coverage package uses for `coverage:ignore-file`
/// (coverage 1.15.1, lib/src/util.dart line 65, `final ignoreFile`), applied
/// the same way: a file is ignored when any line contains a match. The `$`
/// means the marker must end its line (only letters, digits, and spaces may
/// follow), so prose that merely mentions the marker does not count.
final ignoreFilePattern = RegExp(r'//\s*coverage:ignore-file[\w\d\s]*$');

/// Whether [source] opts out of coverage exactly as the coverage package sees
/// it (T-011 review R2-S2).
bool hasIgnoreFile(String source) =>
    source.split('\n').any((line) => line.contains(ignoreFilePattern));

/// Whether [source] has nothing but comments and library, import, export,
/// and part directives, so it has no executable lines.
bool isDirectiveOnly(String source) {
  final withoutComments = source
      .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
      .replaceAll(RegExp(r'//[^\n]*'), '');
  final withoutDirectives = withoutComments.replaceAll(
    RegExp(r'\b(library|import|export|part)\b[^;]*;'),
    '',
  );
  return withoutDirectives.trim().isEmpty;
}

/// Why the file at [path] may be absent from lcov, or null if it must appear.
String? exemptionReason(String path, String source) {
  if (hasIgnoreFile(source)) return 'coverage:ignore-file marker';
  if (isGenerated(path, source)) return 'generated (GENERATED CODE header)';
  if (isDirectiveOnly(source)) return 'imports/exports only';
  return null;
}

/// Every exempt file in [libSources] (relative path to source) with its
/// reason, sorted by path.
Map<String, String> exemptions(Map<String, String> libSources) {
  final paths = libSources.keys.toList()..sort();
  return {
    for (final path in paths) path: ?exemptionReason(path, libSources[path]!),
  };
}

/// The files in [libSources] (relative path to source) that must appear in
/// lcov but do not, sorted.
List<String> missingFromLcov(
  Map<String, String> libSources,
  Set<String> covered,
) {
  final missing = <String>[
    for (final MapEntry(key: path, value: source) in libSources.entries)
      if (!covered.contains(path) && exemptionReason(path, source) == null)
        path,
  ]..sort();
  return missing;
}

/// Runs the gate and returns the process exit code. Messages go to [out].
int runGate(String packageDir, int minPercent, StringSink out) {
  // Normalized, so `.` and `..` segments do not break the SF path match.
  final root = Directory(packageDir).absolute.uri
      .normalizePath()
      .toFilePath()
      .replaceFirst(RegExp(r'[\\/]+$'), '');
  final lcovFile = File('$root/coverage/lcov.info');
  if (!lcovFile.existsSync()) {
    out.writeln('::error::coverage/lcov.info not found in $packageDir');
    return 1;
  }
  final summary = parseLcov(lcovFile.readAsStringSync(), root);
  if (summary.linesFound == 0) {
    out.writeln('::error::no coverable lines found in coverage/lcov.info');
    return 1;
  }

  final libDir = Directory('$root/lib');
  final libSources = <String, String>{
    if (libDir.existsSync())
      for (final entity in libDir.listSync(recursive: true))
        if (entity is File && entity.path.endsWith('.dart'))
          _relative(entity.path, root): entity.readAsStringSync(),
  };
  final missing = missingFromLcov(libSources, summary.files);
  final exempt = exemptions(libSources);

  final line =
      'line coverage: ${summary.linesHit}/${summary.linesFound} = '
      '${summary.percent.toStringAsFixed(1)}% (minimum $minPercent%)';
  out.writeln(line);
  var code = 0;
  if (summary.percent < minPercent) {
    out.writeln('::error::$line');
    code = 1;
  }
  if (missing.isNotEmpty) {
    out.writeln(
      '::error::${missing.length} lib file(s) are not in the coverage report '
      'because no test loads them: ${missing.join(', ')}. Add tests that '
      'import them.',
    );
    code = 1;
  } else {
    out.writeln(
      'every lib file that is not exempt is in the coverage report '
      '(${libSources.length} files under lib/, ${exempt.length} exempt)',
    );
  }
  // Exemptions are listed every time so a new one shows up in review
  // (T-011 review R2-S1).
  out.writeln('exempt from the lcov presence check: ${exempt.length}');
  for (final MapEntry(key: path, value: reason) in exempt.entries) {
    out.writeln('  $path: $reason');
  }
  return code;
}

/// Markdown for the GitHub step summary: the whole gate output, with
/// `::error::` turned into a visible FAIL (T-011 review R2-G2).
String stepSummary(String packageDir, String output) {
  final buffer = StringBuffer('### Coverage gate: $packageDir\n\n```\n');
  for (final line in output.split('\n')) {
    if (line.isEmpty) continue;
    buffer.writeln(
      line.startsWith('::error::')
          ? 'FAIL: ${line.substring('::error::'.length)}'
          : line,
    );
  }
  buffer.writeln('```');
  return buffer.toString();
}

void main(List<String> args) {
  final min = args.length == 2 ? int.tryParse(args[1]) : null;
  if (min == null) {
    stderr.writeln(
      'usage: dart run tool/coverage_gate.dart <package dir> <minimum percent>',
    );
    exitCode = 2;
    return;
  }
  final out = StringBuffer();
  final code = runGate(args[0], min, out);
  stdout.write(out);
  final summaryPath = Platform.environment['GITHUB_STEP_SUMMARY'];
  if (summaryPath != null && summaryPath.isNotEmpty) {
    File(summaryPath).writeAsStringSync(
      stepSummary(args[0], out.toString()),
      mode: FileMode.append,
    );
  }
  exitCode = code;
}

String _slashes(String path) => path.replaceAll(r'\', '/');

bool _startsWithPath(String path, String root) => Platform.isWindows
    ? path.toLowerCase().startsWith(root.toLowerCase())
    : path.startsWith(root);

String _relative(String path, String root) {
  var r = _slashes(root);
  if (!r.endsWith('/')) r = '$r/';
  final p = _slashes(path);
  return _startsWithPath(p, r) ? p.substring(r.length) : p;
}
