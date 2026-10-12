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
  String get devPlaceholderBody => 'This screen is not built yet.';

  @override
  String devPlaceholderItem(int number) {
    return 'Placeholder item $number';
  }
}
