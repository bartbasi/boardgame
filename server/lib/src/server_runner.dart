import 'dart:async';
import 'dart:io';

import 'package:postgres/postgres.dart';

import 'app.dart';
import 'config/config.dart';
import 'config/database_config.dart';
import 'db/database.dart';
import 'db/database_health.dart';
import 'db/migration.dart';
import 'db/migrations.dart';
import 'http/rate_limit.dart';
import 'http/rate_limiter.dart';
import 'http/routes.dart';
import 'http/serve.dart';
import 'logging/logger.dart';
import 'version.dart';

/// Exit code for a missing or invalid configuration (sysexits EX_CONFIG).
const configErrorExitCode = 78;

/// Exit code when the server cannot listen, for example the port is in use.
const listenErrorExitCode = 1;

/// Exit code when PostgreSQL cannot be reached within the startup timeout
/// (sysexits EX_UNAVAILABLE).
const databaseUnavailableExitCode = 69;

/// Exit code when a migration fails or the migration history does not match
/// this server (sysexits EX_SOFTWARE, T-019 AC3).
const migrationFailedExitCode = 70;

/// How long in-flight requests may run after a shutdown signal
/// [ASSUMPTION: 10 s, T-008 AC9].
const defaultShutdownGrace = Duration(seconds: 10);

/// How long startup keeps trying to reach PostgreSQL before it gives up with
/// [databaseUnavailableExitCode]. Compose starts the server only after the
/// database is healthy, so this covers short restarts and slow networks.
const defaultDatabaseStartupTimeout = Duration(seconds: 30);

/// Pause between startup connection attempts.
const databaseRetryInterval = Duration(seconds: 1);

/// Loads config, connects to PostgreSQL, applies pending migrations, then
/// serves HTTP until the first event on [shutdownSignals] and shuts down
/// gracefully. Returns the process exit code.
///
/// Startup, in order (T-019):
/// 1. Config: on any missing or invalid variable, one JSON line on
///    [stderrLine] names every problem (never a value) and the result is
///    [configErrorExitCode].
/// 2. Database: retries `SELECT 1` every [databaseRetryInterval] for up to
///    [databaseStartupTimeout], then gives up with
///    [databaseUnavailableExitCode].
/// 3. Migrations ([migrations], default [schemaMigrations]): a failure is
///    logged with its version and name and returns
///    [migrationFailedExitCode]; nothing listens.
/// 4. Listen.
///
/// A shutdown signal during steps 2 and 3 stops startup after the current
/// step and returns 0.
///
/// Shutdown stops accepting connections at once, lets in-flight requests
/// finish for up to [shutdownGrace], closes whatever is left, closes the
/// database pool, and returns 0.
///
/// [address] defaults to all IPv4 interfaces, as needed inside a container.
/// [onListening], [addTestRoutes], and [periodicTimer] (creates the rate
/// limiter's sweep timer) are test hooks.
Future<int> runServer({
  required Map<String, String> environment,
  required Stream<ProcessSignal> shutdownSignals,
  required void Function(String line) stdoutLine,
  required void Function(String line) stderrLine,
  String version = appVersion,
  Duration shutdownGrace = defaultShutdownGrace,
  Duration databaseStartupTimeout = defaultDatabaseStartupTimeout,
  List<Migration> migrations = schemaMigrations,
  Object? address,
  DateTime Function() clock = DateTime.now,
  void Function(HttpServer server)? onListening,
  void Function(Routes v1)? addTestRoutes,
  PeriodicTimerFactory periodicTimer = Timer.periodic,
}) async {
  final Config config;
  final DatabaseConfig databaseConfig;
  try {
    (config, databaseConfig) = _loadConfig(environment);
  } on ConfigException catch (e) {
    Logger(
      minLevel: LogLevel.error,
      sink: stderrLine,
      clock: clock,
    ).error(e.message);
    return configErrorExitCode;
  }

  final logger = Logger(
    minLevel: config.logLevel,
    sink: stdoutLine,
    clock: clock,
  );

  final shutdown = Completer<ProcessSignal>();
  final signalSubscription = shutdownSignals.listen((signal) {
    if (!shutdown.isCompleted) shutdown.complete(signal);
  });

  final database = Database.open(databaseConfig);
  Timer? sweep;
  try {
    final startup = await _prepareDatabase(
      database,
      migrations,
      logger,
      databaseStartupTimeout,
      shutdown.future,
    );
    if (startup != null) return startup;

    final databaseHealth = DatabaseHealth(
      probe: () => database.ping(timeout: databaseConnectTimeout),
      onChange: (up) => up
          ? logger.info('database available again')
          : logger.warning('database unavailable'),
    );
    // Per-IP rate limiting (T-020) is the first /v1 guard; attestation
    // (T-066) goes after it.
    final limiter = RateLimiter(
      limit: config.rateLimitPerMinute,
      maxTracked: config.rateLimitMaxTrackedIps,
      onFull: logRateLimiterFull(logger, config.rateLimitMaxTrackedIps),
    );
    // Removes expired entries even when no request arrives (T-020 AC6);
    // cancelled in `finally`.
    sweep = startRateLimitSweep(limiter, periodic: periodicTimer);
    final handler = buildApp(
      version: version,
      logger: logger,
      databaseHealth: databaseHealth,
      v1Middleware: [
        rateLimit(
          limiter,
          ClientAddressResolver(
            trustedProxies: config.trustedProxies,
            onUnusableForwarded: logUnusableForwarded(logger),
          ),
        ),
      ],
      addTestRoutes: addTestRoutes,
    );

    final HttpServer server;
    try {
      server = await bindAndServe(
        handler,
        address ?? InternetAddress.anyIPv4,
        config.port,
        logger,
      );
    } on SocketException catch (e) {
      logger.error(
        'could not listen',
        fields: {
          'port': config.port,
          'reason': e.osError?.message ?? e.message,
        },
      );
      return listenErrorExitCode;
    }
    logger.info('server started', {'port': server.port, 'version': version});
    onListening?.call(server);

    final signal = await shutdown.future;
    logger.info('shutdown started', {
      'signal': signal.toString(),
      'graceMs': shutdownGrace.inMilliseconds,
    });

    // close() stops listening at once and closes idle keep-alive
    // connections; active connections close after their response is
    // written.
    await server.close();
    final drained = await _waitForConnections(server, shutdownGrace);
    if (!drained) {
      final left = server.connectionsInfo().total;
      logger.warning('shutdown grace period expired', {
        'openConnections': left,
      });
      await server.close(force: true);
    }
    logger.info('shutdown complete');
    return 0;
  } finally {
    sweep?.cancel();
    await signalSubscription.cancel();
    await _closeDatabase(database, logger);
  }
}

(Config, DatabaseConfig) _loadConfig(Map<String, String> environment) {
  // Both loaders run even if the first fails, so one line names every
  // problem.
  final problems = <String>[];
  Config? config;
  DatabaseConfig? databaseConfig;
  try {
    config = Config.load(environment);
  } on ConfigException catch (e) {
    problems.addAll(e.problems);
  }
  try {
    databaseConfig = DatabaseConfig.load(environment);
  } on ConfigException catch (e) {
    problems.addAll(e.problems);
  }
  if (problems.isNotEmpty) throw ConfigException(problems);
  return (config!, databaseConfig!);
}

/// Waits for the database, logs what it is, and migrates. Returns null to
/// go on serving, or the exit code to stop with.
Future<int?> _prepareDatabase(
  Database database,
  List<Migration> migrations,
  Logger logger,
  Duration startupTimeout,
  Future<ProcessSignal> shutdown,
) async {
  var stopRequested = false;
  unawaited(shutdown.then((_) => stopRequested = true));

  final reachable = await _waitForDatabase(
    database,
    logger,
    startupTimeout,
    () => stopRequested,
    shutdown,
  );
  if (stopRequested) return _stoppedDuringStartup(logger);
  if (!reachable) return databaseUnavailableExitCode;

  try {
    final info = await database.info();
    logger.info('database ready', {
      'serverVersion': info.serverVersion,
      'localeProvider': info.localeProvider,
      'locale': info.locale,
      'encoding': info.encoding,
    });
    await migrate(database.pool, migrations, logger);
  } on MigrationFailedException catch (e) {
    final cause = e.cause;
    logger.error(
      'migration failed',
      error: cause,
      stackTrace: e.causeStackTrace,
      fields: {
        'version': e.version,
        'name': e.name,
        // The SQL is ours, so PostgreSQL's message about it holds no request
        // data and is safe to log (describeError keeps only the SQLSTATE).
        if (cause is ServerException) 'dbMessage': cause.message,
        if (cause is ServerException && cause.position != null)
          'position': cause.position,
      },
    );
    return migrationFailedExitCode;
  } on MigrationStateException catch (e) {
    logger.error('migrations cannot run', fields: {'reason': e.message});
    return migrationFailedExitCode;
  } on ServerException catch (e, s) {
    // PostgreSQL refused the bookkeeping before any migration started, for
    // example the role may not create tables (SQLSTATE 42501).
    logger.error('migrations could not start', error: e, stackTrace: s);
    return migrationFailedExitCode;
  } on Object catch (e, s) {
    // Lost the connection before any migration started.
    logger.error(
      'database unavailable during startup',
      error: e,
      stackTrace: s,
    );
    return databaseUnavailableExitCode;
  }
  if (stopRequested) return _stoppedDuringStartup(logger);
  return null;
}

int _stoppedDuringStartup(Logger logger) {
  logger.info('shutdown during startup');
  logger.info('shutdown complete');
  return 0;
}

/// SQLSTATE codes that make the startup wait for PostgreSQL give up at once
/// instead of retrying (https://www.postgresql.org/docs/18/errcodes-appendix.html):
/// 28P01 invalid_password, 28000 invalid_authorization_specification (for
/// example no such role, or pg_hba.conf refuses it), and 3D000
/// invalid_catalog_name (no such database). Other errors, such as a refused
/// socket or 57P03 cannot_connect_now while PostgreSQL starts, are retried.
const permanentStartupSqlStates = {'28P01', '28000', '3D000'};

Future<bool> _waitForDatabase(
  Database database,
  Logger logger,
  Duration timeout,
  bool Function() stopRequested,
  Future<ProcessSignal> shutdown,
) async {
  final elapsed = Stopwatch()..start();
  var attempts = 0;
  while (true) {
    attempts++;
    try {
      await database.ping(timeout: databaseConnectTimeout);
      if (attempts > 1) {
        logger.info('database reachable', {'attempts': attempts});
      }
      return true;
    } on Object catch (e) {
      if (stopRequested()) return false;
      if (e is ServerException && permanentStartupSqlStates.contains(e.code)) {
        // Retrying cannot help: the settings are wrong. Fail at once so the
        // operator does not wait for the whole startup timeout. Same message
        // as the timeout case, so alerts and tests match one line;
        // `permanent` tells them apart.
        logger.error(
          'database unreachable',
          error: e,
          fields: {'attempts': attempts, 'permanent': true},
        );
        return false;
      }
      if (elapsed.elapsed + databaseRetryInterval >= timeout) {
        logger.error(
          'database unreachable',
          error: e,
          fields: {'attempts': attempts, 'timeoutMs': timeout.inMilliseconds},
        );
        return false;
      }
      if (attempts == 1) {
        logger.warning('database not reachable yet, retrying', {
          'errorType': e.runtimeType.toString(),
          'retryMs': databaseRetryInterval.inMilliseconds,
          'timeoutMs': timeout.inMilliseconds,
        });
      }
    }
    await Future.any<Object?>([
      Future<void>.delayed(databaseRetryInterval),
      shutdown,
    ]);
    if (stopRequested()) return false;
  }
}

Future<void> _closeDatabase(Database database, Logger logger) async {
  try {
    await database.close().timeout(const Duration(seconds: 5));
  } on Object catch (e) {
    logger.warning('database pool did not close cleanly', {
      'errorType': e.runtimeType.toString(),
    });
  }
}

Future<bool> _waitForConnections(HttpServer server, Duration grace) async {
  final deadline = Stopwatch()..start();
  while (server.connectionsInfo().total > 0) {
    if (deadline.elapsed >= grace) return false;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  return true;
}
