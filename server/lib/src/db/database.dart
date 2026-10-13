import 'package:postgres/postgres.dart';

import '../config/database_config.dart';

/// How long opening one connection may take, waiting for a free pool slot
/// included.
const databaseConnectTimeout = Duration(seconds: 5);

/// Default limit for one query. Migrations pass their own, longer limit.
const databaseQueryTimeout = Duration(seconds: 10);

/// What the server learned about the database at startup, for the
/// `database ready` log line.
final class DatabaseInfo {
  /// Creates the info.
  const DatabaseInfo({
    required this.serverVersion,
    required this.localeProvider,
    required this.locale,
    required this.encoding,
  });

  /// `server_version`, for example `18.6`.
  final String serverVersion;

  /// `builtin`, `icu`, or `libc` (pg_database.datlocprovider).
  final String localeProvider;

  /// The builtin or ICU locale (pg_database.datlocale), or LC_COLLATE for
  /// libc.
  final String locale;

  /// The database encoding, for example `UTF8`.
  final String encoding;
}

/// The PostgreSQL connection pool (T-019).
///
/// One per server process. Connections open lazily, up to
/// [DatabaseConfig.poolMax] at a time; a connection that failed is dropped
/// and replaced on next use, so the pool recovers by itself when the
/// database comes back.
final class Database {
  Database._(this.pool);

  /// Creates the pool. Opens no connection yet.
  ///
  /// TLS is off: PostgreSQL is reached only over the internal Compose
  /// network `db`, which has no route outside the host (deploy/README.md).
  /// The postgres image's default password method for network connections
  /// is scram-sha-256, so the password is not sent in clear text either.
  factory Database.open(DatabaseConfig config) => Database._(
    Pool<void>.withEndpoints(
      [
        Endpoint(
          host: config.host,
          port: config.port,
          database: config.name,
          username: config.user,
          password: config.password,
        ),
      ],
      settings: PoolSettings(
        maxConnectionCount: config.poolMax,
        connectTimeout: databaseConnectTimeout,
        queryTimeout: databaseQueryTimeout,
        sslMode: SslMode.disable,
        applicationName: 'boardgame-server',
      ),
    ),
  );

  /// The pool, for queries. Each call borrows a connection and returns it.
  final Pool<void> pool;

  /// Runs `SELECT 1`. Throws if the database cannot be reached or does not
  /// answer within [timeout].
  Future<void> ping({Duration timeout = databaseQueryTimeout}) async {
    await pool.execute('SELECT 1', timeout: timeout);
  }

  /// Reads the server version and the current database's locale settings.
  Future<DatabaseInfo> info() async {
    final rows = await pool.execute('''
SELECT current_setting('server_version'),
       CASE d.datlocprovider WHEN 'b' THEN 'builtin' WHEN 'i' THEN 'icu'
                             WHEN 'c' THEN 'libc' ELSE d.datlocprovider::text END,
       coalesce(d.datlocale, d.datcollate),
       pg_encoding_to_char(d.encoding)
FROM pg_database d
WHERE d.datname = current_database()''');
    final row = rows.single;
    return DatabaseInfo(
      serverVersion: row[0]! as String,
      localeProvider: row[1]! as String,
      locale: row[2]! as String,
      encoding: row[3]! as String,
    );
  }

  /// Closes every connection. Waits for borrowed connections to come back.
  Future<void> close() => pool.close();
}
