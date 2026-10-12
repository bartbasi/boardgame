import 'dart:async';
import 'dart:io';

import 'package:boardgame_server/boardgame_server.dart';
import 'package:test/test.dart';

/// QA edge cases for `--healthcheck` (T-010 AC12), beyond the developer tests.

Future<HttpServer> _stub(
  FutureOr<void> Function(HttpRequest request) handle, {
  InternetAddress? address,
}) async {
  final server = await HttpServer.bind(
    address ?? InternetAddress.loopbackIPv4,
    0,
  );
  server.listen((request) async {
    try {
      await handle(request);
    } on Object {
      // The client may have gone away.
    }
  });
  addTearDown(() => server.close(force: true));
  return server;
}

Map<String, String> _env(int port) => {'PORT': '$port', 'LOG_LEVEL': 'info'};

Future<int> _run(
  int port,
  List<String> err, {
  Duration timeout = const Duration(milliseconds: 500),
}) => runHealthcheck(
  environment: _env(port),
  stderrLine: err.add,
  timeout: timeout,
);

void main() {
  group('runHealthcheck edge cases', () {
    test(
      'a 200 with a non-JSON body is still healthy (exit 0 on 200)',
      () async {
        final server = await _stub((request) async {
          request.response
            ..statusCode = 200
            ..write('<html>not json</html>');
          await request.response.close();
        });
        final err = <String>[];
        expect(await _run(server.port, err), 0);
        expect(err, isEmpty);
      },
    );

    test(
      'a 200 whose body never finishes ends in exit 1 by the timeout',
      () async {
        final server = await _stub((request) async {
          request.response
            ..statusCode = 200
            ..contentLength = 1000
            ..write('x');
          await request.response.flush();
          await Completer<void>().future;
        });
        final err = <String>[];
        final watch = Stopwatch()..start();
        expect(await _run(server.port, err), 1);
        expect(watch.elapsed, lessThan(const Duration(seconds: 3)));
        expect(err.single, contains('"reason":"timeout"'));
      },
    );

    test('a 200 with a large body is drained and healthy', () async {
      final server = await _stub((request) async {
        request.response.statusCode = 200;
        request.response.write('a' * 2000000);
        await request.response.close();
      });
      final err = <String>[];
      expect(
        await _run(server.port, err, timeout: const Duration(seconds: 3)),
        0,
      );
    });

    test('a connection closed without any response is exit 1', () async {
      final server = await _stub((request) async {
        final socket = await request.response.detachSocket();
        socket.destroy();
      });
      final err = <String>[];
      expect(await _run(server.port, err), 1);
      expect(err.single, contains('"level":"error"'));
      expect(err.single, isNot(contains('secret')));
    });

    for (final status in [201, 204, 301, 404, 429, 500, 502]) {
      test('status $status is exit 1', () async {
        final server = await _stub((request) async {
          request.response.statusCode = status;
          if (status == 301) {
            request.response.headers.set('location', '/health');
          }
          await request.response.close();
        });
        final err = <String>[];
        expect(await _run(server.port, err), 1);
        expect(err.single, contains('"status":$status'));
      });
    }

    test('a server listening only on IPv6 ::1 is unhealthy by design '
        '(the probe uses 127.0.0.1)', () async {
      final InternetAddress v6 = InternetAddress.loopbackIPv6;
      HttpServer server;
      try {
        server = await _stub((request) async {
          request.response.statusCode = 200;
          await request.response.close();
        }, address: v6);
      } on SocketException {
        markTestSkipped('IPv6 loopback not available');
        return;
      }
      final err = <String>[];
      expect(await _run(server.port, err), 1);
    });

    for (final port in ['0', '65536', '-1', 'abc', '']) {
      test(
        'PORT "$port" is an invalid config: exit 1, value not printed',
        () async {
          final err = <String>[];
          final code = await runHealthcheck(
            environment: {'PORT': port, 'LOG_LEVEL': 'info'},
            stderrLine: err.add,
          );
          expect(code, 1);
          expect(err.single, contains('invalid configuration'));
          if (port.trim().isNotEmpty) {
            expect(err.single, isNot(contains('"$port"')));
          }
        },
      );
    }

    test('PORT unset is exit 1', () async {
      final err = <String>[];
      final code = await runHealthcheck(
        environment: {'LOG_LEVEL': 'info'},
        stderrLine: err.add,
      );
      expect(code, 1);
    });

    // Rewritten by backend-developer in T-010 round 2 (review R1-S4): the
    // original passed HTTP_PROXY only in the map given to runHealthcheck,
    // which feeds Config.load, while HttpClient reads proxies from
    // Platform.environment. A real process with HTTP_PROXY in its own
    // environment is the only way to cover `findProxy = DIRECT`.
    test(
      'HTTP_PROXY in the process environment is ignored (real process)',
      () async {
        final server = await _stub((request) async {
          request.response.statusCode = 200;
          await request.response.close();
        });
        // A "proxy" that counts connections and answers nothing useful.
        final proxy = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(proxy.close);
        var proxyHits = 0;
        proxy.listen((socket) {
          proxyHits++;
          socket.destroy();
        });
        final proxyUrl = 'http://127.0.0.1:${proxy.port}';

        final result = await Process.run(
          Platform.resolvedExecutable,
          ['bin/server.dart', '--healthcheck'],
          environment: {
            ..._env(server.port),
            'HTTP_PROXY': proxyUrl,
            'http_proxy': proxyUrl,
            // An inherited no_proxy could hide a regression.
            'NO_PROXY': '',
            'no_proxy': '',
          },
        );

        expect(result.exitCode, 0, reason: 'stderr: ${result.stderr}');
        expect(proxyHits, 0);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test('ten health checks in a row against one server all exit 0', () async {
      final server = await _stub((request) async {
        request.response.statusCode = 200;
        await request.response.close();
      });
      for (var i = 0; i < 10; i++) {
        expect(await _run(server.port, <String>[]), 0);
      }
    });
  });
}
