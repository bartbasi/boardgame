// T-031: manual barcode entry (docs/ux/screens/manual-entry.md).
import 'package:board_game_collector/app/app.dart';
import 'package:board_game_collector/app/navigation/app_router.dart';
import 'package:board_game_collector/core/data/network/api_client_provider.dart';
import 'package:board_game_collector/core/domain/failure.dart';
import 'package:board_game_collector/features/scanner/presentation/barcode_field.dart';
import 'package:board_game_collector/features/scanner/presentation/lookup_result_screen.dart';
import 'package:board_game_collector/features/scanner/presentation/manual_entry_screen.dart';
import 'package:board_game_collector/features/scanner/presentation/scan_screen.dart';
import 'package:board_game_collector/features/scanner/presentation/search_screen.dart';
import 'package:board_game_collector/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

const _helper = '8, 12, or 13 digits, printed under the barcode.';
const _errorEmpty = 'Enter the barcode number.';
const _errorCheckDigit =
    'That number does not look right. Check the digits against the box.';
String _errorLength(int count) =>
    'A barcode has 8, 12, or 13 digits. You entered $count.';

Finder get _field => find.byType(TextField);
Finder get _submit => find.widgetWithText(FilledButton, 'Look up');

String _fieldText(WidgetTester tester) =>
    tester.widget<TextField>(_field).controller!.text;

bool _fieldHasFocus(WidgetTester tester) =>
    tester.widget<TextField>(_field).focusNode!.hasPrimaryFocus;

/// Opens manual entry from the Scan placeholder's `scanner.actionManual`.
Future<void> _openFromScan(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(OutlinedButton, 'Enter barcode'));
  await tester.pumpAndSettle();
}

/// Types [text] one character at a time, as a keyboard would.
Future<void> _typeEach(WidgetTester tester, String text) async {
  for (var i = 1; i <= text.length; i++) {
    await tester.enterText(_field, text.substring(0, i));
    await tester.pump();
  }
}

Future<void> _submitWith(WidgetTester tester, String text) async {
  await tester.enterText(_field, text);
  await tester.pump();
  await tester.tap(_submit);
  await tester.pumpAndSettle();
}

void main() {
  group('AC1 entry points', () {
    testWidgets('Scan: "Enter barcode" opens manual entry', (tester) async {
      await pumpApp(tester);
      await _openFromScan(tester);

      expect(find.byType(ManualEntryScreen), findsOne);
      expect(find.widgetWithText(AppBar, 'Enter barcode'), findsOne);
      expect(find.byType(ScanScreen), findsNothing);
    });

    testWidgets('Search: the app bar action opens manual entry', (
      tester,
    ) async {
      await pumpApp(tester, size: WindowSizes.expanded);
      await tester.pumpAndSettle();
      await tapDestination(tester, 'Search');

      final action = find.ancestor(
        of: find.byTooltip('Enter barcode'),
        matching: find.byType(IconButton),
      );
      expect(action, findsOne);
      expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
      await tester.tap(action);
      await tester.pumpAndSettle();

      expect(find.byType(ManualEntryScreen), findsOne);
      expect(find.byType(SearchScreen), findsNothing);
      // Pushed inside Search: the rail still has Search selected.
      expect(
        tester
            .widget<NavigationRail>(find.byType(NavigationRail))
            .selectedIndex,
        1,
      );
    });

    testWidgets('Back returns to the previous screen and drops the text', (
      tester,
    ) async {
      await pumpApp(tester);
      await _openFromScan(tester);
      await tester.enterText(_field, '12345');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(ScanScreen), findsOne);

      await _openFromScan(tester);
      expect(_fieldText(tester), isEmpty);
    });
  });

  group('AC2 digits only, max 13, numeric keyboard', () {
    testWidgets('the field asks for the numeric keyboard', (tester) async {
      await pumpApp(tester);
      await _openFromScan(tester);

      final field = tester.widget<TextField>(_field);
      expect(field.keyboardType, TextInputType.number);
      expect(field.autofocus, isTrue);
      expect(_fieldHasFocus(tester), isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
    });

    testWidgets('letters, spaces, and dashes are dropped as they are typed', (
      tester,
    ) async {
      await pumpApp(tester);
      await _openFromScan(tester);

      await _typeEach(tester, '0a3 6-0x0');
      expect(_fieldText(tester), '03600');
      expect(find.text('5 of 13 digits'), findsOne);
    });

    testWidgets('pasted text keeps only its digits', (tester) async {
      await pumpApp(tester);
      await _openFromScan(tester);

      await tester.enterText(_field, ' 0 36000-29145 2 (UPC)\n');
      await tester.pump();
      expect(_fieldText(tester), '036000291452');
      expect(find.text('12 of 13 digits'), findsOne);
    });

    testWidgets('only ASCII 0 to 9 are kept (T-026 carry-over)', (
      tester,
    ) async {
      await pumpApp(tester);
      await _openFromScan(tester);

      // Arabic-Indic one, fullwidth two, Devanagari three, superscript one.
      final otherDigits = String.fromCharCodes([0x0661, 0xFF12, 0x0969, 0xB9]);
      await tester.enterText(_field, '4${otherDigits}0');
      await tester.pump();
      expect(_fieldText(tester), '40');
    });

    testWidgets('input stops at 13 digits, typed or pasted', (tester) async {
      await pumpApp(tester);
      await _openFromScan(tester);

      await _typeEach(tester, '40063813339317');
      expect(_fieldText(tester), '4006381333931');
      expect(find.text('13 of 13 digits'), findsOne);

      await tester.enterText(_field, '');
      await tester.enterText(_field, '12345678901234567890');
      await tester.pump();
      expect(_fieldText(tester), '1234567890123');
    });

    test('the formatters are the documented ones', () {
      TextEditingValue apply(String text) {
        var value = TextEditingValue(text: text);
        for (final formatter in BarcodeField.inputFormatters) {
          value = formatter.formatEditUpdate(TextEditingValue.empty, value);
        }
        return value;
      }

      expect(apply('12-34 ab56').text, '123456');
      expect(apply('9' * 20).text, '9' * 13);
      expect(BarcodeField.maxDigits, 13);
    });
  });

  group('AC3 valid codes open the lookup result', () {
    for (final code in ['036000291452', '4006381333931', '96385074']) {
      testWidgets('$code with the Look up button', (tester) async {
        await pumpApp(tester);
        await _openFromScan(tester);
        await _submitWith(tester, code);

        final screen = tester.widget<LookupResultScreen>(
          find.byType(LookupResultScreen),
        );
        expect(screen.barcode.digits, code);
        expect(find.widgetWithText(AppBar, 'Barcode $code'), findsOne);
        expect(find.byType(ManualEntryScreen), findsNothing);
      });
    }

    testWidgets('the keyboard action submits too', (tester) async {
      await pumpApp(tester);
      await _openFromScan(tester);
      await tester.enterText(_field, '4006381333931');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<LookupResultScreen>(find.byType(LookupResultScreen))
            .barcode
            .gtin13,
        '4006381333931',
      );
    });

    testWidgets('from Search, the lookup result opens inside Search', (
      tester,
    ) async {
      await pumpApp(tester, size: WindowSizes.expanded);
      await tester.pumpAndSettle();
      await tapDestination(tester, 'Search');
      await tester.tap(find.byTooltip('Enter barcode'));
      await tester.pumpAndSettle();
      await _submitWith(tester, '96385074');

      expect(find.byType(LookupResultScreen), findsOne);
      expect(
        tester
            .widget<NavigationRail>(find.byType(NavigationRail))
            .selectedIndex,
        1,
      );

      // Back from the result returns to manual entry with the code kept.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(_fieldText(tester), '96385074');
    });

    testWidgets('a lookup path with an invalid code goes to the root', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(BoardGameCollectorApp)),
      );
      container.read(appRouterProvider).go('/scan/lookup/036000291453');
      await tester.pumpAndSettle();

      expect(find.byType(LookupResultScreen), findsNothing);
      expect(find.byType(ScanScreen), findsOne);
    });
  });

  group('AC4 invalid codes', () {
    final cases = {
      '036000291453': _errorCheckDigit,
      '12345': _errorLength(5),
      '': _errorEmpty,
    };
    for (final MapEntry(key: input, value: message) in cases.entries) {
      testWidgets('"$input" shows "$message", keeps focus, announces it', (
        tester,
      ) async {
        await pumpApp(tester);
        await _openFromScan(tester);
        tester.takeAnnouncements();

        await _submitWith(tester, input);

        expect(find.text(message), findsOne);
        expect(find.text(_helper), findsNothing);
        expect(find.byIcon(Icons.error), findsOne);
        expect(_fieldHasFocus(tester), isTrue);
        expect(find.byType(LookupResultScreen), findsNothing);
        expect(find.byType(ManualEntryScreen), findsOne);
        expect(tester.takeAnnouncements(), [
          isAccessibilityAnnouncement(
            'Error: $message',
            assertiveness: Assertiveness.assertive,
            textDirection: TextDirection.ltr,
          ),
        ]);
      });
    }

    testWidgets('screen readers read the error as part of the field', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await pumpApp(tester);
        await _openFromScan(tester);
        await _submitWith(tester, '12345');

        final fieldNode = find.semantics
            .byLabel('Barcode number')
            .evaluate()
            .single;
        expect(fieldNode.flagsCollection.isTextField, isTrue);
        final childLabels = <String>[];
        fieldNode.visitChildren((child) {
          childLabels.add(child.label);
          return true;
        });
        expect(childLabels, contains(_errorLength(5)));
        expect(childLabels, contains('5 of 13 digits'));
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('the field outline uses the error role', (tester) async {
      await pumpApp(tester);
      await _openFromScan(tester);
      await _submitWith(tester, '036000291453');

      final decorator = tester.widget<InputDecorator>(
        find.byType(InputDecorator),
      );
      expect(decorator.decoration.error, isNotNull);
      final scheme = Theme.of(tester.element(_field)).colorScheme;
      final icon = tester.widget<Icon>(find.byIcon(Icons.error));
      expect(icon.color, scheme.error);
    });

    testWidgets('no error while typing, only after submit', (tester) async {
      await pumpApp(tester);
      await _openFromScan(tester);
      await _typeEach(tester, '12345');

      expect(find.text(_errorLength(5)), findsNothing);
      expect(find.text(_helper), findsOne);
    });

    testWidgets('the error clears when the user edits the field', (
      tester,
    ) async {
      await pumpApp(tester);
      await _openFromScan(tester);
      await _submitWith(tester, '12345');
      expect(find.text(_errorLength(5)), findsOne);

      await tester.enterText(_field, '123456');
      await tester.pumpAndSettle();
      expect(find.text(_errorLength(5)), findsNothing);
      expect(find.text(_helper), findsOne);
    });

    testWidgets('the clear button empties the field, clears the error, and '
        'keeps focus', (tester) async {
      await pumpApp(tester);
      await _openFromScan(tester);
      expect(find.byTooltip('Clear Barcode number'), findsNothing);

      await _submitWith(tester, '12345');
      final clear = find.byTooltip('Clear Barcode number');
      expect(clear, findsOne);
      await tester.tap(clear);
      await tester.pumpAndSettle();

      expect(_fieldText(tester), isEmpty);
      expect(find.text(_errorLength(5)), findsNothing);
      expect(find.text('0 of 13 digits'), findsOne);
      expect(_fieldHasFocus(tester), isTrue);
      expect(find.byTooltip('Clear Barcode number'), findsNothing);
    });

    testWidgets('a fixed code then opens the lookup result', (tester) async {
      await pumpApp(tester);
      await _openFromScan(tester);
      await _submitWith(tester, '036000291453');
      await _submitWith(tester, '036000291452');

      expect(find.byType(LookupResultScreen), findsOne);
    });
  });

  group('error messages (manual-entry.md section 4, T-026 carry-over)', () {
    final l10n = AppLocalizationsEn();

    test('empty input (length 0) gets manualEntry.errorEmpty', () {
      expect(
        manualEntryErrorMessage(
          l10n,
          const InvalidBarcodeFailure(
            InvalidBarcodeReason.wrongLength,
            length: 0,
          ),
        ),
        _errorEmpty,
      );
    });

    test('other wrong lengths show the count', () {
      for (final length in [1, 5, 7, 9, 11]) {
        expect(
          manualEntryErrorMessage(
            l10n,
            InvalidBarcodeFailure(
              InvalidBarcodeReason.wrongLength,
              length: length,
            ),
          ),
          _errorLength(length),
        );
      }
    });

    test('non-digit is the fallback message and shows no length', () {
      expect(
        manualEntryErrorMessage(
          l10n,
          const InvalidBarcodeFailure(InvalidBarcodeReason.nonDigit, length: 4),
        ),
        'Use digits only.',
      );
    });

    test('bad check digit', () {
      expect(
        manualEntryErrorMessage(
          l10n,
          const InvalidBarcodeFailure(
            InvalidBarcodeReason.badCheckDigit,
            length: 12,
          ),
        ),
        _errorCheckDigit,
      );
    });
  });

  group('AC5 initial state, no network', () {
    testWidgets('helper text and counter show on arrival', (tester) async {
      await pumpApp(tester);
      await _openFromScan(tester);

      expect(find.text(_helper), findsOne);
      expect(find.text('0 of 13 digits'), findsOne);
      expect(find.text('Barcode number'), findsOne);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      // Submit is enabled, so an empty submit gives a clear error.
      expect(tester.widget<FilledButton>(_submit).onPressed, isNotNull);
    });

    testWidgets('offline: no network is used and a valid code still opens '
        'the lookup result', (tester) async {
      var networkReads = 0;
      setTestWindow(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // The device is offline: any use of the network fails loudly.
            apiClientProvider.overrideWith((ref) {
              networkReads++;
              throw StateError('offline');
            }),
          ],
          child: const BoardGameCollectorApp(),
        ),
      );
      await _openFromScan(tester);
      await _submitWith(tester, '036000291452');

      expect(find.byType(LookupResultScreen), findsOne);
      expect(networkReads, 0);
      expect(tester.takeException(), isNull);
    });
  });

  group('AC6 large text, themes, sizes', () {
    for (final brightness in Brightness.values) {
      for (final entry in {
        'compact': WindowSizes.compact,
        'expanded': WindowSizes.expanded,
      }.entries) {
        testWidgets('no overflow and guidelines pass at 2.0 '
            '(${brightness.name}, ${entry.key})', (tester) async {
          final semantics = tester.ensureSemantics();
          try {
            await pumpApp(
              tester,
              size: entry.value,
              textScale: largeTextScale,
              brightness: brightness,
            );
            await _openFromScan(tester);
            expect(tester.takeException(), isNull);
            await _expectGuidelines(tester);

            await _submitWith(tester, '036000291453');
            expect(tester.takeException(), isNull);
            expect(find.text(_errorCheckDigit), findsOne);
            await _expectGuidelines(tester);

            // Field, clear button, submit, and both text actions.
            await tester.enterText(_field, '12345');
            await tester.pump();
            for (final target in [
              _field,
              find.ancestor(
                of: find.byTooltip('Clear Barcode number'),
                matching: find.byType(IconButton),
              ),
              _submit,
              find.widgetWithText(TextButton, 'Scan instead'),
              find.widgetWithText(TextButton, 'Search by title instead'),
            ]) {
              expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
            }
          } finally {
            semantics.dispose();
          }
        });
      }
    }

    for (final entry in WindowSizes.all.entries) {
      testWidgets('no overflow at 2.0 in ${entry.key}', (tester) async {
        await pumpApp(tester, size: entry.value, textScale: largeTextScale);
        await _openFromScan(tester);
        await _submitWith(tester, '12345');
        expect(tester.takeException(), isNull);
        expect(find.text(_errorLength(5)), findsOne);
      });
    }

    testWidgets('medium and expanded center a column of at most 600 dp', (
      tester,
    ) async {
      await pumpApp(tester, size: WindowSizes.expanded);
      await _openFromScan(tester);
      final rect = tester.getRect(_submit);
      expect(rect.width, lessThanOrEqualTo(600));
      final content = tester.getRect(find.byType(SingleChildScrollView).last);
      expect(rect.center.dx, closeTo(content.center.dx, 1));
    });

    testWidgets('phone landscape keeps the column on the leading 55%', (
      tester,
    ) async {
      await pumpApp(tester, size: WindowSizes.landscape);
      await _openFromScan(tester);
      final content = tester.getRect(find.byType(SingleChildScrollView).last);
      final rect = tester.getRect(_submit);
      expect(rect.right, lessThanOrEqualTo(content.left + content.width * 0.6));
    });
  });

  group('alternatives', () {
    testWidgets('Scan instead, from Scan, returns to the scanner', (
      tester,
    ) async {
      await pumpApp(tester);
      await _openFromScan(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Scan instead'));
      await tester.pumpAndSettle();

      expect(find.byType(ScanScreen), findsOne);
      expect(find.byType(ManualEntryScreen), findsNothing);
      expect(find.byType(NavigationBar), findsOne);
    });

    testWidgets('Search by title instead, from Scan, switches to Search and '
        'leaves Scan at its root', (tester) async {
      await pumpApp(tester);
      await _openFromScan(tester);
      await tester.tap(
        find.widgetWithText(TextButton, 'Search by title instead'),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SearchScreen), findsOne);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );

      await tapDestination(tester, 'Scan');
      expect(find.byType(ScanScreen), findsOne);
      expect(find.byType(ManualEntryScreen), findsNothing);
    });

    testWidgets('Scan instead, from Search, switches to Scan', (tester) async {
      await pumpApp(tester);
      await tester.pumpAndSettle();
      await tapDestination(tester, 'Search');
      await tester.tap(find.byTooltip('Enter barcode'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Scan instead'));
      await tester.pumpAndSettle();

      expect(find.byType(ScanScreen), findsOne);
      expect(find.byType(NavigationBar), findsOne);
      await tapDestination(tester, 'Search');
      expect(find.byType(SearchScreen), findsOne);
    });
  });
}

Future<void> _expectGuidelines(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
}
