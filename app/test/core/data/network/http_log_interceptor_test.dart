// T-013 AC12: request and response bodies are never logged, and release
// builds (logging disabled) have no log interceptor at all.
import 'dart:io';

import 'package:board_game_collector/core/data/network/http_log_interceptor.dart';
import 'package:board_game_collector/core/data/network/retry_policy.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_http.dart';

const String _secret = 'SECRET_BODY_MARKER';

void main() {
  test('logging disabled (release) adds no log interceptor', () {
    final client = fakeClient(FakeHttpAdapter([respond(200)]));

    expect(client.dio.interceptors.whereType<HttpLogInterceptor>(), isEmpty);
  });

  test('a response logs method, path, status, and time only', () {
    final lines = <String>[];
    final adapter = FakeHttpAdapter([
      respond(
        200,
        body: '{"status": "$_secret", "version": "1"}',
        headers: {'X-Secret': _secret},
        delay: const Duration(milliseconds: 250),
      ),
    ]);
    final client = fakeClient(adapter, enableLogging: true, log: lines.add);
    expect(
      client.dio.interceptors.whereType<HttpLogInterceptor>(),
      hasLength(1),
    );

    runFake(
      () => client.post(
        '/v1/search',
        decode: (json) => json,
        body: {'query': _secret},
      ),
    );

    expect(lines, ['HTTP POST /v1/search -> 200 (250 ms)']);
  });

  test('query strings are not logged', () {
    final lines = <String>[];
    final client = fakeClient(
      FakeHttpAdapter([respond(404, body: '{"x": "$_secret"}')]),
      enableLogging: true,
      log: lines.add,
      policy: const RetryPolicy(maxRetries: 0),
    );

    runFake(
      () => client.get(
        '/v1/search',
        decode: (json) => json,
        queryParameters: {'q': _secret},
      ),
    );

    expect(lines, ['HTTP GET /v1/search -> 404 (0 ms)']);
  });

  test('an error logs its type, not its message', () {
    final lines = <String>[];
    final client = fakeClient(
      FakeHttpAdapter([
        failWith(DioExceptionType.connectionError, error: _secret),
      ]),
      enableLogging: true,
      log: lines.add,
      policy: const RetryPolicy(maxRetries: 0),
    );

    runFake(() => client.get('/health', decode: (json) => json));

    expect(lines, ['HTTP GET /health -> connectionError (0 ms)']);
  });

  test('a missing start time leaves the time out', () {
    final lines = <String>[];
    final interceptor = HttpLogInterceptor(lines.add);
    final options = RequestOptions(
      path: '/health',
      baseUrl: 'https://api.example.test',
    );
    interceptor.onResponse(
      Response<String>(requestOptions: options, statusCode: 200),
      ResponseInterceptorHandler(),
    );

    expect(lines, ['HTTP GET /health -> 200']);
  });

  test('the interceptor never reads data, headers, or query parameters', () {
    // Backs up the manual review: this is the only file that logs requests,
    // and it never reads data, headers, or queryParameters.
    final source = File('lib/core/data/network/http_log_interceptor.dart')
        .readAsStringSync();
    expect(source, isNot(contains('.data')));
    expect(source, isNot(contains('.headers')));
    expect(source, isNot(contains('queryParameters')));
  });
}
