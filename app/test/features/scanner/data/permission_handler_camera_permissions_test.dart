// T-030: the camera permission repository on top of permission_handler.
// The plugin's method channel is replaced, so these tests check the real
// plugin calls and the mapping, without a device.
import 'package:board_game_collector/core/domain/result.dart';
import 'package:board_game_collector/features/scanner/data/permission_handler_camera_permissions.dart';
import 'package:board_game_collector/features/scanner/domain/camera_permission.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

const _channel = MethodChannel('flutter.baseflow.com/permissions/methods');

/// permission_handler's wire values (PermissionStatusValue).
const _wire = <PermissionStatus, int>{
  PermissionStatus.denied: 0,
  PermissionStatus.granted: 1,
  PermissionStatus.restricted: 2,
  PermissionStatus.limited: 3,
  PermissionStatus.permanentlyDenied: 4,
  PermissionStatus.provisional: 5,
};

/// Camera's permission value in permission_handler.
const _camera = 1;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<MethodCall> calls;
  void answer(Object? Function(MethodCall call) handler) {
    calls = [];
    messenger.setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      return handler(call);
    });
  }

  tearDown(() => messenger.setMockMethodCallHandler(_channel, null));

  group('mapStatus', () {
    final expected = <PermissionStatus, CameraPermission>{
      PermissionStatus.granted: CameraPermission.granted,
      PermissionStatus.limited: CameraPermission.granted,
      PermissionStatus.provisional: CameraPermission.granted,
      PermissionStatus.denied: CameraPermission.denied,
      PermissionStatus.permanentlyDenied: CameraPermission.permanentlyDenied,
      PermissionStatus.restricted: CameraPermission.restricted,
    };
    for (final status in PermissionStatus.values) {
      test(status.name, () {
        expect(
          PermissionHandlerCameraPermissions.mapStatus(status),
          expected[status],
        );
      });
    }
  });

  group('status', () {
    for (final MapEntry(key: status, value: wire) in _wire.entries) {
      test(
        'reads the camera status without a prompt (${status.name})',
        () async {
          answer((_) => wire);
          final result = await const PermissionHandlerCameraPermissions()
              .status();
          expect(
            result,
            Ok(PermissionHandlerCameraPermissions.mapStatus(status)),
          );
          expect(calls.single.method, 'checkPermissionStatus');
          expect(calls.single.arguments, _camera);
        },
      );
    }
  });

  group('request', () {
    test('asks for the camera only and maps the answer', () async {
      answer((_) => {_camera: _wire[PermissionStatus.permanentlyDenied]});
      final result = await const PermissionHandlerCameraPermissions().request();
      expect(result, const Ok(CameraPermission.permanentlyDenied));
      expect(calls.single.method, 'requestPermissions');
      expect(calls.single.arguments, [_camera]);
    });

    test('granted', () async {
      answer((_) => {_camera: _wire[PermissionStatus.granted]});
      expect(
        await const PermissionHandlerCameraPermissions().request(),
        const Ok(CameraPermission.granted),
      );
    });
  });

  group('openSettings', () {
    test('opens the app settings page', () async {
      answer((_) => true);
      expect(
        await const PermissionHandlerCameraPermissions().openSettings(),
        const Ok(true),
      );
      expect(calls.single.method, 'openAppSettings');
    });

    test('reports when the page could not open', () async {
      answer((_) => false);
      expect(
        await const PermissionHandlerCameraPermissions().openSettings(),
        const Ok(false),
      );
    });
  });

  group('plugin errors never cross the data layer', () {
    test(
      'a PlatformException becomes UnexpectedFailure, logged by type',
      () async {
        answer((_) => throw PlatformException(code: 'boom', message: 'secret'));
        final log = <String>[];
        final repo = PermissionHandlerCameraPermissions(log: log.add);
        expect(
          await repo.status(),
          const Err<CameraPermission>(UnexpectedFailure()),
        );
        expect(
          await repo.request(),
          const Err<CameraPermission>(UnexpectedFailure()),
        );
        expect(await repo.openSettings(), const Err<bool>(UnexpectedFailure()));
        expect(log, [
          'Camera permission status failed: PlatformException',
          'Camera permission request failed: PlatformException',
          'Camera permission openSettings failed: PlatformException',
        ]);
        expect(log.join(), isNot(contains('secret')));
      },
    );

    test(
      'a missing plugin becomes UnexpectedFailure without a logger',
      () async {
        // No handler answers null, which the plugin turns into an error.
        answer((_) => null);
        expect(
          await const PermissionHandlerCameraPermissions().status(),
          const Err<CameraPermission>(UnexpectedFailure()),
        );
      },
    );
  });

  test('the provider gives the permission_handler repository', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      container.read(cameraPermissionRepositoryProvider),
      isA<PermissionHandlerCameraPermissions>(),
    );
  });
}
