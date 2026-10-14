import 'dart:convert';

import 'config.dart';

/// PostgreSQL connection settings, read once at startup from environment
/// variables (T-019 AC4, AC5).
///
/// server/.env.example lists every variable read here, next to the ones
/// [Config.load] reads (test/config/env_example_test.dart checks this).
///
/// The password is held only in memory: [toString] and every
/// [ConfigException] problem leave it out, like every other value.
final class DatabaseConfig {
  /// Creates a config. Use [load] in production code.
  const DatabaseConfig({
    required this.host,
    required this.port,
    required this.name,
    required this.user,
    required this.password,
    required this.poolMax,
  });

  /// Host name or IP address of the PostgreSQL server (DATABASE_HOST).
  final String host;

  /// TCP port (DATABASE_PORT, default [defaultPort]).
  final int port;

  /// Database name (DATABASE_NAME).
  final String name;

  /// Login role (DATABASE_USER).
  final String user;

  /// Password of [user] (DATABASE_PASSWORD). Never logged or printed.
  final String password;

  /// Maximum number of open connections in the pool (DATABASE_POOL_MAX,
  /// default [defaultPoolMax]).
  final int poolMax;

  /// PostgreSQL's default port.
  static const defaultPort = 5432;

  /// Default pool size [ASSUMPTION: 5, T-019 AC5].
  static const defaultPoolMax = 5;

  /// Largest allowed pool size. PostgreSQL allows 100 connections by default
  /// (max_connections), and each connection is a PostgreSQL process with its
  /// own memory, inside the database container's 256 MB limit.
  static const maxPoolMax = 20;

  /// PostgreSQL truncates identifiers longer than 63 bytes (NAMEDATALEN - 1,
  /// https://www.postgresql.org/docs/18/sql-syntax-lexical.html#SQL-SYNTAX-IDENTIFIERS).
  static const maxIdentifierBytes = 63;

  /// Reads and validates every database variable from [environment].
  ///
  /// Collects all problems before failing, like [Config.load], and throws a
  /// [ConfigException] that names each variable and never holds a value.
  /// An empty value counts as missing; DATABASE_PORT and DATABASE_POOL_MAX
  /// fall back to their defaults when missing.
  static DatabaseConfig load(Map<String, String> environment) {
    final problems = <String>[];
    String? read(String key) {
      final raw = environment[key]?.trim() ?? '';
      return raw.isEmpty ? null : raw;
    }

    T? required<T extends Object>(
      String key,
      String rule,
      T? Function(String raw) parse,
    ) {
      final raw = read(key);
      if (raw == null) {
        problems.add('$key is missing; it $rule.');
        return null;
      }
      final value = parse(raw);
      if (value == null) problems.add('$key is invalid; it $rule.');
      return value;
    }

    T? optional<T extends Object>(
      String key,
      String rule,
      T fallback,
      T? Function(String raw) parse,
    ) {
      final raw = read(key);
      if (raw == null) return fallback;
      final value = parse(raw);
      if (value == null) problems.add('$key is invalid; it $rule.');
      return value;
    }

    final host = required(
      'DATABASE_HOST',
      'must be a host name or IP address without spaces',
      _parseHost,
    );
    final port = optional(
      'DATABASE_PORT',
      'must be an integer from 1 to 65535 (default $defaultPort)',
      defaultPort,
      (raw) => _parseInt(raw, 1, 65535),
    );
    final name = required(
      'DATABASE_NAME',
      'must be a database name of at most $maxIdentifierBytes bytes',
      _parseIdentifier,
    );
    final user = required(
      'DATABASE_USER',
      'must be a role name of at most $maxIdentifierBytes bytes',
      _parseIdentifier,
    );
    // Taken as-is (no trim beyond the empty check): a password may legally
    // contain any character. The raw value is never echoed.
    final password = environment['DATABASE_PASSWORD'];
    if (password == null || password.trim().isEmpty) {
      problems.add('DATABASE_PASSWORD is missing; it must be set.');
    }
    final poolMax = optional(
      'DATABASE_POOL_MAX',
      'must be an integer from 1 to $maxPoolMax (default $defaultPoolMax)',
      defaultPoolMax,
      (raw) => _parseInt(raw, 1, maxPoolMax),
    );

    if (problems.isNotEmpty) throw ConfigException(problems);
    return DatabaseConfig(
      host: host!,
      port: port!,
      name: name!,
      user: user!,
      password: password!,
      poolMax: poolMax!,
    );
  }

  static String? _parseHost(String raw) =>
      raw.length <= 253 && RegExp(r'^[A-Za-z0-9._:\-\[\]]+$').hasMatch(raw)
      ? raw
      : null;

  static String? _parseIdentifier(String raw) =>
      raw.codeUnits.every((c) => c >= 0x20 && c != 0x7f) &&
          utf8.encode(raw).length <= maxIdentifierBytes
      ? raw
      : null;

  static int? _parseInt(String raw, int min, int max) {
    if (!RegExp(r'^[0-9]{1,5}$').hasMatch(raw)) return null;
    final value = int.parse(raw);
    return value >= min && value <= max ? value : null;
  }

  /// Names the target without the password, for debugging only. The server
  /// does not log it: host and user names are configuration, not secrets, but
  /// logs carry only what an operator needs.
  @override
  String toString() =>
      'DatabaseConfig(host: $host, port: $port, name: $name, user: $user, '
      'password: <redacted>, poolMax: $poolMax)';
}
