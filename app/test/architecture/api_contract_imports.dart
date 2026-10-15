import 'dart:io';

import 'domain_purity.dart' show directiveUris;

/// One file that uses package:api_contract where it may not (T-028 AC5).
class ContractImportViolation {
  const ContractImportViolation({
    required this.file,
    required this.uri,
    required this.reason,
  });

  /// The file, relative to lib/, with forward slashes.
  final String file;

  /// The URI in the import or export directive.
  final String uri;

  /// Why it is not allowed.
  final String reason;

  @override
  String toString() => '$file: "$uri" ($reason)';
}

/// Whether [segments] (a path relative to lib/) is a data layer file:
/// `features/<feature>/data/...` or `core/data/...`.
bool isDataPath(List<String> segments) =>
    (segments.length >= 4 &&
        segments[0] == 'features' &&
        segments[2] == 'data') ||
    (segments.length >= 3 && segments[0] == 'core' && segments[1] == 'data');

/// Checks every Dart file under [libDir]: only data layer files may import
/// `package:api_contract`, and no file may export it, so the DTOs cannot
/// reach domain or presentation code through a data file either. Domain and
/// presentation get domain entities from the data layer's mappers.
List<ContractImportViolation> checkContractImports(Directory libDir) {
  if (!libDir.existsSync()) return const [];
  final root = libDir.absolute.path;
  final files = [
    for (final entity in libDir.listSync(recursive: true))
      if (entity is File && entity.path.endsWith('.dart')) entity,
  ]..sort((a, b) => a.path.compareTo(b.path));
  final violations = <ContractImportViolation>[];
  for (final file in files) {
    final relative = file.absolute.path
        .substring(root.length + 1)
        .replaceAll(Platform.pathSeparator, '/');
    final segments = relative.split('/');
    final source = file.readAsStringSync();
    for (final uri in directiveUris(source)) {
      if (!uri.startsWith('package:api_contract/')) continue;
      if (_exports(source, uri)) {
        violations.add(
          ContractImportViolation(
            file: relative,
            uri: uri,
            reason: 'api_contract must not be re-exported',
          ),
        );
      } else if (!isDataPath(segments)) {
        violations.add(
          ContractImportViolation(
            file: relative,
            uri: uri,
            reason: 'api_contract may only be imported under lib/**/data/',
          ),
        );
      }
    }
  }
  return violations;
}

/// Whether [source] has an export directive for [uri]. Comments are
/// ignored.
bool _exports(String source, String uri) => RegExp(
  '^\\s*export\\s+[\'"]${RegExp.escape(uri)}[\'"]',
  multiLine: true,
).hasMatch(source.replaceAll(_blockComment, '').replaceAll(_lineComment, ''));

final RegExp _blockComment = RegExp(r'/\*[\s\S]*?\*/');
final RegExp _lineComment = RegExp(r'//[^\n]*');
