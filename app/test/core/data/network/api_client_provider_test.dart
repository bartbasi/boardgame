// T-013 AC2 and AC3: the app-wide client reads API_BASE_URL. Tests run
// without a --dart-define, so the provider's client must refuse to send.
import 'package:board_game_collector/core/data/network/api_client_provider.dart';
import 'package:board_game_collector/core/data/network/http_log_interceptor.dart';
import 'package:board_game_collector/core/domain/result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('without API_BASE_URL every call fails with a config failure', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final client = container.read(apiClientProvider);
    final result = await client.get('/health', decode: (json) => json);

    expect(
      result,
      const Err<Map<String, dynamic>>(
        ConfigurationFailure(ConfigurationProblem.missingBaseUrl),
      ),
    );
  });

  test('the client is a single instance with debug logging in tests', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final client = container.read(apiClientProvider);
    expect(container.read(apiClientProvider), same(client));
    // flutter test runs in debug mode, so logging is on; release builds
    // pass enableLogging: false (see http_log_interceptor_test.dart).
    expect(
      client.dio.interceptors.whereType<HttpLogInterceptor>(),
      hasLength(1),
    );
    expect(client.dio.options.connectTimeout, const Duration(seconds: 10));
  });
}
