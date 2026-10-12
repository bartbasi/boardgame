// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'api_client_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app's single [ApiClient], configured from
/// `--dart-define=API_BASE_URL=...`.
///
/// Debug builds may use http for a local server; profile and release
/// builds require https (T-013 AC3). Request logging is on only in debug
/// builds and never includes bodies (AC12).

@ProviderFor(apiClient)
final apiClientProvider = ApiClientProvider._();

/// The app's single [ApiClient], configured from
/// `--dart-define=API_BASE_URL=...`.
///
/// Debug builds may use http for a local server; profile and release
/// builds require https (T-013 AC3). Request logging is on only in debug
/// builds and never includes bodies (AC12).

final class ApiClientProvider
    extends $FunctionalProvider<ApiClient, ApiClient, ApiClient>
    with $Provider<ApiClient> {
  /// The app's single [ApiClient], configured from
  /// `--dart-define=API_BASE_URL=...`.
  ///
  /// Debug builds may use http for a local server; profile and release
  /// builds require https (T-013 AC3). Request logging is on only in debug
  /// builds and never includes bodies (AC12).
  ApiClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'apiClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$apiClientHash();

  @$internal
  @override
  $ProviderElement<ApiClient> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ApiClient create(Ref ref) {
    return apiClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ApiClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ApiClient>(value),
    );
  }
}

String _$apiClientHash() => r'2ffcadb0d67e358a99059279355d3351b7e5c469';
