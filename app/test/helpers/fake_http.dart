import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:board_game_collector/core/data/network/api_client.dart';
import 'package:board_game_collector/core/data/network/api_config.dart';
import 'package:board_game_collector/core/data/network/retry_policy.dart';
import 'package:board_game_collector/core/domain/result.dart';
import 'package:clock/clock.dart';
import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';

/// Answers one request in a [FakeHttpAdapter].
typedef FakeHandler = Future<ResponseBody> Function(RequestOptions options);

/// An HTTP adapter that never touches the network. Each request takes the
/// next handler from the queue; the last handler repeats once the queue
/// has one left.
class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter(List<FakeHandler> handlers) : _handlers = [...handlers];

  final List<FakeHandler> _handlers;

  /// Every request sent, in order.
  final List<RequestOptions> requests = [];

  /// The fake (or real) clock time when each request was sent.
  final List<DateTime> sentAt = [];

  /// Whether each request's cancel future completed.
  final List<bool> cancelled = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    sentAt.add(clock.now());
    final index = cancelled.length;
    cancelled.add(false);
    unawaited(cancelFuture?.then((_) => cancelled[index] = true));
    final handler = _handlers.length > 1
        ? _handlers.removeAt(0)
        : _handlers.single;
    return handler(options);
  }

  @override
  void close({bool force = false}) {}

  /// The waits between consecutive requests.
  List<Duration> get gaps => [
    for (var i = 1; i < sentAt.length; i++) sentAt[i].difference(sentAt[i - 1]),
  ];
}

/// Responds with [status], [body], and [headers] after [delay].
FakeHandler respond(
  int status, {
  String body = '{}',
  Map<String, String> headers = const {},
  Duration delay = Duration.zero,
}) => (options) async {
  if (delay > Duration.zero) await Future<void>.delayed(delay);
  return ResponseBody.fromString(
    body,
    status,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
      for (final entry in headers.entries)
        entry.key.toLowerCase(): [entry.value],
    },
  );
};

/// Throws a [DioException] of [type] after [delay], wrapping [error].
FakeHandler failWith(
  DioExceptionType type, {
  Object? error,
  Duration delay = Duration.zero,
}) => (options) async {
  if (delay > Duration.zero) await Future<void>.delayed(delay);
  throw DioException(requestOptions: options, type: type, error: error);
};

/// Throws [error] as is, as a broken adapter might.
FakeHandler throwRaw(Object error) =>
    (options) async => throw error;

/// Never answers.
FakeHandler hang() =>
    (options) => Completer<ResponseBody>().future;

/// The base URL used by most tests (T-013 AC2).
const String testBaseUrl = 'https://api.example.test';

/// A client wired to [adapter], with a seeded random so jitter is
/// repeatable.
ApiClient fakeClient(
  FakeHttpAdapter adapter, {
  String baseUrl = testBaseUrl,
  Random? random,
  RetryPolicy policy = const RetryPolicy(),
  bool enableLogging = false,
  void Function(String)? log,
  Stopwatch Function()? newStopwatch,
}) {
  final dio = Dio()..httpClientAdapter = adapter;
  return ApiClient(
    config: ApiConfig.parse(baseUrl, allowInsecureHttp: false),
    enableLogging: enableLogging,
    dio: dio,
    random: random ?? Random(42),
    policy: policy,
    log: log,
    // Fake time drives the call deadline (production uses Stopwatch).
    newStopwatch: newStopwatch ?? clock.stopwatch,
  );
}

/// A fixed start time for fake clocks, on a whole second so HTTP dates
/// (one-second resolution) line up.
final DateTime fakeStart = DateTime.utc(2026, 10, 12, 12);

/// The outcome of [runFake]: the result and the fake time it took.
typedef Timed<T> = ({Result<T> result, Duration elapsed});

/// Runs [call] in fake time until it completes and returns its result and
/// the fake time it took. Fails if it does not finish within [limit].
Timed<T> runFake<T>(
  Future<Result<T>> Function() call, {
  Duration limit = const Duration(minutes: 5),
}) {
  return fakeAsync((async) {
    Result<T>? result;
    Duration? elapsed;
    final start = clock.now();
    unawaited(
      call().then((r) {
        result = r;
        elapsed = clock.now().difference(start);
      }),
    );
    var waited = Duration.zero;
    const step = Duration(milliseconds: 10);
    async.flushMicrotasks();
    while (result == null && waited < limit) {
      async.elapse(step);
      waited += step;
    }
    if (result == null) {
      throw StateError('call did not finish within $limit of fake time');
    }
    return (result: result!, elapsed: elapsed!);
  }, initialTime: fakeStart);
}

/// A Random whose nextDouble always returns [value], to test the edges of
/// the jitter range.
class FixedRandom implements Random {
  FixedRandom(this.value);

  final double value;

  @override
  double nextDouble() => value;

  @override
  bool nextBool() => value >= 0.5;

  @override
  int nextInt(int max) => (value * max).floor();
}

/// Reads a JSON fixture shared by packages/api_contract (its README allows
/// the app's data layer tests to reuse them). Tests run from app/.
String contractFixture(String relativePath) =>
    File('../packages/api_contract/test/fixtures/$relativePath')
        .readAsStringSync();

/// Reads a fixture from app/test/fixtures/.
String appFixture(String relativePath) =>
    File('test/fixtures/$relativePath').readAsStringSync();
