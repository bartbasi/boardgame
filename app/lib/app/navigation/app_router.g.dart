// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_router.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app's router: one branch per destination, each with its own navigator,
/// so every destination keeps its back stack and scroll position
/// (docs/ux/screens/app-shell.md, decision 7).

@ProviderFor(appRouter)
final appRouterProvider = AppRouterProvider._();

/// The app's router: one branch per destination, each with its own navigator,
/// so every destination keeps its back stack and scroll position
/// (docs/ux/screens/app-shell.md, decision 7).

final class AppRouterProvider
    extends $FunctionalProvider<GoRouter, GoRouter, GoRouter>
    with $Provider<GoRouter> {
  /// The app's router: one branch per destination, each with its own navigator,
  /// so every destination keeps its back stack and scroll position
  /// (docs/ux/screens/app-shell.md, decision 7).
  AppRouterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appRouterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appRouterHash();

  @$internal
  @override
  $ProviderElement<GoRouter> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GoRouter create(Ref ref) {
    return appRouter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GoRouter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GoRouter>(value),
    );
  }
}

String _$appRouterHash() => r'53c36cecd3817b0c0b31efd2069f8fdd1f3b90f6';
