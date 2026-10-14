// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'permission_handler_camera_permissions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The camera permission repository. Tests override it with a fake.

@ProviderFor(cameraPermissionRepository)
final cameraPermissionRepositoryProvider =
    CameraPermissionRepositoryProvider._();

/// The camera permission repository. Tests override it with a fake.

final class CameraPermissionRepositoryProvider
    extends
        $FunctionalProvider<
          CameraPermissionRepository,
          CameraPermissionRepository,
          CameraPermissionRepository
        >
    with $Provider<CameraPermissionRepository> {
  /// The camera permission repository. Tests override it with a fake.
  CameraPermissionRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cameraPermissionRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cameraPermissionRepositoryHash();

  @$internal
  @override
  $ProviderElement<CameraPermissionRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CameraPermissionRepository create(Ref ref) {
    return cameraPermissionRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CameraPermissionRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CameraPermissionRepository>(value),
    );
  }
}

String _$cameraPermissionRepositoryHash() =>
    r'bdd11bfb9b684540fc99193820f6d4cb45ef3ed3';
