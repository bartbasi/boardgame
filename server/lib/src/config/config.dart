import 'dart:io';

import '../http/rate_limiter.dart';
import '../logging/logger.dart';

/// Thrown by [Config.load] when one or more variables are missing or invalid.
///
/// [problems] names each variable and what it must be. It never contains a
/// variable's value, so the message is safe to print and log.
class ConfigException implements Exception {
  /// Creates an exception listing [problems].
  ConfigException(List<String> problems)
    : problems = List.unmodifiable(problems);

  /// One entry per missing or invalid variable.
  final List<String> problems;

  /// A single line naming every problem.
  String get message => 'Invalid configuration: ${problems.join(' ')}';

  @override
  String toString() => 'ConfigException: $message';
}

/// Server configuration, read once at startup from environment variables.
///
/// server/.env.example must list exactly the variables read here
/// (test/config/env_example_test.dart checks this).
final class Config {
  /// Creates a config. Use [load] in production code.
  const Config({
    required this.port,
    required this.logLevel,
    this.rateLimitPerMinute = defaultRateLimitPerWindow,
    this.rateLimitMaxTrackedIps = defaultRateLimitMaxTracked,
    this.trustedProxies = const [],
  });

  /// TCP port to listen on (PORT, 1 to 65535).
  final int port;

  /// Minimum log level (LOG_LEVEL).
  final LogLevel logLevel;

  /// Requests allowed per client IP per minute on /v1 (RATE_LIMIT_PER_MINUTE,
  /// default [defaultRateLimitPerWindow], T-020 AC1).
  final int rateLimitPerMinute;

  /// Most client IPs the rate limiter tracks at once
  /// (RATE_LIMIT_MAX_TRACKED_IPS, default [defaultRateLimitMaxTracked],
  /// T-020 AC7).
  final int rateLimitMaxTrackedIps;

  /// Peers whose X-Forwarded-For is trusted (TRUSTED_PROXY_ADDRESSES, a
  /// comma-separated list of IP addresses; default none, T-020 AC4). In
  /// Compose this is Caddy's fixed address on the `web` network.
  final List<InternetAddress> trustedProxies;

  /// Largest RATE_LIMIT_PER_MINUTE accepted [ASSUMPTION].
  static const maxRateLimitPerMinute = 10000;

  /// Largest RATE_LIMIT_MAX_TRACKED_IPS accepted [ASSUMPTION]. The limiter
  /// holds about 5 MB per 100,000 entries, and the process grew by up to
  /// 10 MB while filling them (server/README.md), so this keeps the limiter
  /// well inside the server container's 64 MB.
  static const maxRateLimitMaxTrackedIps = 200000;

  /// Most entries in TRUSTED_PROXY_ADDRESSES.
  static const maxTrustedProxies = 10;

  /// Reads and validates every variable from [environment].
  ///
  /// Collects all problems before failing, so one run reports every missing
  /// or invalid variable. Throws [ConfigException] if there is any problem.
  /// An empty value counts as missing.
  static Config load(Map<String, String> environment) {
    final problems = <String>[];

    final port = _read(
      environment,
      'PORT',
      problems,
      'must be an integer from 1 to 65535',
      _parsePort,
    );
    final logLevel = _read(
      environment,
      'LOG_LEVEL',
      problems,
      'must be one of: ${LogLevel.values.map((l) => l.name).join(', ')}',
      LogLevel.tryParse,
    );

    final perMinute = _optional(
      environment,
      'RATE_LIMIT_PER_MINUTE',
      problems,
      'must be an integer from 1 to $maxRateLimitPerMinute '
          '(default $defaultRateLimitPerWindow)',
      defaultRateLimitPerWindow,
      (raw) => _parseInt(raw, 1, maxRateLimitPerMinute),
    );
    final maxTracked = _optional(
      environment,
      'RATE_LIMIT_MAX_TRACKED_IPS',
      problems,
      'must be an integer from 1 to $maxRateLimitMaxTrackedIps '
          '(default $defaultRateLimitMaxTracked)',
      defaultRateLimitMaxTracked,
      (raw) => _parseInt(raw, 1, maxRateLimitMaxTrackedIps),
    );
    final trusted = _optional(
      environment,
      'TRUSTED_PROXY_ADDRESSES',
      problems,
      'must be a comma-separated list of at most $maxTrustedProxies IP '
          'addresses (default none)',
      const <InternetAddress>[],
      _parseAddresses,
    );

    if (problems.isNotEmpty) throw ConfigException(problems);
    return Config(
      port: port!,
      logLevel: logLevel!,
      rateLimitPerMinute: perMinute!,
      rateLimitMaxTrackedIps: maxTracked!,
      trustedProxies: trusted!,
    );
  }

  static T? _optional<T extends Object>(
    Map<String, String> environment,
    String name,
    List<String> problems,
    String rule,
    T fallback,
    T? Function(String raw) parse,
  ) {
    final raw = environment[name]?.trim() ?? '';
    if (raw.isEmpty) return fallback;
    final value = parse(raw);
    if (value == null) problems.add('$name is invalid; it $rule.');
    return value;
  }

  static int? _parseInt(String raw, int min, int max) {
    if (!RegExp(r'^[0-9]{1,7}$').hasMatch(raw)) return null;
    final value = int.parse(raw);
    return value >= min && value <= max ? value : null;
  }

  static List<InternetAddress>? _parseAddresses(String raw) {
    final parts = raw.split(',').map((p) => p.trim()).toList();
    if (parts.length > maxTrustedProxies) return null;
    final result = <InternetAddress>[];
    for (final part in parts) {
      final address = InternetAddress.tryParse(part);
      if (address == null) return null;
      result.add(address);
    }
    return List.unmodifiable(result);
  }

  static T? _read<T extends Object>(
    Map<String, String> environment,
    String name,
    List<String> problems,
    String rule,
    T? Function(String raw) parse,
  ) {
    final raw = environment[name]?.trim() ?? '';
    if (raw.isEmpty) {
      problems.add('$name is missing; it $rule.');
      return null;
    }
    final value = parse(raw);
    if (value == null) problems.add('$name is invalid; it $rule.');
    return value;
  }

  static int? _parsePort(String raw) {
    if (!RegExp(r'^[0-9]{1,5}$').hasMatch(raw)) return null;
    final port = int.parse(raw);
    return port >= 1 && port <= 65535 ? port : null;
  }
}
