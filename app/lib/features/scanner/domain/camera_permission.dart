import 'package:board_game_collector/core/domain/result.dart';

/// The camera permission as the scanner needs to know it (T-030,
/// scanner.md section 4).
enum CameraPermission {
  /// The app may use the camera.
  granted,

  /// Not granted, and the app may still ask: never asked yet, or (Android)
  /// denied without "don't ask again".
  denied,

  /// Not granted, and asking again shows no prompt: iOS after the first
  /// denial, Android after "don't ask again". Only system settings can
  /// change it.
  permanentlyDenied,

  /// iOS parental or device policy blocks the camera. Neither the user's
  /// answer nor the app's settings page can change it.
  restricted,
}

/// Reads and requests the camera permission. Implemented in the data
/// layer; no exception crosses it.
abstract interface class CameraPermissionRepository {
  /// The current permission, without showing a prompt.
  Future<Result<CameraPermission>> status();

  /// Whether a [CameraPermission.denied] status comes from an earlier
  /// denial rather than from never asking (T-030 review R1-M1), so the
  /// scanner does not prompt again at the next launch.
  ///
  /// Android: true once the user denied the prompt (the platform then asks
  /// apps to show a rationale). iOS: always false, because iOS reports any
  /// earlier answer as [CameraPermission.permanentlyDenied] already.
  Future<Result<bool>> wasDeniedBefore();

  /// Shows the system prompt when the platform still allows it, and returns
  /// the permission after the user answered.
  Future<Result<CameraPermission>> request();

  /// Opens the app's page in the system settings. Ok(false) when the
  /// platform could not open it.
  Future<Result<bool>> openSettings();
}
