// Runs bin/server.dart as a real child process and sends raw requests that
// dart:io cannot turn into a URL, to prove that no request data reaches
// stdout or stderr except through our JSON logger (T-008 review R1-M1).
@Timeout(Duration(minutes: 2))
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../support/harness.dart';
import '../support/database.dart';

/// Requests built to break `HttpRequest.requestedUri` or the request line.
/// Every client-controlled value contains "secret".
const _hostileRequests = {
  'X-Forwarded-Host with an unclosed IPv6 bracket':
      'GET /v1/nope?q=secret-query HTTP/1.1\r\n'
      'Host: localhost\r\n'
      'X-Forwarded-Host: [secret-forwarded-host\r\n'
      'Connection: close\r\n\r\n',
  'X-Forwarded-Proto with spaces':
      'GET /health?q=secret-query HTTP/1.1\r\n'
      'Host: localhost\r\n'
      'X-Forwarded-Proto: a b secret-proto\r\n'
      'Connection: close\r\n\r\n',
  'Host with an unclosed IPv6 bracket':
      'GET /v1/games/1?q=secret-query HTTP/1.1\r\n'
      'Host: [secret-host\r\n'
      'Connection: close\r\n\r\n',
  'non-standard method':
      'SECRETMETHOD /health?q=secret-query HTTP/1.1\r\n'
      'Host: localhost\r\n'
      'Connection: close\r\n\r\n',
  'garbage request line': 'secret garbage\r\n\r\n',
  'normal request with private headers':
      'GET /v1/nope?q=secret-query HTTP/1.1\r\n'
      'Host: localhost\r\n'
      'User-Agent: secret-agent\r\n'
      'X-Forwarded-For: 203.0.113.5\r\n'
      'Connection: close\r\n\r\n',
};

void main() {
  test('hostile requests: stderr stays empty, stdout is only JSON lines, and '
      'no request value is printed (R1-M1)', () async {
    final port = await freePort();
    final process = await Process.start(Platform.resolvedExecutable, [
      'bin/server.dart',
    ], environment: withTestDatabase({'PORT': '$port', 'LOG_LEVEL': 'debug'}));
    final stdoutLines = <String>[];
    final stderrText = StringBuffer();
    final started = Completer<void>();
    final stdoutDone = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .forEach((line) {
          stdoutLines.add(line);
          if (line.contains('"server started"') && !started.isCompleted) {
            started.complete();
          }
        });
    final stderrDone = process.stderr
        .transform(utf8.decoder)
        .forEach(stderrText.write);
    addTearDown(() => process.kill(ProcessSignal.sigkill));

    await started.future.timeout(const Duration(seconds: 60));

    final responses = <String, String>{};
    for (final MapEntry(key: name, value: request)
        in _hostileRequests.entries) {
      responses[name] = await rawHttp(port, request);
    }
    // Give the server a moment to write any late output, then stop it.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    process.kill();
    await process.exitCode.timeout(const Duration(seconds: 15));
    await Future.wait([stdoutDone, stderrDone]);

    expect(stderrText.toString(), isEmpty, reason: 'nothing may reach stderr');
    for (final line in stdoutLines) {
      expect(
        () => jsonDecode(line) as Map<String, dynamic>,
        returnsNormally,
        reason: 'stdout line is not a JSON object: $line',
      );
      expect(line, isNot(contains('secret')), reason: line);
      expect(line, isNot(contains('203.0.113.5')), reason: line);
    }

    // The URL-breaking requests get our envelope, not shelf's plain text.
    for (final name in [
      'X-Forwarded-Host with an unclosed IPv6 bracket',
      'X-Forwarded-Proto with spaces',
    ]) {
      final response = responses[name]!;
      expect(response, startsWith('HTTP/1.1 404'), reason: name);
      expect(
        response.toLowerCase(),
        contains('content-type: application/json'),
      );
      expect(jsonDecode(rawBody(response)!), {
        'error': {'code': 'not_found', 'message': 'Not found.'},
      });
    }
    for (final response in responses.values) {
      expect(response, isNot(contains('secret')));
      expect(response, isNot(contains('Bad Request')));
      expect(response, isNot(contains('Internal Server Error')));
    }

    // Every request that dart:io accepted wrote one request line.
    final requestLines = stdoutLines
        .map((l) => jsonDecode(l) as Map<String, dynamic>)
        .where((r) => r['msg'] == 'request')
        .toList();
    expect(requestLines, isNotEmpty);
    for (final r in requestLines) {
      expect(r['method'], anyOf('GET', '<other>'));
    }
  });
}
