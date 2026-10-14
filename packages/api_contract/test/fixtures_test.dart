import 'package:api_contract/api_contract.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

/// Decoders by fixture name prefix. A fixture in malformed/ or variants/ is
/// named `<prefix>_<case>.json`.
final _decoders = <String, Object Function(Map<String, dynamic>)>{
  'error': ErrorEnvelope.fromJson,
  'health': HealthResponse.fromJson,
  'game_summary': GameSummary.fromJson,
  'game_detail': GameDetailResponse.fromJson,
  'search': SearchResponse.fromJson,
  'lookup': LookupResponse.fromJson,
};

Object Function(Map<String, dynamic>) _decoderFor(String path) {
  final name = path.split('/').last;
  final prefix = _decoders.keys
      .where((p) => name.startsWith('${p}_'))
      .fold<String?>(null, (best, p) {
        return best == null || p.length > best.length ? p : best;
      });
  if (prefix == null) {
    throw StateError('$path does not start with a known DTO prefix');
  }
  return _decoders[prefix]!;
}

/// T-018 AC7: one example JSON per response type and status, for the app's
/// data layer tests (T-028) to reuse.
void main() {
  group('Fixture inventory (T-018 AC7)', () {
    test('every response type has its example fixtures', () {
      expect(listFixtures('game_summary'), [
        'game_summary/full.json',
        'game_summary/minimal.json',
      ]);
      expect(listFixtures('game_detail'), [
        'game_detail/full.json',
        'game_detail/minimal.json',
      ]);
      expect(listFixtures('search'), [
        'search/empty.json',
        'search/results.json',
      ]);
      expect(listFixtures('lookup'), [
        'lookup/candidates.json',
        'lookup/matched.json',
        'lookup/none.json',
        'lookup/unavailable.json',
      ]);
      expect(listFixtures('health'), ['health/ok.json']);
    });

    for (final folder in [
      'game_summary',
      'game_detail',
      'search',
      'lookup',
      'health',
    ]) {
      final decode = _decoders[folder]!;
      for (final path in listFixtures(folder)) {
        test('$path decodes without error', () {
          expect(() => decode(readFixture(path)), returnsNormally);
        });
      }
    }

    for (final path in listFixtures('malformed')) {
      test('$path fails with CheckedFromJsonException', () {
        final decode = _decoderFor(path);
        expect(
          () => decode(readFixture(path)),
          throwsA(isA<CheckedFromJsonException>()),
        );
      });
    }

    for (final path in listFixtures('variants')) {
      test('$path decodes without error', () {
        final decode = _decoderFor(path);
        expect(() => decode(readFixture(path)), returnsNormally);
      });
    }

    test('a fixture with an unknown prefix is reported', () {
      expect(() => _decoderFor('malformed/other_x.json'), throwsStateError);
    });

    test('the longest prefix wins', () {
      expect(
        _decoderFor('variants/game_summary_x.json'),
        same(_decoders['game_summary']),
      );
    });
  });
}
