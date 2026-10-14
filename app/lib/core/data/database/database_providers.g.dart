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
