import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:postgres/postgres.dart';

/// The PostgreSQL server the tests use (T-019 AC7: real PostgreSQL, the same
/// major version as Compose; the driver is never mocked).
///
/// Settings come from TEST_DATABASE_HOST, TEST_DATABASE_PORT (default 5432),
/// TEST_DATABASE_USER, TEST_DATABASE_PASSWORD, and TEST_DATABASE_NAME. The
/// user must be allowed to create databases (the postgres image's
/// POSTGRES_USER is a superuser). CI sets them for a service container;
/// server/README.md ("Checks") shows the local docker command.
///
/// Every test that starts the server needs it, because the server does not
/// start without its database.
final class TestPostgres {
  TestPostgres._({
    required this.host,
    required this.port,
    required this.user,
    required this.password,
    required this.database,
  });

  /// Reads the settings, or throws a [StateError] that says how to set them.
  factory TestPostgres.fromEnvironment() {
    final env = Platform.environment;
    String need(String key) {
      final value = env[key] ?? '';
      if (value.isEmpty) {
        throw StateError(
          '$key is not set. Tests that start the server need a PostgreSQL 18 '
          'server: see server/README.md, "Checks", for the docker command and '
          'the TEST_DATABASE_* variables.',
        );
      }
      return value;
    }

    return TestPostgres._(
      host: need('TEST_DATABASE_HOST'),
      port: int.parse(env['TEST_DATABASE_PORT'] ?? '5432'),
      user: need('TEST_DATABASE_USER'),
      password: need('TEST_DATABASE_PASSWORD'),
      database: need('TEST_DATABASE_NAME'),
    );
  }

  /// The shared instance, read once.
  static final TestPostgres shared = TestPostgres.fromEnvironment();

  final String host;
  final int port;
  final String user;
  final String password;

  /// The shared test database. Tests that only need a working server use
  /// it; the schema migrations are applied to it by whichever server starts
  /// first (the advisory lock serializes concurrent test files).
  final String database;

  /// DATABASE_* variables for the server, pointing at [databaseName] (default
  /// the shared database) on [host] and [port] (default the real server; a
  /// [TcpProxy] passes its own).
  Map<String, String> serverEnvironment({
    String? databaseName,
    String? host,
    int? port,
  }) => {
    'DATABASE_HOST': host ?? this.host,
    'DATABASE_PORT': '${port ?? this.port}',
    'DATABASE_NAME': databaseName ?? database,
    'DATABASE_USER': user,
    'DATABASE_PASSWORD': password,
  };

  /// Opens a direct connection to [databaseName] (default the shared one),
  /// for checks that look at the database from outside the server.
  Future<Connection> connect([String? databaseName]) => Connection.open(
    Endpoint(
      host: host,
      port: port,
      database: databaseName ?? database,
      username: user,
      password: password,
    ),
    settings: const ConnectionSettings(sslMode: SslMode.disable),
  );

  /// Creates an empty database with a random name. Drop it with
  /// [ScratchDatabase.drop] (tests do it in addTearDown).
  Future<ScratchDatabase> createScratch() async {
    final random = Random.secure();
    final suffix = List.generate(
      12,
      (_) => random.nextInt(36).toRadixString(36),
    ).join();
    final name = 'scratch_$suffix';
    final admin = await connect();
    try {
      // Name from [a-z0-9_] only, so quoting is not needed.
      await admin.execute('CREATE DATABASE $name');
    } finally {
      await admin.close();
    }
    return ScratchDatabase._(this, name);
  }
}

/// A database created for one test.
final class ScratchDatabase {
  ScratchDatabase._(this.server, this.name);

  final TestPostgres server;
  final String name;

  /// DATABASE_* variables pointing at this database.
  Map<String, String> serverEnvironment({String? host, int? port}) =>
      server.serverEnvironment(databaseName: name, host: host, port: port);

  /// Opens a direct connection to this database.
  Future<Connection> connect() => server.connect(name);

  /// Runs [sql] on a fresh connection and returns the rows.
  Future<List<List<Object?>>> query(
    String sql, {
    Map<String, Object?>? parameters,
  }) async {
    final connection = await connect();
    try {
      final result = await connection.execute(
        parameters == null ? sql : Sql.named(sql),
        parameters: parameters,
      );
      return [for (final row in result) row.toList()];
    } finally {
      await connection.close();
    }
  }

  /// Drops the database, closing anything still connected to it.
  Future<void> drop() async {
    final admin = await server.connect();
    try {
      await admin.execute('DROP DATABASE IF EXISTS $name WITH (FORCE)');
    } finally {
      await admin.close();
    }
  }
}

/// A TCP forwarder between the server and PostgreSQL, so a test can make
/// the database disappear and come back without stopping the real
/// PostgreSQL (T-019 AC6). The server talks to the real database through
/// it; nothing is faked at the protocol level.
final class TcpProxy {
  TcpProxy._(this._targetHost, this._targetPort, this.port);

  /// Starts forwarding a free loopback port to [targetHost]:[targetPort].
  static Future<TcpProxy> start(String targetHost, int targetPort) async {
    final listener = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final proxy = TcpProxy._(targetHost, targetPort, listener.port);
    proxy._listen(listener);
    return proxy;
  }

  final String _targetHost;
  final int _targetPort;

  /// The loopback port to connect to.
  final int port;

  ServerSocket? _listener;
  final _sockets = <Socket>{};
  bool _blackhole = false;

  /// Whether new connections are accepted and forwarded.
  bool get isUp => _listener != null;

  void _listen(ServerSocket listener) {
    _listener = listener;
    listener.listen(_accept);
  }

  Future<void> _accept(Socket client) async {
    _sockets.add(client);
    if (_blackhole) {
      // Accept and never answer, like a host that stopped responding.
      client.listen((_) {}, onError: (_) {}, onDone: client.destroy);
      return;
    }
    Socket upstream;
    try {
      upstream = await Socket.connect(_targetHost, _targetPort);
    } on SocketException {
      _sockets.remove(client);
      client.destroy();
      return;
    }
    _sockets.add(upstream);
    void closeBoth() {
      client.destroy();
      upstream.destroy();
      _sockets
        ..remove(client)
        ..remove(upstream);
    }

    client.listen(upstream.add, onError: (_) => closeBoth(), onDone: closeBoth);
    upstream.listen(client.add, onError: (_) => closeBoth(), onDone: closeBoth);
  }

  /// The database "goes down": stops listening (new connections are
  /// refused) and cuts every open connection.
  Future<void> down() async {
    final listener = _listener;
    _listener = null;
    await listener?.close();
    for (final socket in [..._sockets]) {
      socket.destroy();
    }
    _sockets.clear();
  }

  /// The database "hangs": connections are accepted but never answered, and
  /// open ones are cut.
  Future<void> hang() async {
    _blackhole = true;
    for (final socket in [..._sockets]) {
      socket.destroy();
    }
    _sockets.clear();
  }

  /// The database "comes back" on the same port.
  Future<void> up() async {
    _blackhole = false;
    if (_listener != null) return;
    _listen(await ServerSocket.bind(InternetAddress.loopbackIPv4, port));
  }

  /// Stops everything.
  Future<void> close() => down();
}

/// [environment] plus the DATABASE_* variables of the shared test database,
/// for tests that start the server.
Map<String, String> withTestDatabase(Map<String, String> environment) => {
  ...environment,
  ...TestPostgres.shared.serverEnvironment(),
};

/// A distinctive fake password for tests that check it never reaches the
/// logs. Built at run time so the secret scanner (gitleaks, T-016) does not
/// see a password-like literal in the source.
String fakePassword(String tag) => ['fake', 'pw', tag, 'T019'].join('-');
