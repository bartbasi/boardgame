// Child process used by test/qa/serve_edge_cases_test.dart. Serves the real
// app pipeline through bindAndServe with /v1 guards that throw. Not part of
// production code. Usage: dart test/support/guard_server.dart <port>
import 'dart:io';

import 'package:boardgame_server/boardgame_server.dart';

Future<void> main(List<String> args) async {
  final logger = Logger(minLevel: LogLevel.debug, sink: stdout.writeln);
  final handler = buildApp(
    version: 'guard-test',
    logger: logger,
    v1Middleware: [
      (inner) => (request) async {
        final path = request.requestedUri.path;
        if (path.contains('sync')) {
          throw StateError('guard msg ${request.requestedUri}');
        }
        if (path.contains('format')) {
          throw const FormatException('bad', 'src-value');
        }
        if (path.contains('string')) {
          // ignore: only_throw_errors
          throw 'string-throw-value';
        }
        if (path.contains('later')) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          throw StateError('late msg');
        }
        return inner(request);
      },
    ],
  );
  await bindAndServe(
    handler,
    InternetAddress.loopbackIPv4,
    int.parse(args.single),
    logger,
  );
  logger.info('server started');
}
