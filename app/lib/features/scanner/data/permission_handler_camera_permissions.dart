import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/domain/result.dart';
import '../domain/camera_permission.dart';

part 'permission_handler_camera_permissions.g.dart';

/// [CameraPermissionRepository] on top of the permission_handler plugin
/// (MIT; T-030).
///
/// Every plugin error (for example a missing plugin on an unsupported
/// platform) becomes [UnexpectedFailure], which the scanner shows as
/// "camera not available". The error is logged by type only.
class PermissionHandlerCameraPermissions implements CameraPermissionRepository {
  const PermissionHandlerCameraPermissions({this.log});

  /// Receives one line per plugin error; null in release builds.
  final void Function(String message)? log;

  @override
  Future<Result<CameraPermission>> status() =>
      _guard('status', () async => mapStatus(await Permission.camera.status));

  @override
  Future<Result<CameraPermission>> request() => _guard(
    'request',
    () async => mapStatus(await Permission.camera.request()),
  );

  @override
  Future<Result<bool>> openSettings() =>
      _guard('openSettings', openAppSettings);

  Future<Result<T>> _guard<T>(String action, Future<T> Function() call) async {
    try {
      return Ok(await call());
    } on Object catch (error) {
      log?.call('Camera permission $action failed: ${error.runtimeType}');
      return const Err(UnexpectedFailure());
    }
  }

  /// Maps the plugin's status to the scanner's.
  ///
  /// `limited` and `provisional` do not apply to the camera; they count as
  /// granted, because the platform did allow access.
  @visibleForTesting
  static CameraPermission mapStatus(PermissionStatus status) =>
      switch (status) {
        PermissionStatus.granted ||
        PermissionStatus.limited ||
        PermissionStatus.provisional => CameraPermission.granted,
        PermissionStatus.denied => CameraPermission.denied,
        PermissionStatus.permanentlyDenied =>
          CameraPermission.permanentlyDenied,
        PermissionStatus.restricted => CameraPermission.restricted,
      };
}

/// The camera permission repository. Tests override it with a fake.
@Riverpod(keepAlive: true)
CameraPermissionRepository cameraPermissionRepository(Ref ref) =>
    PermissionHandlerCameraPermissions(log: kDebugMode ? debugPrint : null);
