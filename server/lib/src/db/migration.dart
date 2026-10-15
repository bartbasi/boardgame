import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:postgres/postgres.dart';

import '../logging/logger.dart';
import 'transaction_control.dart';

/// One schema change, applied once, in its own transaction (T-019 AC1).
///
/// The SQL is embedded in the server binary (the image is `scratch` and has
/// no files besides the executable), so migrations are Dart constants listed
/// in lib/src/db/migrations.dart.
///
/// Rules for the SQL:
/// - It runs inside a transaction, so it must not use statements that refuse
///   to run in one (for example `CREATE INDEX CONCURRENTLY`, `VACUUM`,
///   `CREATE DATABASE`).
/// - It must not control that transaction: no BEGIN, START TRANSACTION,
///   COMMIT (or COMMIT AND CHAIN, COMMIT PREPARED), END, ROLLBACK (or
///   ROLLBACK TO, ROLLBACK PREPARED), ABORT, SAVEPOINT, RELEASE, or
///   PREPARE TRANSACTION as a statement. In the simple query protocol a
///   COMMIT would end the migration's transaction, so a later failure could
///   no longer roll back the statements before it (T-019 AC3, QA T-019-B1).
///   [validateMigrations] refuses them at the start of any statement, after
///   comments, and ignores quoted and dollar-quoted text, so a PL/pgSQL body
///   (`$$ BEGIN ... END; $$`) or a `BEGIN ATOMIC ... END` function body is
///   fine.
/// - A `BEGIN ATOMIC ... END` body (where a `;` does not end the statement)
///   is recognized only in `CREATE [OR REPLACE] FUNCTION` and
///   `CREATE [OR REPLACE] PROCEDURE`, outside parentheses. Anywhere else
///   `begin atomic` is plain words and the next `;` ends the statement. The
///   body ends at an END that starts a body statement (right after ATOMIC
///   or a `;`), as in PostgreSQL's grammar, so CASE ... END or a column
///   labelled `case` or `end` inside a statement does not matter. A body
///   that is never closed with END is refused (T-101).
/// - Each migration starts with `standard_conforming_strings` on, even if an
///   earlier migration turned it off on the same connection, so a backslash
///   in a plain '...' string is never an escape (T-101).
/// - Use `SET LOCAL`, never a plain `SET`: a plain `SET` outlives the
///   migration's transaction, reaches the next migration on the same
///   connection, and after the last one stays on a pooled connection that
///   request queries use later (T-101 review R1-G1).
/// - It may hold several statements separated by semicolons. It is sent with
///   the simple query protocol and takes no parameters.
/// - Never edit a migration once it has been merged: the checksum of every
///   applied migration is stored and checked at startup. Add a new one.
/// - No column for a user id, device id, IP address, or user agent
///   (T-019 AC8, PRD privacy rules).
final class Migration {
  /// Creates a migration.
  const Migration({
    required this.version,
    required this.name,
    required this.sql,
  });

  /// Position in the list: 1, 2, 3, and so on, with no gaps.
  final int version;

  /// Short snake_case description, stored in `schema_migrations.name`.
  final String name;

  /// The statements to run.
  final String sql;

  /// SHA-256 of [sql] in hex, stored in `schema_migrations.checksum`.
  String get checksum => sha256.convert(utf8.encode(sql)).toString();
}

/// Base class for migration problems that stop the server.
sealed class MigrationException implements Exception {
  /// A fixed description; never holds request data or credentials.
  String get message;

  @override
  String toString() => '$runtimeType: $message';
}

/// The migration list or the database's migration history is inconsistent,
/// for example the database is at a version this server does not know, or
/// an applied migration was edited afterwards.
final class MigrationStateException extends MigrationException {
  /// Creates the exception.
  MigrationStateException(this.message);

  @override
  final String message;
}

/// A migration failed; its transaction was rolled back (T-019 AC3).
final class MigrationFailedException extends MigrationException {
  /// Creates the exception for the migration [version] named [name].
  MigrationFailedException({
    required this.version,
    required this.name,
    required this.cause,
    required this.causeStackTrace,
  });

  /// Version of the migration that failed.
  final int version;

  /// Name of the migration that failed.
  final String name;

  /// The error PostgreSQL (or the connection) raised.
  final Object cause;

  /// Where [cause] was thrown.
  final StackTrace causeStackTrace;

  @override
  String get message => 'migration $version ($name) failed and was rolled back';
}

/// What [migrate] did.
final class MigrationReport {
  /// Creates a report.
  const MigrationReport({required this.applied, required this.version});

  /// Versions applied by this run, in order. Empty if the schema was current.
  final List<int> applied;

  /// The schema version after the run (0 for an empty list).
  final int version;
}

/// Name of the table that records applied migrations.
const migrationsTable = 'schema_migrations';

/// Session-level advisory lock key held while migrating, so two server
/// processes started at once cannot apply the same migration twice
/// (https://www.postgresql.org/docs/18/explicit-locking.html#ADVISORY-LOCKS).
/// Any constant works; this one spells "T-019" in its digits.
const migrationLockKey = 7019019;

/// Checks that [migrations] are numbered 1, 2, 3, ... with snake_case names
/// and non-empty SQL without transaction control statements (see
/// [Migration]). Throws [MigrationStateException] otherwise.
void validateMigrations(List<Migration> migrations) {
  final namePattern = RegExp(r'^[a-z][a-z0-9_]{0,62}$');
  for (var i = 0; i < migrations.length; i++) {
    final m = migrations[i];
    if (m.version != i + 1) {
      throw MigrationStateException(
        'migration at position ${i + 1} has version ${m.version}; versions '
        'must be 1, 2, 3, ... in order with no gaps',
      );
    }
    if (!namePattern.hasMatch(m.name)) {
      throw MigrationStateException(
        'migration ${m.version} needs a snake_case name of at most 63 '
        'characters',
      );
    }
    if (m.sql.trim().isEmpty) {
      throw MigrationStateException('migration ${m.version} has no SQL');
    }
    final scan = scanTransactionControl(m.sql);
    final control = scan.statement;
    if (control != null) {
      throw MigrationStateException(
        'migration ${m.version} (${m.name}) contains a $control statement; '
        'every migration already runs in its own transaction, so remove it',
      );
    }
    if (scan.unclosedBody) {
      throw MigrationStateException(
        'migration ${m.version} (${m.name}) has a BEGIN ATOMIC function body '
        'that is not closed; end it with END',
      );
    }
  }
}

/// Applies every migration in [migrations] that the database has not
/// recorded yet, in order, each in its own transaction (T-019 AC1, AC2, AC3).
///
/// Holds [migrationLockKey] as an advisory lock on one pooled connection for
/// the whole run. Creates [migrationsTable] if needed. Before applying
/// anything it checks that the recorded history is a prefix of
/// [migrations] with matching checksums.
///
/// Throws [MigrationStateException] for an inconsistent list or history,
/// [MigrationFailedException] when a migration fails (its changes are rolled
/// back and the versions before it stay applied), and the driver's error if
/// the database cannot be reached before any migration starts.
///
/// [statementTimeout] limits each migration's SQL; the default is generous
/// because a later migration may rewrite a large table.
Future<MigrationReport> migrate(
  Pool<void> pool,
  List<Migration> migrations,
  Logger logger, {
  Duration statementTimeout = const Duration(minutes: 5),
}) async {
  validateMigrations(migrations);
  return pool.withConnection((connection) async {
    await connection.execute(
      Sql.named('SELECT pg_advisory_lock(@key)'),
      parameters: {'key': TypedValue(Type.bigInteger, migrationLockKey)},
    );
    try {
      return await _migrateLocked(
        connection,
        migrations,
        logger,
        statementTimeout,
      );
    } finally {
      // A broken connection is dropped by the pool, which ends the session
      // and with it the lock, so a failure here needs no handling.
      try {
        await connection.execute(
          Sql.named('SELECT pg_advisory_unlock(@key)'),
          parameters: {'key': TypedValue(Type.bigInteger, migrationLockKey)},
        );
      } on Object {
        // See above.
      }
    }
  });
}

Future<MigrationReport> _migrateLocked(
  Connection connection,
  List<Migration> migrations,
  Logger logger,
  Duration statementTimeout,
) async {
  await connection.execute('''
CREATE TABLE IF NOT EXISTS $migrationsTable (
  version integer PRIMARY KEY CHECK (version > 0),
  name text NOT NULL,
  checksum text NOT NULL,
  applied_at timestamptz NOT NULL DEFAULT now()
)''');
  final rows = await connection.execute(
    'SELECT version, name, checksum FROM $migrationsTable ORDER BY version',
  );

  final latest = migrations.length;
  for (var i = 0; i < rows.length; i++) {
    final version = rows[i][0]! as int;
    final checksum = rows[i][2]! as String;
    if (version > latest) {
      throw MigrationStateException(
        'the database schema is at version $version, newer than this '
        "server's latest migration ($latest); deploy a server that knows it",
      );
    }
    if (version != i + 1) {
      throw MigrationStateException(
        '$migrationsTable is missing version ${i + 1}; the history must be '
        '1, 2, 3, ... with no gaps',
      );
    }
    if (checksum != migrations[i].checksum) {
      throw MigrationStateException(
        'migration $version (${migrations[i].name}) was changed after it was '
        'applied; restore its SQL and add a new migration instead',
      );
    }
  }

  final applied = <int>[];
  for (final m in migrations.skip(rows.length)) {
    final watch = Stopwatch()..start();
    try {
      // A migration may change a setting for the rest of the session, and
      // the next one runs on the same connection. With
      // standard_conforming_strings off, PostgreSQL reads a backslash in a
      // plain '...' string as an escape and validateMigrations does not, so
      // each migration starts with it on (T-101, review R3-G1).
      await connection.execute('SET standard_conforming_strings = on');
      await connection.runTx((tx) async {
        await tx.execute(
          m.sql,
          queryMode: QueryMode.simple,
          timeout: statementTimeout,
        );
        await tx.execute(
          Sql.named(
            'INSERT INTO $migrationsTable (version, name, checksum) '
            'VALUES (@version, @name, @checksum)',
          ),
          parameters: {
            'version': TypedValue(Type.integer, m.version),
            'name': TypedValue(Type.text, m.name),
            'checksum': TypedValue(Type.text, m.checksum),
          },
        );
      });
    } on Object catch (e, s) {
      throw MigrationFailedException(
        version: m.version,
        name: m.name,
        cause: e,
        causeStackTrace: s,
      );
    }
    applied.add(m.version);
    logger.info('migration applied', {
      'version': m.version,
      'name': m.name,
      'durationMs': watch.elapsedMilliseconds,
    });
  }

  logger.info('database schema up to date', {
    'version': latest,
    'appliedNow': applied.length,
  });
  return MigrationReport(applied: applied, version: latest);
}
