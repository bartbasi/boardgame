// T-013 AC2 and AC3: parsing API_BASE_URL.
import 'package:board_game_collector/core/data/network/api_config.dart';
import 'package:board_game_collector/core/domain/result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Uri? parse(String raw, {bool allowInsecureHttp = false}) => ApiConfig.parse(
    raw,
    allowInsecureHttp: allowInsecureHttp,
  ).valueOrNull?.baseUri;

  Failure? failure(String raw, {bool allowInsecureHttp = false}) =>
      ApiConfig.parse(raw, allowInsecureHttp: allowInsecureHttp).failureOrNull;

  group('accepted', () {
    test('an https URL', () {
      expect(
        parse('https://api.example.test'),
        Uri.parse('https://api.example.test'),
      );
    });

    test('trailing slashes and spaces are removed', () {
      expect(
        parse('  https://api.example.test///  '),
        Uri.parse('https://api.example.test'),
      );
      expect(
        parse('https://api.example.test/base/'),
        Uri.parse('https://api.example.test/base'),
      );
    });

    test('a port is kept', () {
      expect(
        parse('https://api.example.test:8443'),
        Uri.parse('https://api.example.test:8443'),
      );
    });

    test('http only when insecure http is allowed (debug builds)', () {
      expect(
        parse('http://10.0.2.2:8080', allowInsecureHttp: true),
        Uri.parse('http://10.0.2.2:8080'),
      );
    });

    test('toString shows the URL', () {
      expect(
        ApiConfig.parse(
          'https://api.example.test',
          allowInsecureHttp: false,
        ).valueOrNull.toString(),
        'ApiConfig(https://api.example.test)',
      );
    });
  });

  group('refused with a typed failure', () {
    test('http in a release build (AC3)', () {
      expect(
        failure('http://api.example.test'),
        const ConfigurationFailure(ConfigurationProblem.insecureBaseUrl),
      );
      expect(
        failure('HTTP://api.example.test'),
        const ConfigurationFailure(ConfigurationProblem.insecureBaseUrl),
      );
    });

    for (final raw in ['', '   ']) {
      test('missing: "$raw"', () {
        expect(
          failure(raw, allowInsecureHttp: true),
          const ConfigurationFailure(ConfigurationProblem.missingBaseUrl),
        );
      });
    }

    for (final raw in [
      'api.example.test',
      '/v1',
      'ftp://api.example.test',
      'https://',
      'https://api.example.test?x=1',
      'https://api.example.test#top',
      'https://user:pass@api.example.test',
      'https://[::1',
      'wss://api.example.test',
    ]) {
      test('malformed: "$raw"', () {
        expect(
          failure(raw, allowInsecureHttp: true),
          const ConfigurationFailure(ConfigurationProblem.malformedBaseUrl),
        );
      });
    }
  });

  test('without a dart-define the environment value is empty', () {
    expect(ApiConfig.fromEnvironment, isEmpty);
  });
}
