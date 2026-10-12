import 'dart:convert';
import 'dart:io';

import 'package:boardgame_server/boardgame_server.dart';
import 'package:shelf/shelf.dart';

/// A fixed clock for log timestamps.
final fixedNow = DateTime.utc(2026, 10, 12, 14, 30, 5, 123);

/// Collects log lines in memory and decodes them.
class LogCapture {
  final List<String> lines = [];

  void call(String line) => lines.add(line);

  /// Every line decoded as a JSON object. Fails if a line is not one.
  List<Map<String, dynamic>> get records => [
    for (final line in lines) jsonDecode(line) as Map<String, dynamic>,
  ];

  /// Records whose `msg` is [message].
  List<Map<String, dynamic>> withMessage(String message) =>
      records.where((r) => r['msg'] == message).toList();

  Logger logger({LogLevel minLevel = LogLevel.debug}) =>
      Logger(minLevel: minLevel, sink: call, clock: () => fixedNow);
}

/// The full app pipeline with captured logs.
class TestApp {
  TestApp({
    this.version = '1.2.3+test',
    void Function(Routes v1)? addTestRoutes,
    LogLevel minLevel = LogLevel.debug,
  }) {
    handler = buildApp(
      version: version,
      logger: logs.logger(minLevel: minLevel),
      addTestRoutes: addTestRoutes,
    );
  }

  final String version;
  final LogCapture logs = LogCapture();
  late final Handler handler;

  Future<Response> send(
    String method,
    String pathAndQuery, {
    Map<String, String> headers = const {},
    String? body,
  }) async => handler(
    Request(
      method,
      Uri.parse('http://localhost$pathAndQuery'),
      headers: headers,
      body: body,
    ),
  );

  Future<Response> get(
    String pathAndQuery, {
    Map<String, String> headers = const {},
  }) => send('GET', pathAndQuery, headers: headers);
}

/// Decodes a response body that must be a JSON object, the same check the
/// api_contract README asks clients to make before calling fromJson.
Future<Map<String, dynamic>> jsonObjectOf(Response response) async {
  final decoded = jsonDecode(await response.readAsString());
  if (decoded is! Map<String, dynamic>) {
    throw FormatException('Body is not a JSON object: $decoded');
  }
  return decoded;
}

/// Sends [request] bytes as-is over a raw TCP socket and returns everything
/// the server sends back until it closes the connection (or 5 s pass).
/// Used for requests HttpClient refuses to build, such as a bad Host header.
Future<String> rawHttp(int port, String request) async {
  final socket = await Socket.connect(InternetAddress.loopbackIPv4, port);
  socket.write(request);
  await socket.flush();
  final bytes = <int>[];
  try {
    await socket
        .timeout(const Duration(seconds: 5))
        .forEach(bytes.addAll)
        .catchError((Object _) {});
  } finally {
    socket.destroy();
  }
  return utf8.decode(bytes, allowMalformed: true);
}

/// The body of a raw HTTP/1.1 response, or null if there is no header end.
String? rawBody(String response) {
  final end = response.indexOf('\r\n\r\n');
  return end < 0 ? null : response.substring(end + 4);
}

/// A TCP port that was free a moment ago on the loopback interface.
Future<int> freePort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}
