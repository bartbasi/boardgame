// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app's single database, opened lazily in a background isolate and
/// closed when the provider container is disposed. Tests override it with an
/// in-memory database.

@ProviderFor(appDatabase)
final appDatabaseProvider = AppDatabaseProvider._();

/// The app's single database, opened lazily in a background isolate and
/// closed when the provider container is disposed. Tests override it with an
/// in-memory database.

final class AppDatabaseProvider
    extends $FunctionalProvider<AppDatabase, AppDatabase, AppDatabase>
    with $Provider<AppDatabase> {
  /// The app's single database, opened lazily in a background isolate and
  /// closed when the provider container is disposed. Tests override it with an
  /// in-memory database.
  AppDatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appDatabaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appDatabaseHash();

  @$internal
  @override
  $ProviderElement<AppDatabase> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppDatabase create(Ref ref) {
    return appDatabase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppDatabase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppDatabase>(value),
    );
  }
}

String _$appDatabaseHash() => r'f95a13c7df9192f499f20ac5b96c500cae43eb3d';

/// The store of cached game details and confirmed barcode matches.

@ProviderFor(localGameStore)
final localGameStoreProvider = LocalGameStoreProvider._();

/// The store of cached game details and confirmed barcode matches.

final class LocalGameStoreProvider
    extends $FunctionalProvider<LocalGameStore, LocalGameStore, LocalGameStore>
    with $Provider<LocalGameStore> {
  /// The store of cached game details and confirmed barcode matches.
  LocalGameStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'localGameStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$localGameStoreHash();

  @$internal
  @override
  $ProviderElement<LocalGameStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LocalGameStore create(Ref ref) {
    return localGameStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LocalGameStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LocalGameStore>(value),
    );
  }
}

String _$localGameStoreHash() => r'3429661f3532ae9532b7fa0f0a2604985ee7655f';

/// The details cache the games repository uses. Today it is the same
/// [LocalGameStore]; T-102 re-points this provider to the separate cache
/// database file (PRD Q39).

@ProviderFor(gameDetailsCache)
final gameDetailsCacheProvider = GameDetailsCacheProvider._();

/// The details cache the games repository uses. Today it is the same
/// [LocalGameStore]; T-102 re-points this provider to the separate cache
/// database file (PRD Q39).

final class GameDetailsCacheProvider
    extends
        $FunctionalProvider<
          GameDetailsCache,
          GameDetailsCache,
          GameDetailsCache
        >
    with $Provider<GameDetailsCache> {
  /// The details cache the games repository uses. Today it is the same
  /// [LocalGameStore]; T-102 re-points this provider to the separate cache
  /// database file (PRD Q39).
  GameDetailsCacheProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'gameDetailsCacheProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$gameDetailsCacheHash();

  @$internal
  @override
  $ProviderElement<GameDetailsCache> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GameDetailsCache create(Ref ref) {
    return gameDetailsCache(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GameDetailsCache value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GameDetailsCache>(value),
    );
  }
}

String _$gameDetailsCacheHash() => r'27fe0a182d165d50cc67bd23d6d9bbf2487fec16';

/// The store of confirmed barcode matches the games repository uses. It
/// stays on the main database file (user data).

@ProviderFor(barcodeMatchStore)
final barcodeMatchStoreProvider = BarcodeMatchStoreProvider._();

/// The store of confirmed barcode matches the games repository uses. It
/// stays on the main database file (user data).

final class BarcodeMatchStoreProvider
    extends
        $FunctionalProvider<
          BarcodeMatchStore,
          BarcodeMatchStore,
          BarcodeMatchStore
        >
    with $Provider<BarcodeMatchStore> {
  /// The store of confirmed barcode matches the games repository uses. It
  /// stays on the main database file (user data).
  BarcodeMatchStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'barcodeMatchStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$barcodeMatchStoreHash();

  @$internal
  @override
  $ProviderElement<BarcodeMatchStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BarcodeMatchStore create(Ref ref) {
    return barcodeMatchStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BarcodeMatchStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BarcodeMatchStore>(value),
    );
  }
}

String _$barcodeMatchStoreHash() => r'241e3643b14f589c3a7900695dd5c92719945ad5';
