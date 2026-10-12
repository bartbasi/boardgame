import '../../domain/result.dart';

/// Where the app's backend lives. Built from the `API_BASE_URL`
/// `--dart-define` by [ApiConfig.parse].
final class ApiConfig {
  const ApiConfig._(this.baseUri);

  /// The backend base URL with no trailing slash, for example
  /// `https://api.example.test`. Request paths such as `/v1/lookup` are
  /// appended to it.
  final Uri baseUri;

  /// The value of `--dart-define=API_BASE_URL=...`, or an empty string.
  static const String fromEnvironment = String.fromEnvironment('API_BASE_URL');

  /// Parses [raw] into a config.
  ///
  /// Returns a [ConfigurationFailure] when [raw] is empty, is not an
  /// absolute http or https URL with a host, has a query, fragment, or user
  /// info, or uses http while [allowInsecureHttp] is false. Release and
  /// profile builds pass false; debug builds pass true so a developer can
  /// use a local server over http [ASSUMPTION, T-013 AC3].
  static Result<ApiConfig> parse(
    String raw, {
    required bool allowInsecureHttp,
  }) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return const Err(
        ConfigurationFailure(ConfigurationProblem.missingBaseUrl),
      );
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        !uri.isAbsolute ||
        uri.host.isEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.userInfo.isNotEmpty ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      return const Err(
        ConfigurationFailure(ConfigurationProblem.malformedBaseUrl),
      );
    }
    if (uri.scheme == 'http' && !allowInsecureHttp) {
      return const Err(
        ConfigurationFailure(ConfigurationProblem.insecureBaseUrl),
      );
    }
    var path = uri.path;
    while (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return Ok(ApiConfig._(uri.replace(path: path)));
  }

  @override
  String toString() => 'ApiConfig($baseUri)';
}
