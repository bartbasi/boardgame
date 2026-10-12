import 'dart:io';

/// One forbidden dependency found by [checkDomainPurity].
class PurityViolation {
  const PurityViolation({
    required this.domainFile,
    required this.file,
    required this.uri,
    required this.reason,
  });

  /// The domain file whose import graph reaches the problem.
  final String domainFile;

  /// The file that contains the directive (the domain file itself, or a
  /// file it imports directly or indirectly).
  final String file;

  /// The URI in the import or export directive.
  final String uri;

  /// Why the URI is not allowed.
  final String reason;

  @override
  String toString() => '$file: "$uri" ($reason), reached from $domainFile';
}

/// Pure Dart packages that domain code may import. Anything else is refused,
/// so Flutter, plugins, and unknown packages fail by default.
const Set<String> allowedDomainPackages = {
  'collection',
  'equatable',
  'freezed_annotation',
  'json_annotation',
  'meta',
};

/// Dart core libraries that are platform or UI bound.
const Set<String> forbiddenDartLibraries = {
  'dart:ffi',
  'dart:html',
  'dart:io',
  'dart:js',
  'dart:js_interop',
  'dart:js_interop_unsafe',
  'dart:js_util',
  'dart:mirrors',
  'dart:ui',
  'dart:ui_web',
};

final RegExp _blockComment = RegExp(r'/\*[\s\S]*?\*/');
final RegExp _lineComment = RegExp(r'//[^\n]*');
final RegExp _directive = RegExp(
  r'''^\s*(?:import|export)\s+((?:'[^']*'|"[^"]*")(?:\s*if\s*\([^)]*\)\s*(?:'[^']*'|"[^"]*"))*)''',
  multiLine: true,
);
final RegExp _quoted = RegExp(r'''(?:'([^']*)'|"([^"]*)")''');

/// Every URI in the import and export directives of [source], including the
/// alternatives of conditional imports. Comments are ignored.
List<String> directiveUris(String source) {
  final code = source
      .replaceAll(_blockComment, '')
      .replaceAll(_lineComment, '');
  return [
    for (final match in _directive.allMatches(code))
      for (final quoted in _quoted.allMatches(match.group(1)!))
        quoted.group(1) ?? quoted.group(2)!,
  ];
}

/// Checks every Dart file under `<libDir>/features/<feature>/domain/` and
/// `<libDir>/core/domain/` (shared domain code such as Result and Failure,
/// added in T-013).
///
/// A domain file, and every file of [packageName] it reaches through imports
/// or exports, may only use: `dart:` libraries outside
/// [forbiddenDartLibraries], packages in [allowedDomainPackages], and files
/// of its own package that are not in a feature's data or presentation
/// layer or in `core/data/`. Returns the violations; an empty list means
/// the layer is pure.
List<PurityViolation> checkDomainPurity({
  required Directory libDir,
  required String packageName,
}) {
  final featuresDir = Directory(_join(libDir.path, 'features'));
  final coreDomainDir = Directory(_join(libDir.path, 'core/domain'));
  final domainFiles = [
    if (featuresDir.existsSync())
      for (final entity in featuresDir.listSync(recursive: true))
        if (entity is File &&
            entity.path.endsWith('.dart') &&
            _segments(entity.path, libDir).length >= 3 &&
            _segments(entity.path, libDir)[2] == 'domain')
          entity,
    if (coreDomainDir.existsSync())
      for (final entity in coreDomainDir.listSync(recursive: true))
        if (entity is File && entity.path.endsWith('.dart')) entity,
  ]..sort((a, b) => a.path.compareTo(b.path));

  final violations = <PurityViolation>[];
  for (final domainFile in domainFiles) {
    final visited = <String>{};
    final queue = <File>[domainFile];
    while (queue.isNotEmpty) {
      final file = queue.removeLast();
      final key = File(file.path).absolute.path;
      if (!visited.add(key) || !file.existsSync()) continue;
      for (final uri in directiveUris(file.readAsStringSync())) {
        final result = _classify(
          uri: uri,
          from: file,
          libDir: libDir,
          packageName: packageName,
        );
        if (result.reason != null) {
          violations.add(
            PurityViolation(
              domainFile: _relative(domainFile.path, libDir),
              file: _relative(file.path, libDir),
              uri: uri,
              reason: result.reason!,
            ),
          );
        }
        if (result.follow != null) queue.add(result.follow!);
      }
    }
  }
  return violations;
}

class _Classification {
  const _Classification({this.reason, this.follow});
  final String? reason;
  final File? follow;
}

_Classification _classify({
  required String uri,
  required File from,
  required Directory libDir,
  required String packageName,
}) {
  if (uri.startsWith('dart:')) {
    final library = uri.split('/').first;
    return forbiddenDartLibraries.contains(library)
        ? _Classification(reason: '$library is platform or UI bound')
        : const _Classification();
  }
  if (uri.startsWith('package:')) {
    final rest = uri.substring('package:'.length);
    final slash = rest.indexOf('/');
    final package = slash < 0 ? rest : rest.substring(0, slash);
    if (package == packageName) {
      final target = File(_join(libDir.path, rest.substring(slash + 1)));
      return _ownFile(target, libDir);
    }
    if (package == 'flutter' || package.startsWith('flutter_')) {
      return _Classification(reason: 'Flutter package "$package"');
    }
    if (!allowedDomainPackages.contains(package)) {
      return _Classification(
        reason: 'package "$package" is not on the pure Dart allowlist',
      );
    }
    return const _Classification();
  }
  // A relative URI: resolve it against the importing file.
  final resolved = File(_join(from.parent.path, uri));
  return _ownFile(resolved, libDir);
}

_Classification _ownFile(File target, Directory libDir) {
  final segments = _segments(target.path, libDir);
  if (segments.length >= 3 &&
      segments[0] == 'features' &&
      (segments[2] == 'data' || segments[2] == 'presentation')) {
    return _Classification(
      reason: 'domain must not depend on the ${segments[2]} layer',
    );
  }
  if (segments.length >= 2 && segments[0] == 'core' && segments[1] == 'data') {
    return const _Classification(
      reason: 'domain must not depend on the core data layer',
    );
  }
  return _Classification(follow: target);
}

/// Path segments of [path] relative to [libDir], with `.` and `..` resolved.
List<String> _segments(String path, Directory libDir) {
  final base = _normalize(libDir.absolute.path);
  final full = _normalize(File(path).absolute.path);
  if (full.length < base.length || !full.startsWith(base)) return const [];
  return full.sublist(base.length);
}

List<String> _normalize(String path) {
  final out = <String>[];
  for (final part in path.split(RegExp(r'[\\/]'))) {
    if (part.isEmpty || part == '.') continue;
    if (part == '..') {
      if (out.isNotEmpty) out.removeLast();
    } else {
      out.add(part);
    }
  }
  return out;
}

extension on List<String> {
  bool startsWith(List<String> prefix) {
    for (var i = 0; i < prefix.length; i++) {
      if (this[i] != prefix[i]) return false;
    }
    return true;
  }
}

String _join(String a, String b) => '$a${Platform.pathSeparator}$b';

String _relative(String path, Directory libDir) =>
    _segments(path, libDir).join('/');
