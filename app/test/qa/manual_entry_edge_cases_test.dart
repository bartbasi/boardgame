// T-031 QA round 1: edge cases for manual barcode entry.
import 'package:board_game_collector/features/scanner/domain/barcode.dart';
import 'package:board_game_collector/features/scanner/presentation/lookup_result_screen.dart';
import 'package:board_game_collector/features/scanner/presentation/manual_entry_screen.dart';
import 'package:board_game_collector/features/scanner/presentation/scan_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

Finder get _field => find.byType(TextField);
Finder get _submit => find.widgetWithText(FilledButton, 'Look up');

String _text(WidgetTester tester) =>
    tester.widget<TextField>(_field).controller!.text;

Future<void> _open(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(OutlinedButton, 'Enter barcode'));
  await tester.pumpAndSettle();
}

Future<void> _enterAndSubmit(WidgetTester tester, String text) async {
  await tester.enterText(_field, text);
  await tester.pump();
  await tester.tap(_submit);
  await tester.pumpAndSettle();
}

void main() {
  group('paste and typing', () {
    final cases = <String, String>{
      'mixed text keeps the digits, cut at 13':
          'UPC: 036000-291452 (Hasbro) 2020',
      'tabs, newlines, and spaces are dropped': '\t036000\n291452  ',
      'Arabic-Indic digits are dropped': '٠١٢٣٤',
      'Extended Arabic-Indic digits are dropped': '۰۱۲',
      'full-width digits are dropped': '０３６０００',
      'emoji and combining marks are dropped': '0\u{1F600}3́​6',
      'a plus sign and letters are dropped': '+0e3x6',
    };
    final expected = <String, String>{
      'mixed text keeps the digits, cut at 13': '0360002914522',
      'tabs, newlines, and spaces are dropped': '036000291452',
      'Arabic-Indic digits are dropped': '',
      'Extended Arabic-Indic digits are dropped': '',
      'full-width digits are dropped': '',
      'emoji and combining marks are dropped': '036',
      'a plus sign and letters are dropped': '036',
    };
    for (final entry in cases.entries) {
      testWidgets(entry.key, (tester) async {
        await pumpApp(tester);
        await _open(tester);
        await tester.enterText(_field, entry.value);
        await tester.pump();
        expect(_text(tester), expected[entry.key]);
      });
    }

    testWidgets('a very long paste is cut at 13 digits without a crash', (
      tester,
    ) async {
      await pumpApp(tester);
      await _open(tester);
      await tester.enterText(_field, '1234567890' * 5000);
      await tester.pump();
      expect(_text(tester), '1234567890123');
      expect(find.text('13 of 13 digits'), findsOne);
    });

    testWidgets('a very long non-digit paste leaves the field empty', (
      tester,
    ) async {
      await pumpApp(tester);
      await _open(tester);
      await tester.enterText(_field, 'abc ' * 20000);
      await tester.pump();
      expect(_text(tester), isEmpty);
      await tester.tap(_submit);
      await tester.pumpAndSettle();
      expect(find.text('Enter the barcode number.'), findsOne);
    });

    testWidgets('a whitespace-only entry reads as empty', (tester) async {
      await pumpApp(tester);
      await _open(tester);
      await _enterAndSubmit(tester, '   \t ');
      expect(find.text('Enter the barcode number.'), findsOne);
    });

    testWidgets('leading and trailing whitespace around a valid code is '
        'trimmed and the code opens', (tester) async {
      await pumpApp(tester);
      await _open(tester);
      await _enterAndSubmit(tester, '  036000291452 \n');
      expect(
        tester
            .widget<LookupResultScreen>(find.byType(LookupResultScreen))
            .barcode
            .digits,
        '036000291452',
      );
    });

    testWidgets('a paste of two codes is cut and fails the check digit, '
        'not silently accepted', (tester) async {
      await pumpApp(tester);
      await _open(tester);
      await _enterAndSubmit(tester, '036000291452 4006381333931');
      expect(find.byType(LookupResultScreen), findsNothing);
      expect(find.byIcon(Icons.error), findsOne);
    });
  });

  group('lengths and check digits', () {
    // 8, 12, 13 digit valid codes.
    const valid = ['96385074', '036000291452', '4006381333931'];
    for (final code in valid) {
      testWidgets('valid ${code.length}-digit $code opens the result', (
        tester,
      ) async {
        await pumpApp(tester);
        await _open(tester);
        await _enterAndSubmit(tester, code);
        expect(find.byType(LookupResultScreen), findsOne);
      });
    }

    // Each valid code with the last digit changed.
    const badCheck = ['96385075', '036000291453', '4006381333932'];
    for (final code in badCheck) {
      testWidgets('bad check digit on ${code.length} digits: $code', (
        tester,
      ) async {
        await pumpApp(tester);
        await _open(tester);
        await _enterAndSubmit(tester, code);
        expect(find.byType(LookupResultScreen), findsNothing);
        expect(
          find.text(
            'That number does not look right. Check the digits against the '
            'box.',
          ),
          findsOne,
        );
      });
    }

    for (final length in [1, 7, 9, 10, 11]) {
      testWidgets('$length digits is a length error naming $length', (
        tester,
      ) async {
        await pumpApp(tester);
        await _open(tester);
        await _enterAndSubmit(tester, '1' * length);
        expect(
          find.text('A barcode has 8, 12, or 13 digits. You entered $length.'),
          findsOne,
        );
        expect(find.byType(LookupResultScreen), findsNothing);
      });
    }

    testWidgets('a 14-digit GTIN cannot be typed: it is cut to 13', (
      tester,
    ) async {
      await pumpApp(tester);
      await _open(tester);
      // GTIN-14 with a valid check digit: 1 + EAN-13 body of 4006381333931.
      const gtin14 = '14006381333938';
      expect(Barcode.parse(gtin14).isErr, isTrue);
      await tester.enterText(_field, gtin14);
      await tester.pump();
      expect(_text(tester), hasLength(13));
      expect(_text(tester), '1400638133393');
    });

    testWidgets('leading zeros are kept: 8-digit 00000000 style codes', (
      tester,
    ) async {
      await pumpApp(tester);
      await _open(tester);
      // 12-digit all zeros has a valid check digit (sum 0).
      await _enterAndSubmit(tester, '000000000000');
      expect(
        tester
            .widget<LookupResultScreen>(find.byType(LookupResultScreen))
            .barcode
            .digits,
        '000000000000',
      );
    });
  });

  group('rapid and repeated actions', () {
    testWidgets('a double tap on Look up opens one lookup result', (
      tester,
    ) async {
      await pumpApp(tester);
      await _open(tester);
      await tester.enterText(_field, '036000291452');
      await tester.pump();
      // Two taps before any frame is pumped.
      await tester.tap(_submit);
      await tester.tap(_submit, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.byType(LookupResultScreen), findsOne);
      // One Back must return to manual entry, then Scan: no duplicate
      // result may sit in the stack.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(LookupResultScreen), findsNothing);
      expect(find.byType(ManualEntryScreen), findsOne);
    });

    testWidgets('two keyboard actions in a row open one lookup result', (
      tester,
    ) async {
      await pumpApp(tester);
      await _open(tester);
      await tester.enterText(_field, '96385074');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(LookupResultScreen), findsNothing);
    });

    testWidgets('repeated invalid submits announce each time and keep one '
        'error line', (tester) async {
      await pumpApp(tester);
      await _open(tester);
      tester.takeAnnouncements();
      for (var i = 0; i < 3; i++) {
        await tester.tap(_submit);
        await tester.pumpAndSettle();
      }
      expect(find.byIcon(Icons.error), findsOne);
      expect(tester.takeAnnouncements(), hasLength(3));
    });
  });

  group('navigation and the shell', () {
    testWidgets('system Back from manual entry returns to Scan with the bar '
        'back', (tester) async {
      await pumpApp(tester);
      await _open(tester);
      expect(find.byType(NavigationBar), findsNothing);
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(ScanScreen), findsOne);
      expect(find.byType(NavigationBar), findsOne);
    });

    testWidgets('system Back from the lookup result goes to manual entry, '
        'then to Scan', (tester) async {
      await pumpApp(tester);
      await _open(tester);
      await _enterAndSubmit(tester, '96385074');
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(ManualEntryScreen), findsOne);
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(ScanScreen), findsOne);
    });

    testWidgets('on expanded, switching tabs with the field focused keeps '
        'the rail and drops no state', (tester) async {
      await pumpApp(tester, size: WindowSizes.expanded);
      await _open(tester);
      await tester.enterText(_field, '0360');
      await tester.pump();
      await tapDestination(tester, 'Collection');
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsOne);
      await tapDestination(tester, 'Scan');
      await tester.pumpAndSettle();
      // The pushed screen is still there with its text (branch state kept).
      expect(find.byType(ManualEntryScreen), findsOne);
      expect(_text(tester), '0360');
    });

    testWidgets('after returning from another tab on compact, the bar is '
        'hidden only while the field has focus', (tester) async {
      await pumpApp(tester);
      await _open(tester);
      expect(find.byType(NavigationBar), findsNothing);
      tester.binding.focusManager.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOne);
      await tapDestination(tester, 'Search');
      await tester.pumpAndSettle();
      await tapDestination(tester, 'Scan');
      await tester.pumpAndSettle();
      expect(find.byType(ManualEntryScreen), findsOne);
      expect(find.byType(NavigationBar), findsOne);
    });

    testWidgets('rotating the window with text typed keeps the text', (
      tester,
    ) async {
      await pumpApp(tester);
      await _open(tester);
      await tester.enterText(_field, '03600');
      setTestWindow(tester, size: const Size(800, 360));
      await tester.pumpAndSettle();
      expect(_text(tester), '03600');
      expect(tester.takeException(), isNull);
    });
  });

  group('large text and screen reader', () {
    testWidgets('a long error at 2.0 text in phone landscape does not '
        'overflow', (tester) async {
      await pumpApp(tester, size: const Size(800, 360), textScale: 2);
      await _open(tester);
      await tester.enterText(_field, '1' * 11);
      await tester.tap(_submit, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('the field exposes label, counter, and helper in semantics', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        await pumpApp(tester);
        await _open(tester);
        final labels = _fieldLabels();
        expect(labels, contains('0 of 13 digits'));
        expect(
          labels,
          contains('8, 12, or 13 digits, printed under the barcode.'),
        );
      } finally {
        handle.dispose();
      }
    });

    testWidgets('the error is in the field semantics and clears on edit', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        await pumpApp(tester);
        await _open(tester);
        await _enterAndSubmit(tester, '12345');
        expect(
          _fieldLabels(),
          contains('A barcode has 8, 12, or 13 digits. You entered 5.'),
        );
        await tester.enterText(_field, '123456');
        await tester.pumpAndSettle();
        expect(_fieldLabels().where((l) => l.contains('You entered')), isEmpty);
      } finally {
        handle.dispose();
      }
    });
  });
}

/// The label of the field's semantics node and of its children.
List<String> _fieldLabels() {
  final node = find.semantics.byLabel('Barcode number').evaluate().single;
  final labels = <String>[node.label];
  node.visitChildren((child) {
    labels.add(child.label);
    return true;
  });
  return labels;
}
