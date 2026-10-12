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
  const Config({required this.port, required this.logLevel});

  /// TCP port to listen on (PORT, 1 to 65535).
  final int port;

  /// Minimum log level (LOG_LEVEL).
  final LogLevel logLevel;

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

    if (problems.isNotEmpty) throw ConfigException(problems);
    return Config(port: port!, logLevel: logLevel!);
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
