import 'dart:io';

/// One repository declared in the wrong layer (T-029 AC8).
class RepositoryLayerViolation {
  const RepositoryLayerViolation({
    required this.file,
    required this.name,
    required this.reason,
  });

  /// The file, relative to lib/, with forward slashes.
  final String file;

  /// The class that breaks the rule.
  final String name;

  /// Why it is not allowed.
  final String reason;

  @override
  String toString() => '$file: $name ($reason)';
}

/// A repository found by [findRepositories].
class RepositoryDeclaration {
  const RepositoryDeclaration({
    required this.file,
    required this.name,
    required this.isInterface,
  });

  /// The file, relative to lib/, with forward slashes.
  final String file;

  /// The class name.
  final String name;

  /// True for an abstract repository (the interface), false for a class
  /// that implements one.
  final bool isInterface;
}

/// An abstract class whose name ends in Repository: the interface.
final RegExp _interface = RegExp(
  r'^\s*abstract\s+(?:interface\s+|base\s+)?class\s+(\w*Repository)\b',
  multiLine: true,
);

/// A concrete class that implements a Repository interface. The implements
/// clause may span lines, so it is matched up to the class body. A
/// Repository inside type arguments (`Comparable<FooRepository>`) does not
/// count.
final RegExp _implementation = RegExp(
  r'^\s*(?:final\s+|base\s+)?class\s+(\w+)[^{;]*?\bimplements\b[^{]*?'
  r'\b\w*Repository\b(?![\w\s,]*>)[^{]*\{',
  multiLine: true,
);

/// Strips `//` comments, so commented-out code does not count.
String _withoutLineComments(String source) =>
    source.replaceAll(RegExp(r'//.*$', multiLine: true), '');

/// Every repository interface and implementation under [libDir].
List<RepositoryDeclaration> findRepositories(Directory libDir) {
  if (!libDir.existsSync()) return const [];
  final root = libDir.absolute.path;
  final files = [
    for (final entity in libDir.listSync(recursive: true))
      if (entity is File &&
          entity.path.endsWith('.dart') &&
          !entity.path.endsWith('.g.dart') &&
          !entity.path.endsWith('.freezed.dart'))
        entity,
  ]..sort((a, b) => a.path.compareTo(b.path));
  return [
    for (final file in files)
      ...() {
        final relative = file.absolute.path
            .substring(root.length + 1)
            .replaceAll(Platform.pathSeparator, '/');
        final source = _withoutLineComments(file.readAsStringSync());
        return [
          for (final m in _interface.allMatches(source))
            RepositoryDeclaration(
              file: relative,
              name: m.group(1)!,
              isInterface: true,
            ),
          for (final m in _implementation.allMatches(source))
            RepositoryDeclaration(
              file: relative,
              name: m.group(1)!,
              isInterface: false,
            ),
        ];
      }(),
  ];
}

/// Checks that every repository interface lives in a feature's domain
/// folder (`features/<feature>/domain/`) and every implementation in a
/// feature's data folder (`features/<feature>/data/`).
List<RepositoryLayerViolation> checkRepositoryLayers(Directory libDir) => [
  for (final repo in findRepositories(libDir))
    if (repo.isInterface && !_inLayer(repo.file, 'domain'))
      RepositoryLayerViolation(
        file: repo.file,
        name: repo.name,
        reason: 'repository interfaces belong in features/<feature>/domain/',
      )
    else if (!repo.isInterface && !_inLayer(repo.file, 'data'))
      RepositoryLayerViolation(
        file: repo.file,
        name: repo.name,
        reason: 'repository implementations belong in features/<feature>/data/',
      ),
];

bool _inLayer(String file, String layer) {
  final segments = file.split('/');
  return segments.length >= 4 &&
      segments[0] == 'features' &&
      segments[2] == layer;
}
