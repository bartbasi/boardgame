// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get navScan => 'Scan';

  @override
  String get navSearch => 'Search';

  @override
  String get navCollection => 'Collection';

  @override
  String get navSettings => 'Settings';

  @override
  String get navScanLabel => 'Scan a barcode';

  @override
  String get navSearchLabel => 'Search by title';

  @override
  String get navCollectionLabel => 'Your collection';

  @override
  String get navSettingsLabel => 'Settings';

  @override
  String get shellAppName => 'Board Game Collector';

  @override
  String get shellSkipToContent => 'Skip to content';

  @override
  String get commonOfflineBanner => 'You are offline. Showing saved data.';

  @override
  String get scannerTitle => 'Scan a barcode';

  @override
  String get searchTitle => 'Search';

  @override
  String get collectionTitle => 'Collection';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get scannerActionManual => 'Enter barcode';

  @override
  String get searchActionManual => 'Enter barcode';

  @override
  String get manualEntryTitle => 'Enter barcode';

  @override
  String get manualEntryFieldLabel => 'Barcode number';

  @override
  String get manualEntryHelper =>
      '8, 12, or 13 digits, printed under the barcode.';

  @override
  String get manualEntrySubmit => 'Look up';

  @override
  String manualEntryErrorLength(int count) {
    return 'A barcode has 8, 12, or 13 digits. You entered $count.';
  }

  @override
  String get manualEntryErrorNonDigit => 'Use digits only.';

  @override
  String get manualEntryErrorCheckDigit =>
      'That number does not look right. Check the digits against the box.';

  @override
  String get manualEntryErrorEmpty => 'Enter the barcode number.';

  @override
  String manualEntryErrorAnnouncement(String message) {
    return 'Error: $message';
  }

  @override
  String get manualEntrySearchInstead => 'Search by title instead';

  @override
  String get manualEntryScanInstead => 'Scan instead';

  @override
  String manualEntryDigitCounter(int count) {
    return '$count of 13 digits';
  }

  @override
  String itemEditClearField(String field) {
    return 'Clear $field';
  }

  @override
  String lookupTitle(String code) {
    return 'Barcode $code';
  }

  @override
  String get devPlaceholderBody => 'This screen is not built yet.';

  @override
  String devPlaceholderItem(int number) {
    return 'Placeholder item $number';
  }
}
