/// Backend API for the Board Game Collector app.
library;

export 'src/app.dart' show buildApp, healthResponse;
export 'src/cli.dart'
    show Command, healthcheckFlag, parseCommand, runMain, usageErrorExitCode;
export 'src/healthcheck.dart'
    show healthcheckTimeout, healthyExitCode, runHealthcheck, unhealthyExitCode;
export 'src/config/config.dart' show Config, ConfigException;
export 'src/config/database_config.dart' show DatabaseConfig;
export 'src/db/database.dart'
    show Database, DatabaseInfo, databaseConnectTimeout, databaseQueryTimeout;
export 'src/db/database_health.dart'
    show DatabaseHealth, databaseHealthCacheFor, databaseHealthTimeout;
export 'src/db/migration.dart'
    show
        Migration,
        MigrationException,
        MigrationFailedException,
        MigrationReport,
        MigrationStateException,
        migrate,
        migrationLockKey,
        migrationsTable,
        validateMigrations;
export 'src/db/migrations.dart' show schemaMigrations;
export 'src/db/transaction_control.dart' show findTransactionControl;
export 'src/http/middleware.dart'
    show loggableMethod, otherMethod, unmatchedRoute;
export 'src/http/serve.dart' show bindAndServe, serverIdleTimeout;
export 'src/logging/error_description.dart'
    show describeError, maxErrorDescriptionLength;
export 'src/http/responses.dart'
    show errorResponse, internalErrorResponse, jsonResponse, notFoundResponse;
export 'src/http/routes.dart' show RouteSlot, Routes;
export 'src/logging/logger.dart' show LogLevel, Logger;
export 'src/server_runner.dart'
    show
        configErrorExitCode,
        databaseRetryInterval,
        databaseUnavailableExitCode,
        defaultDatabaseStartupTimeout,
        defaultShutdownGrace,
        listenErrorExitCode,
        migrationFailedExitCode,
        permanentStartupSqlStates,
        runServer;
export 'src/version.dart' show appVersion;
