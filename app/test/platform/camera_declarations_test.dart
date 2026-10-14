// T-030 AC12 and AC15 back-up checks of the platform files (the criteria
// themselves are proved manually on the built apps). Runs from app/.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../l10n/strings_test.dart' show readCopyTable;

void main() {
  test('AC12 iOS: NSCameraUsageDescription has the copy.md text', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final copy = readCopyTable(File('../docs/ux/copy.md').readAsStringSync());
    final expected = copy['scannerIosUsageDescription']!;
    final match = RegExp(
      r'<key>NSCameraUsageDescription</key>\s*<string>([^<]*)</string>',
    ).firstMatch(plist);
    expect(match, isNotNull);
    expect(match!.group(1), expected);
  });

  group('Android manifest', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();

    test('AC12 declares the CAMERA permission', () {
      expect(
        manifest,
        contains('<uses-permission android:name="android.permission.CAMERA"/>'),
      );
    });

    test('AC15 the camera feature is not required', () {
      expect(
        manifest,
        contains(
          '<uses-feature android:name="android.hardware.camera" '
          'android:required="false"/>',
        ),
      );
    });
  });

  test('AC16 the bundled ML Kit model is not switched off', () {
    final properties = File('android/gradle.properties').readAsStringSync();
    expect(properties, isNot(contains('useUnbundled=true')));
  });
}
