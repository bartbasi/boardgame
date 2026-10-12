import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'api_client.dart';
import 'api_config.dart';

part 'api_client_provider.g.dart';

/// The app's single [ApiClient], configured from
/// `--dart-define=API_BASE_URL=...`.
///
/// Debug builds may use http for a local server; profile and release
/// builds require https (T-013 AC3). Request logging is on only in debug
/// builds and never includes bodies (AC12).
@Riverpod(keepAlive: true)
ApiClient apiClient(Ref ref) {
  final client = ApiClient(
    config: ApiConfig.parse(
      ApiConfig.fromEnvironment,
      allowInsecureHttp: kDebugMode,
    ),
    enableLogging: kDebugMode,
    log: (message) => debugPrint(message),
  );
  ref.onDispose(client.close);
  return client;
}
