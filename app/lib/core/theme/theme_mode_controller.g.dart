// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_mode_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The theme the user picked. Follows the system by default
/// (docs/ux/screens/app-shell.md, decision 4).
///
/// Settings (a later ticket) lets the user force light or dark and persists
/// the choice; until then the value lives only in memory.

@ProviderFor(ThemeModeController)
final themeModeControllerProvider = ThemeModeControllerProvider._();

/// The theme the user picked. Follows the system by default
/// (docs/ux/screens/app-shell.md, decision 4).
///
/// Settings (a later ticket) lets the user force light or dark and persists
/// the choice; until then the value lives only in memory.
final class ThemeModeControllerProvider
    extends $NotifierProvider<ThemeModeController, ThemeMode> {
  /// The theme the user picked. Follows the system by default
  /// (docs/ux/screens/app-shell.md, decision 4).
  ///
  /// Settings (a later ticket) lets the user force light or dark and persists
  /// the choice; until then the value lives only in memory.
  ThemeModeControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'themeModeControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$themeModeControllerHash();

  @$internal
  @override
  ThemeModeController create() => ThemeModeController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ThemeMode value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ThemeMode>(value),
    );
  }
}

String _$themeModeControllerHash() =>
    r'7e0e09b523f30fd0cfbfb944eb145a98f6f32687';

/// The theme the user picked. Follows the system by default
/// (docs/ux/screens/app-shell.md, decision 4).
///
/// Settings (a later ticket) lets the user force light or dark and persists
/// the choice; until then the value lives only in memory.

abstract class _$ThemeModeController extends $Notifier<ThemeMode> {
  ThemeMode build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ThemeMode, ThemeMode>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ThemeMode, ThemeMode>,
              ThemeMode,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
