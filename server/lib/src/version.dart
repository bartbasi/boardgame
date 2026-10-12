// A single compile-time constant has no executable lines, so it never appears
// in lcov.info; the marker exempts it from the CI coverage gate (T-011).
// coverage:ignore-file

/// The server build version reported by GET /health.
///
/// Set at compile time, for example
/// `dart compile exe -DAPP_VERSION=0.1.0+abc1234 bin/server.dart`
/// (the Dockerfile in T-009 passes the release and git commit). Local runs
/// without the define report `0.1.0-dev`.
const String appVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: '0.1.0-dev',
);
