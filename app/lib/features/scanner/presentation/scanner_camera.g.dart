// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scanner_camera.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Creates the scanner screen's camera. Tests override it with a fake.

@ProviderFor(scannerCameraFactory)
final scannerCameraFactoryProvider = ScannerCameraFactoryProvider._();

/// Creates the scanner screen's camera. Tests override it with a fake.

final class ScannerCameraFactoryProvider
    extends
        $FunctionalProvider<
          ScannerCamera Function(),
          ScannerCamera Function(),
          ScannerCamera Function()
        >
    with $Provider<ScannerCamera Function()> {
  /// Creates the scanner screen's camera. Tests override it with a fake.
  ScannerCameraFactoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'scannerCameraFactoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$scannerCameraFactoryHash();

  @$internal
  @override
  $ProviderElement<ScannerCamera Function()> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ScannerCamera Function() create(Ref ref) {
    return scannerCameraFactory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ScannerCamera Function() value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ScannerCamera Function()>(value),
    );
  }
}

String _$scannerCameraFactoryHash() =>
    r'6e27ea559d5856c03f407d1ce4352ac6a69ab2c5';

/// Creates the stopwatch that measures the scanner's debounce window.
/// Tests override it with `clock.stopwatch`, so fake time applies.

@ProviderFor(scanStopwatchFactory)
final scanStopwatchFactoryProvider = ScanStopwatchFactoryProvider._();

/// Creates the stopwatch that measures the scanner's debounce window.
/// Tests override it with `clock.stopwatch`, so fake time applies.

final class ScanStopwatchFactoryProvider
    extends
        $FunctionalProvider<
          Stopwatch Function(),
          Stopwatch Function(),
          Stopwatch Function()
        >
    with $Provider<Stopwatch Function()> {
  /// Creates the stopwatch that measures the scanner's debounce window.
  /// Tests override it with `clock.stopwatch`, so fake time applies.
  ScanStopwatchFactoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'scanStopwatchFactoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$scanStopwatchFactoryHash();

  @$internal
  @override
  $ProviderElement<Stopwatch Function()> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  Stopwatch Function() create(Ref ref) {
    return scanStopwatchFactory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Stopwatch Function() value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Stopwatch Function()>(value),
    );
  }
}

String _$scanStopwatchFactoryHash() =>
    r'83f2a60fdfd2f130f1a12ca5b9ae99140b67e141';
