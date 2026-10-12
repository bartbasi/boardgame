import 'dart:convert';
import 'dart:io';

/// Root of the JSON fixtures. `dart test` runs with the package as the
/// working directory.
const fixturesRoot = 'test/fixtures';

/// Reads and decodes one fixture as a JSON object.
Map<String, dynamic> readFixture(String relativePath) {
  final text = File('$fixturesRoot/$relativePath').readAsStringSync();
  return jsonDecode(text) as Map<String, dynamic>;
}

/// Lists the `.json` fixtures in [folder], sorted by name, as paths relative
/// to [fixturesRoot].
List<String> listFixtures(String folder) {
  final files =
      Directory('$fixturesRoot/$folder')
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .where((name) => name.endsWith('.json'))
          .map((name) => '$folder/$name')
          .toList()
        ..sort();
  return files;
}
