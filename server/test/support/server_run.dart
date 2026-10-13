import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:boardgame_server/boardgame_server.dart';

import 'harness.dart';

/// Runs [runServer] in-process on the loopback interface with captured logs,
/// for the database tests (T-019).
final class ServerRun {
  ServerRun(
    this.environment, {
    this.migrations = schemaMigrations,
    this.databaseStartupTimeout = const Duration(seconds: 10),
  });

  final Map<String, String> environment;
  final List<Migration> migrations;
  final Duration databaseStartupTimeout;

  final signals = StreamController<ProcessSignal>();
  final out = LogCapture();
  final err = LogCapture();
  final listening = Completer<HttpServer>();
  late final Future<int> exitCode;
  bool _exited = false;

  /// Whether [runServer] has returned.
  bool get exited => _exited;

  ServerRun start() {
    exitCode = runServer(
      environment: environment,
      shutdownSignals: signals.stream,
      stdoutLine: out.call,
      stderrLine: err.call,
      version: '1.0.0+db',
      databaseStartupTimeout: databaseStartupTimeout,
      migrations: migrations,
      address: InternetAddress.loopbackIPv4,
      onListening: listening.complete,
    ).whenComplete(() => _exited = true);
    return this;
  }

  /// The port, once listening. Fails if the server exits first.
  Future<int> get port async {
    final server = await Future.any<Object>([
      listening.future,
      exitCode.then((code) => code),
    ]);
    if (server is! HttpServer) {
      throw StateError(
        'server exited with $server before listening:\n'
        '${allLines.join('\n')}',
      );
    }
    return server.port;
  }

  /// Sends SIGTERM and returns the exit code.
  Future<int> stop() {
    signals.add(ProcessSignal.sigterm);
    return exitCode;
  }

  /// Every line written to stdout and stderr.
  List<String> get allLines => [...out.lines, ...err.lines];

  /// GET [path] on the running server: status and decoded JSON body.
  Future<(int, Map<String, dynamic>)> get(String path) async {
    final client = HttpClient()..findProxy = (_) => 'DIRECT';
    try {
      final request = await client.get('127.0.0.1', await port, path);
      final response = await request.close();
      final body = await utf8.decodeStream(response);
      return (response.statusCode, jsonDecode(body) as Map<String, dynamic>);
    } finally {
      client.close(force: true);
    }
  }
}
