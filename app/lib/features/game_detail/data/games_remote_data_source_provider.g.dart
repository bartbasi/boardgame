// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'games_remote_data_source_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app's [GamesRemoteDataSource], on the shared API client.

@ProviderFor(gamesRemoteDataSource)
final gamesRemoteDataSourceProvider = GamesRemoteDataSourceProvider._();

/// The app's [GamesRemoteDataSource], on the shared API client.

final class GamesRemoteDataSourceProvider
    extends
        $FunctionalProvider<
          GamesRemoteDataSource,
          GamesRemoteDataSource,
          GamesRemoteDataSource
        >
    with $Provider<GamesRemoteDataSource> {
  /// The app's [GamesRemoteDataSource], on the shared API client.
  GamesRemoteDataSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'gamesRemoteDataSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$gamesRemoteDataSourceHash();

  @$internal
  @override
  $ProviderElement<GamesRemoteDataSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  GamesRemoteDataSource create(Ref ref) {
    return gamesRemoteDataSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GamesRemoteDataSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GamesRemoteDataSource>(value),
    );
  }
}

String _$gamesRemoteDataSourceHash() =>
    r'5d9f0a06561680f8942ccdfc5b619c0fe68ca175';
