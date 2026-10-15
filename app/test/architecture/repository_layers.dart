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

/// A class declaration header: its modifiers, its name, and everything up
/// to the class body (the extends, with, and implements clauses, which may
/// span lines).
final RegExp _classHeader = RegExp(
  r'^\s*((?:(?:abstract|base|final|interface|sealed|mixin)\s+)*)'
  r'class\s+(\w+)([^{;]*)\{',
  multiLine: true,
);

/// Modifiers that make a class a type to implement rather than a concrete
/// implementation (T-029 R1-S2: `abstract`, `sealed`, `mixin class`, and
/// plain `interface class` repositories).
const Set<String> _interfaceModifiers = {
  'abstract',
  'sealed',
  'interface',
  'mixin',
};

/// A repository type named in a supertype clause: `XRepository` or
/// `XRepositoryImpl`, so a subclass of an implementation counts too.
final RegExp _repositoryType = RegExp(r'\b\w*Repository(?:Impl)?\b');

/// The supertype clauses of a class header.
final RegExp _supertypes = RegExp(
  r'\b(?:extends|with|implements)\b(.*)',
  dotAll: true,
);

/// [header] without type arguments, so `Comparable<XRepository>` does not
/// count as naming a repository.
String _withoutTypeArguments(String header) {
  final innermost = RegExp(r'<[^<>]*>');
  var text = header;
  while (innermost.hasMatch(text)) {
    text = text.replaceAll(innermost, '');
  }
  return text;
}

/// Whether a class is a repository interface (true), an implementation
/// (false), or neither (null). An interface is an abstract, sealed,
/// interface, or mixin class named `...Repository`. An implementation is
/// any other class that extends, implements, or mixes in a repository, or a
/// concrete class named `...Repository`.
bool? _classify(String modifiers, String name, String header) {
  final words = modifiers.trim().split(RegExp(r'\s+')).toSet();
  final named = name.endsWith('Repository');
  if (named && words.any(_interfaceModifiers.contains)) return true;
  final supertypes = _supertypes
      .firstMatch(_withoutTypeArguments(header))
      ?.group(1);
  if (supertypes != null && _repositoryType.hasMatch(supertypes)) {
    return false;
  }
  return named ? false : null;
}

/// Strips `//` comments, so commented-out code does not count.
String _withoutLineComments(String source) =>
    source.replaceAll(RegExp(r'//.*$', multiLine: true), '');

/// Every repository interface and implementation under [libDir].
///
/// Known limits (T-029 review R2-G1; none of these forms is in lib/, and
/// review would catch them): only `class` declarations are read, so a plain
/// `mixin XRepository`, an `enum` or `extension type` that implements a
/// repository, and a class whose annotation sits on the same line as
/// `class` (`@immutable class XRepository`) are not seen. Block comments
/// are not stripped.
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
          for (final m in _classHeader.allMatches(source))
            if (_classify(m.group(1)!, m.group(2)!, m.group(3)!)
                case final isInterface?)
              RepositoryDeclaration(
                file: relative,
                name: m.group(2)!,
                isInterface: isInterface,
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
