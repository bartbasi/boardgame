import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// copy.md nav.scan. Navigation destination label.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get navScan;

  /// copy.md nav.search. Navigation destination label.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get navSearch;

  /// copy.md nav.collection. Navigation destination label.
  ///
  /// In en, this message translates to:
  /// **'Collection'**
  String get navCollection;

  /// copy.md nav.settings. Navigation destination label.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// copy.md nav.scanLabel. Semantic label of the Scan destination.
  ///
  /// In en, this message translates to:
  /// **'Scan a barcode'**
  String get navScanLabel;

  /// copy.md nav.searchLabel. Semantic label of the Search destination.
  ///
  /// In en, this message translates to:
  /// **'Search by title'**
  String get navSearchLabel;

  /// copy.md nav.collectionLabel. Semantic label of the Collection destination.
  ///
  /// In en, this message translates to:
  /// **'Your collection'**
  String get navCollectionLabel;

  /// copy.md nav.settingsLabel. Semantic label of the Settings destination.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettingsLabel;

  /// copy.md shell.appName. Placeholder until PRD Q1 is answered.
  ///
  /// In en, this message translates to:
  /// **'Board Game Collector'**
  String get shellAppName;

  /// copy.md shell.skipToContent.
  ///
  /// In en, this message translates to:
  /// **'Skip to content'**
  String get shellSkipToContent;

  /// copy.md common.offlineBanner.
  ///
  /// In en, this message translates to:
  /// **'You are offline. Showing saved data.'**
  String get commonOfflineBanner;

  /// copy.md scanner.title.
  ///
  /// In en, this message translates to:
  /// **'Scan a barcode'**
  String get scannerTitle;

  /// copy.md search.title.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchTitle;

  /// copy.md collection.title.
  ///
  /// In en, this message translates to:
  /// **'Collection'**
  String get collectionTitle;

  /// copy.md settings.title.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// copy.md scanner.actionManual. Opens manual barcode entry from Scan.
  ///
  /// In en, this message translates to:
  /// **'Enter barcode'**
  String get scannerActionManual;

  /// copy.md search.actionManual. App bar action on Search that opens manual barcode entry.
  ///
  /// In en, this message translates to:
  /// **'Enter barcode'**
  String get searchActionManual;

  /// copy.md manualEntry.title. App bar title.
  ///
  /// In en, this message translates to:
  /// **'Enter barcode'**
  String get manualEntryTitle;

  /// copy.md manualEntry.fieldLabel. Visible label of the barcode field.
  ///
  /// In en, this message translates to:
  /// **'Barcode number'**
  String get manualEntryFieldLabel;

  /// copy.md manualEntry.helper. Helper text under the field.
  ///
  /// In en, this message translates to:
  /// **'8, 12, or 13 digits, printed under the barcode.'**
  String get manualEntryHelper;

  /// copy.md manualEntry.submit. Primary button.
  ///
  /// In en, this message translates to:
  /// **'Look up'**
  String get manualEntrySubmit;

  /// copy.md manualEntry.errorLength. Shown after submit for a digit count other than 8, 12, or 13 (not 0).
  ///
  /// In en, this message translates to:
  /// **'A barcode has 8, 12, or 13 digits. You entered {count}.'**
  String manualEntryErrorLength(int count);

  /// copy.md manualEntry.errorNonDigit. Fallback when a non-digit reaches validation.
  ///
  /// In en, this message translates to:
  /// **'Use digits only.'**
  String get manualEntryErrorNonDigit;

  /// copy.md manualEntry.errorCheckDigit. Wrong check digit.
  ///
  /// In en, this message translates to:
  /// **'That number does not look right. Check the digits against the box.'**
  String get manualEntryErrorCheckDigit;

  /// copy.md manualEntry.errorEmpty. Submit with an empty field.
  ///
  /// In en, this message translates to:
  /// **'Enter the barcode number.'**
  String get manualEntryErrorEmpty;

  /// copy.md manualEntry.errorAnnouncement. Announced to screen readers when an error appears.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String manualEntryErrorAnnouncement(String message);

  /// copy.md manualEntry.searchInstead. Text button that opens Search.
  ///
  /// In en, this message translates to:
  /// **'Search by title instead'**
  String get manualEntrySearchInstead;

  /// copy.md manualEntry.scanInstead. Text button that returns to the scanner.
  ///
  /// In en, this message translates to:
  /// **'Scan instead'**
  String get manualEntryScanInstead;

  /// copy.md manualEntry.digitCounter. Counter under the field.
  ///
  /// In en, this message translates to:
  /// **'{count} of 13 digits'**
  String manualEntryDigitCounter(int count);

  /// copy.md itemEdit.clearField. Label of a clear button inside a text field; also used by the barcode field until copy.md has its own key (T-031 open question).
  ///
  /// In en, this message translates to:
  /// **'Clear {field}'**
  String itemEditClearField(String field);

  /// copy.md lookup.title. App bar title of the lookup result screen.
  ///
  /// In en, this message translates to:
  /// **'Barcode {code}'**
  String lookupTitle(String code);

  /// Skeleton only (T-012), not in copy.md. Removed when the destination screen is built.
  ///
  /// In en, this message translates to:
  /// **'This screen is not built yet.'**
  String get devPlaceholderBody;

  /// Skeleton only (T-012), not in copy.md. Rows of the placeholder Collection list. Removed by T-039.
  ///
  /// In en, this message translates to:
  /// **'Placeholder item {number}'**
  String devPlaceholderItem(int number);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
