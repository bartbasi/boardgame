// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'games_repository_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app's [GamesRepository]: the backend plus the on-device stores.
/// Screens read this provider; tests override it with a fake.

@ProviderFor(gamesRepository)
final gamesRepositoryProvider = GamesRepositoryProvider._();

/// The app's [GamesRepository]: the backend plus the on-device stores.
/// Screens read this provider; tests override it with a fake.

final class GamesRepositoryProvider
    extends
        $FunctionalProvider<GamesRepository, GamesRepository, GamesRepository>
    with $Provider<GamesRepository> {
  /// The app's [GamesRepository]: the backend plus the on-device stores.
  /// Screens read this provider; tests override it with a fake.
  GamesRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'gamesRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$gamesRepositoryHash();

  @$internal
  @override
  $ProviderElement<GamesRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GamesRepository create(Ref ref) {
    return gamesRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GamesRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GamesRepository>(value),
    );
  }
}

String _$gamesRepositoryHash() => r'a34a0728031fb1aed8b9bf40d37a78d1bee2a0c9';
