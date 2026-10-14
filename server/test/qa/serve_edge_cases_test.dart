// QA T-008 round 2: hostile requests, disconnects, and throwing /v1 guards
// against a real child process. Nothing but JSON lines may reach stdout, and
// stderr must stay empty.
@Timeout(Duration(minutes: 3))
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../support/harness.dart';
import '../support/database.dart';

class _Child {
  _Child(this.process, this.port);
  final Process process;
  final int port;
  final stdoutLines = <String>[];
  final stderrText = StringBuffer();
  late final Future<void> _outDone;
  late final Future<void> _errDone;

  static Future<_Child> start(String script) async {
    final port = await freePort();
    final process = await Process.start(
      Platform.resolvedExecutable,
      script == 'bin/server.dart' ? [script] : [script, '$port'],
      environment: withTestDatabase({'PORT': '$port', 'LOG_LEVEL': 'debug'}),
    );
    final child = _Child(process, port);
    final started = Completer<void>();
    child._outDone = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .forEach((l) {
          child.stdoutLines.add(l);
          if (l.contains('"server started"') && !started.isCompleted) {
            started.complete();
          }
        });
    child._errDone = process.stderr
        .transform(utf8.decoder)
        .forEach(child.stderrText.write);
    addTearDown(() => process.kill(ProcessSignal.sigkill));
    await started.future.timeout(const Duration(seconds: 60));
    return child;
  }

  Future<void> stopAndCheck() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    process.kill();
    await process.exitCode.timeout(const Duration(seconds: 15));
    await Future.wait([_outDone, _errDone]);
    expect(stderrText.toString(), isEmpty, reason: 'stderr must stay empty');
    for (final line in stdoutLines) {
      expect(
        () => jsonDecode(line) as Map<String, dynamic>,
        returnsNormally,
        reason: 'not a JSON object: $line',
      );
      expect(line, isNot(contains('secret')), reason: line);
    }
  }
}

String _get(String target, {String headers = ''}) =>
    'GET $target HTTP/1.1\r\nHost: localhost\r\n$headers'
    'Connection: close\r\n\r\n';

const _end = 'Connection: close\r\n\r\n';

void main() {
  group('malformed requests against the real binary', () {
    test('bad Host, proto, absolute-form URIs, long headers', () async {
      final child = await _Child.start('bin/server.dart');
      final requests = <String, String>{
        'empty Host': 'GET /health HTTP/1.1\r\nHost: \r\n$_end',
        'Host with port overflow':
            'GET /health HTTP/1.1\r\nHost: secret-host:99999999\r\n$_end',
        'Host with space': 'GET /health HTTP/1.1\r\nHost: secret host\r\n$_end',
        'Host with userinfo':
            'GET /health HTTP/1.1\r\nHost: secret@evil\r\n$_end',
        'no Host (HTTP/1.1)': 'GET /health?q=secret HTTP/1.1\r\n$_end',
        'HTTP/1.0 no Host': 'GET /health?q=secret HTTP/1.0\r\n\r\n',
        'proto with colon slash': _get(
          '/health?q=secret',
          headers: 'X-Forwarded-Proto: ://secret\r\n',
        ),
        'proto empty': _get('/health', headers: 'X-Forwarded-Proto: \r\n'),
        'proto very odd': _get(
          '/health',
          headers: 'X-Forwarded-Proto: ht!tp-secret\r\n',
        ),
        'forwarded host with port overflow': _get(
          '/v1/x',
          headers: 'X-Forwarded-Host: secret:999999999\r\n',
        ),
        'absolute-form URI with bad authority':
            'GET http://[secret/v1/x?q=secret HTTP/1.1\r\n'
            'Host: localhost\r\n$_end',
        'absolute-form URI normal':
            'GET http://example.com/health?q=secret HTTP/1.1\r\n'
            'Host: localhost\r\n$_end',
        'authority-form CONNECT':
            'CONNECT secret.example:443 HTTP/1.1\r\n'
            'Host: secret.example:443\r\n$_end',
        'asterisk target': 'OPTIONS * HTTP/1.1\r\nHost: localhost\r\n$_end',
        'fragment in target': _get('/health#secret'),
        'percent-encoded junk': _get('/v1/%zz%secret?q=%zz'),
        'unicode path': _get('/v1/é中-secret'),
        'very long target': _get('/v1/${'a' * 70000}secret'),
        'very long header value': _get(
          '/health',
          headers: 'X-Big: ${'x' * 70000}secret\r\n',
        ),
        'very many headers': _get(
          '/health',
          headers: [for (var i = 0; i < 3000; i++) 'X-H$i: secret$i\r\n']
              .join(),
        ),
        'bare LF line endings':
            'GET /health HTTP/1.1\nHost: localhost\nConnection: close\n\n',
        'NUL byte in header': _get('/health', headers: 'X-A: sec\x00ret\r\n'),
        'obs-fold header': _get('/health', headers: 'X-A: a\r\n secret\r\n'),
        'bad content-length':
            'POST /v1/x HTTP/1.1\r\nHost: localhost\r\n'
            'Content-Length: secret\r\n$_end',
        'conflicting content-length':
            'POST /v1/x HTTP/1.1\r\nHost: localhost\r\n'
            'Content-Length: 3\r\nContent-Length: 5\r\n${_end}abc',
        'bad chunked body':
            'POST /v1/x HTTP/1.1\r\nHost: localhost\r\n'
            'Transfer-Encoding: chunked\r\n${_end}zz-secret\r\n',
      };
      final results = <String, String>{};
      for (final MapEntry(key: name, value: request) in requests.entries) {
        results[name] = await rawHttp(child.port, request);
      }
      // The server must still answer a normal request afterwards.
      expect(
        await rawHttp(child.port, _get('/health')),
        startsWith('HTTP/1.1 200'),
      );
      for (final MapEntry(key: name, value: response) in results.entries) {
        expect(response, isNot(contains('secret')), reason: name);
        expect(
          response,
          isNot(contains('Internal Server Error')),
          reason: name,
        );
        // An error answer must be JSON, not shelf or dart:io plain text.
        final status = response.split('\r\n').first;
        final body = rawBody(response) ?? '';
        if ((status.startsWith('HTTP/1.1 4') ||
                status.startsWith('HTTP/1.1 5')) &&
            body.isNotEmpty) {
          expect(
            response.toLowerCase(),
            contains('application/json'),
            reason: '$name: $status',
          );
        }
      }
      await child.stopAndCheck();
    });

    test('client disconnects mid-request and mid-response', () async {
      final child = await _Child.start('bin/server.dart');
      Future<void> partial(String text) async {
        final s = await Socket.connect(
          InternetAddress.loopbackIPv4,
          child.port,
        );
        s.write(text);
        await s.flush();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        s.destroy();
      }

      await partial('GET /health?q=secret HTT');
      await partial('GET /v1/x?q=secret HTTP/1.1\r\nHost: loc');
      await partial(
        'POST /v1/x HTTP/1.1\r\nHost: localhost\r\n'
        'Content-Length: 1000\r\n\r\nsecret',
      );
      await partial(
        'POST /v1/x HTTP/1.1\r\nHost: localhost\r\n'
        'Transfer-Encoding: chunked\r\n\r\n5\r\nsecr',
      );
      final empty = await Socket.connect(
        InternetAddress.loopbackIPv4,
        child.port,
      );
      empty.destroy();
      // Full request, then drop before reading the answer.
      for (var i = 0; i < 30; i++) {
        final s = await Socket.connect(
          InternetAddress.loopbackIPv4,
          child.port,
        );
        s.write(_get('/health?q=secret'));
        await s.flush();
        s.destroy();
      }
      // Half-close after the request.
      final half = await Socket.connect(
        InternetAddress.loopbackIPv4,
        child.port,
      );
      half.write('GET /health HTTP/1.1\r\nHost: localhost\r\n\r\n');
      await half.flush();
      await half.close();
      await half.drain<void>().catchError((Object _) {});

      expect(
        await rawHttp(child.port, _get('/health')),
        startsWith('HTTP/1.1 200'),
      );
      await child.stopAndCheck();
    });

    test('concurrent hostile and normal requests do not interfere', () async {
      final child = await _Child.start('bin/server.dart');
      final results = await Future.wait([
        for (var i = 0; i < 20; i++)
          rawHttp(
            child.port,
            i.isEven
                ? _get(
                    '/v1/x?q=secret',
                    headers: 'X-Forwarded-Host: [secret\r\n',
                  )
                : _get('/health'),
          ),
      ]);
      for (var i = 0; i < results.length; i++) {
        expect(
          results[i],
          startsWith(i.isEven ? 'HTTP/1.1 404' : 'HTTP/1.1 200'),
        );
      }
      await child.stopAndCheck();
    });
  });

  group('throwing /v1 guards against a real bindAndServe', () {
    test(
      'every kind of throw gives the 500 envelope and clean output',
      () async {
        final child = await _Child.start('test/support/guard_server.dart');
        for (final path in [
          '/v1/sync?q=secret',
          '/v1/format?q=secret',
          '/v1/string?q=secret',
          '/v1/later?q=secret',
        ]) {
          final response = await rawHttp(child.port, _get(path));
          expect(response, startsWith('HTTP/1.1 500'), reason: path);
          expect(response, isNot(contains('secret')), reason: path);
          final error = (jsonDecode(rawBody(response)!) as Map)['error'] as Map;
          expect(error['code'], 'internal_error', reason: path);
        }
        expect(
          await rawHttp(child.port, _get('/v1')),
          startsWith('HTTP/1.1 404'),
        );
        // /health is outside the guards.
        expect(
          await rawHttp(child.port, _get('/health')),
          startsWith('HTTP/1.1 200'),
        );
        // A hostile URL is rejected before it reaches the throwing guard.
        final hostile = await rawHttp(
          child.port,
          _get('/v1/sync?q=secret', headers: 'X-Forwarded-Host: [secret\r\n'),
        );
        expect(hostile, startsWith('HTTP/1.1 404'));
        await child.stopAndCheck();

        final records = child.stdoutLines
            .map((l) => jsonDecode(l) as Map<String, dynamic>)
            .toList();
        expect(
          records.where((r) => r['msg'] == 'request' && r['status'] == 500),
          hasLength(4),
        );
      },
    );
  });
}
