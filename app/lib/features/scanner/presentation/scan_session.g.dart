// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scan_session.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether the camera permission prompt was already shown by the scanner
/// in this app run (T-030 AC1, scanner.md section 1: the prompt appears
/// only when the scanner is first opened).
///
/// After that, "denied" shows the Denied panel and its "Allow camera"
/// button asks again. Across app runs the platform tells an earlier denial
/// apart (`CameraPermissionRepository.wasDeniedBefore`; review R1-M1), so a
/// user who denied once is not prompted again at the next launch.

@ProviderFor(CameraPromptShown)
final cameraPromptShownProvider = CameraPromptShownProvider._();

/// Whether the camera permission prompt was already shown by the scanner
/// in this app run (T-030 AC1, scanner.md section 1: the prompt appears
/// only when the scanner is first opened).
///
/// After that, "denied" shows the Denied panel and its "Allow camera"
/// button asks again. Across app runs the platform tells an earlier denial
/// apart (`CameraPermissionRepository.wasDeniedBefore`; review R1-M1), so a
/// user who denied once is not prompted again at the next launch.
final class CameraPromptShownProvider
    extends $NotifierProvider<CameraPromptShown, bool> {
  /// Whether the camera permission prompt was already shown by the scanner
  /// in this app run (T-030 AC1, scanner.md section 1: the prompt appears
  /// only when the scanner is first opened).
  ///
  /// After that, "denied" shows the Denied panel and its "Allow camera"
  /// button asks again. Across app runs the platform tells an earlier denial
  /// apart (`CameraPermissionRepository.wasDeniedBefore`; review R1-M1), so a
  /// user who denied once is not prompted again at the next launch.
  CameraPromptShownProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cameraPromptShownProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cameraPromptShownHash();

  @$internal
  @override
  CameraPromptShown create() => CameraPromptShown();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$cameraPromptShownHash() => r'f6b86d4d928337f48378838362a5904770aaaa45';

/// Whether the camera permission prompt was already shown by the scanner
/// in this app run (T-030 AC1, scanner.md section 1: the prompt appears
/// only when the scanner is first opened).
///
/// After that, "denied" shows the Denied panel and its "Allow camera"
/// button asks again. Across app runs the platform tells an earlier denial
/// apart (`CameraPermissionRepository.wasDeniedBefore`; review R1-M1), so a
/// user who denied once is not prompted again at the next launch.

abstract class _$CameraPromptShown extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
