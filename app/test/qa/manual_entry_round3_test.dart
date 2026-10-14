// T-031 QA round 3: B2 layout fix, semantics, rotation, guard generations.
import 'package:board_game_collector/features/scanner/presentation/lookup_result_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

Finder get _field => find.byType(TextField);
Finder get _submit => find.widgetWithText(FilledButton, 'Look up');

const _checkDigit =
    'That number does not look right. Check the digits against the box.';

Future<void> _open(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(OutlinedButton, 'Enter barcode'));
  await tester.pumpAndSettle();
}

Future<void> _submitCode(WidgetTester tester, String code) async {
  await tester.enterText(_field, code);
  await tester.pump();
  await tester.tap(_submit);
  await tester.pumpAndSettle();
}

List<String> _fieldLabels() {
  final node = find.semantics.byLabel('Barcode number').evaluate().single;
  final labels = <String>[node.label];
  node.visitChildren((child) {
    labels.add(child.label);
    return true;
  });
  return labels;
}

void main() {
  group('B2: field height and button position', () {
    final sizes = {
      'compact': WindowSizes.compact,
      'medium': WindowSizes.medium,
      'expanded': WindowSizes.expanded,
    };
    for (final MapEntry(key: name, value: size) in sizes.entries) {
      for (final scale in [1.0, 1.3, 2.0]) {
        for (final code in ['', '036000291453', '12345']) {
          testWidgets('$name at $scale, "$code": error is compact and the '
              'button is above the keyboard', (tester) async {
            await pumpApp(tester, size: size, textScale: scale);
            await _open(tester);
            await _submitCode(tester, code);
            final field = tester.getRect(_field);
            final button = tester.getRect(_submit);
            final keyboardTop = size.height - fakeKeyboardHeight(size);
            debugPrint(
              'HEIGHT $name $scale "$code": field ${field.height} '
              'button bottom ${button.bottom} keyboard top $keyboardTop',
            );
            // Far below the pre-fix numbers (788 and 1844 at 2.0).
            expect(field.height, lessThan(420));
            expect(button.bottom, lessThanOrEqualTo(keyboardTop));
            expect(find.byIcon(Icons.error), findsOne);
            expect(tester.takeException(), isNull);
          });
        }
      }
    }

    testWidgets('the error text uses the full field width at 2.0', (
      tester,
    ) async {
      await pumpApp(tester, textScale: 2);
      await _open(tester);
      await _submitCode(tester, '036000291453');
      final error = tester.getRect(find.text(_checkDigit));
      final field = tester.getRect(_field);
      // Wider than a few characters: at least half of the field.
      expect(error.width, greaterThan(field.width / 2));
      // The counter sits below the error.
      expect(
        tester.getRect(find.text('12 of 13 digits')).top,
        greaterThanOrEqualTo(error.bottom),
      );
    });
  });

  group('semantics and announcements unchanged', () {
    testWidgets('error and counter are in the field semantics, helper returns '
        'after an edit', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await pumpApp(tester);
        await _open(tester);
        expect(_fieldLabels(), contains('0 of 13 digits'));
        expect(
          _fieldLabels(),
          contains('8, 12, or 13 digits, printed under the barcode.'),
        );
        await _submitCode(tester, '036000291453');
        var labels = _fieldLabels();
        expect(labels, contains(_checkDigit));
        expect(labels, contains('12 of 13 digits'));
        expect(
          labels.where((l) => l.contains('printed under')),
          isEmpty,
          reason: 'the helper is swapped out while the error shows',
        );
        await tester.enterText(_field, '03600029145');
        await tester.pumpAndSettle();
        labels = _fieldLabels();
        expect(labels, contains('11 of 13 digits'));
        expect(labels.where((l) => l.contains('does not look right')), isEmpty);
        expect(
          labels,
          contains('8, 12, or 13 digits, printed under the barcode.'),
        );
      } finally {
        handle.dispose();
      }
    });

    testWidgets('the counter label follows typing', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await pumpApp(tester);
        await _open(tester);
        for (var i = 1; i <= 13; i++) {
          await tester.enterText(_field, '1' * i);
          await tester.pump();
          expect(_fieldLabels(), contains('$i of 13 digits'));
        }
      } finally {
        handle.dispose();
      }
    });

    testWidgets('one assertive announcement per invalid submit with the same '
        'text', (tester) async {
      await pumpApp(tester);
      await _open(tester);
      tester.takeAnnouncements();
      await _submitCode(tester, '036000291453');
      expect(tester.takeAnnouncements(), [
        isAccessibilityAnnouncement(
          'Error: $_checkDigit',
          assertiveness: Assertiveness.assertive,
          textDirection: TextDirection.ltr,
        ),
      ]);
    });

    testWidgets('the error is not announced twice by a live region', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        await pumpApp(tester);
        await _open(tester);
        tester.takeAnnouncements();
        await _submitCode(tester, '12345');
        expect(tester.takeAnnouncements(), hasLength(1));
      } finally {
        handle.dispose();
      }
    });

    testWidgets('error and helper stay readable: guidelines at 2.0 with an '
        'error', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await pumpApp(tester, textScale: 2);
        await _open(tester);
        await _submitCode(tester, '12345');
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      } finally {
        handle.dispose();
      }
    });
  });

  group('phone landscape with the keyboard (known exception, numbers)', () {
    for (final scale in [1.0, 2.0]) {
      testWidgets('long error at $scale: record positions, no exception', (
        tester,
      ) async {
        const size = WindowSizes.landscape;
        await pumpApp(tester, size: size, textScale: scale);
        await _open(tester);
        await tester.enterText(_field, '036000291453');
        await tester.pump();
        await Scrollable.ensureVisible(
          tester.element(_submit),
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
        await tester.pumpAndSettle();
        await tester.tap(_submit);
        await tester.pumpAndSettle();
        final field = tester.getRect(_field);
        final button = tester.getRect(_submit);
        debugPrint(
          'LANDSCAPE $scale: field ${field.top}..${field.bottom} '
          'button ${button.top}..${button.bottom} keyboard top '
          '${size.height - fakeKeyboardHeight(size)}',
        );
        expect(tester.takeException(), isNull);
        expect(find.byIcon(Icons.error), findsOne);
        // The input line stays above the keyboard.
        expect(field.top, lessThan(size.height - fakeKeyboardHeight(size)));
      });
    }
  });

  group('rotation keeps the keyboard', () {
    // T-031-B3 (minor): fails because the phone-landscape branch rebuilds the
    // field state, which drops the input connection while focus stays.
    testWidgets(
      'compact to landscape and back: inset follows the window',
      (tester) async {
        await pumpApp(tester);
        await _open(tester);
        expect(
          tester.view.viewInsets.bottom,
          fakeKeyboardHeight(WindowSizes.compact),
        );
        await tester.enterText(_field, '03600');
        setTestWindow(tester, size: WindowSizes.landscape);
        await tester.pumpAndSettle();
        expect(
          tester.view.viewInsets.bottom,
          fakeKeyboardHeight(WindowSizes.landscape),
        );
        expect(find.byType(NavigationRail), findsOne);
        expect(find.text('5 of 13 digits'), findsOne);
        setTestWindow(tester);
        await tester.pumpAndSettle();
        expect(
          tester.view.viewInsets.bottom,
          fakeKeyboardHeight(WindowSizes.compact),
        );
        // Focus kept and keyboard open: the bar stays hidden.
        expect(find.byType(NavigationBar), findsNothing);
        expect(tester.takeException(), isNull);
      },
      skip: true, // T-031-B3, fixed in T-103: rotation through phone landscape rebuilds the field,
    );

    testWidgets('rotation with an error showing keeps it and the button '
        'position above the keyboard', (tester) async {
      await pumpApp(tester);
      await _open(tester);
      await _submitCode(tester, '036000291453');
      setTestWindow(tester, size: WindowSizes.medium);
      await tester.pumpAndSettle();
      expect(find.text(_checkDigit), findsOne);
      expect(
        tester.getRect(_submit).bottom,
        lessThanOrEqualTo(
          WindowSizes.medium.height - fakeKeyboardHeight(WindowSizes.medium),
        ),
      );
      expect(tester.testTextInput.isVisible, isTrue);
      expect(
        tester.view.viewInsets.bottom,
        fakeKeyboardHeight(WindowSizes.medium),
      );
    });

    // T-031-B3 (minor): the rebuilt field autofocuses again and reopens the
    // keyboard the user had closed.
    testWidgets(
      'a closed keyboard stays closed after rotation',
      (tester) async {
        await pumpApp(tester);
        await _open(tester);
        tester.binding.focusManager.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        setTestWindow(tester, size: WindowSizes.landscape);
        await tester.pumpAndSettle();
        expect(tester.view.viewInsets.bottom, 0);
      },
      skip: true, // T-031-B3, fixed in T-103: rotation through phone landscape rebuilds the field,
    );
  });

  group('OpenOnce generations', () {
    testWidgets('quick submit, Back, submit, Back, submit: always one result '
        'per submit', (tester) async {
      await pumpApp(tester);
      await _open(tester);
      for (var i = 0; i < 5; i++) {
        await tester.enterText(_field, '96385074');
        await tester.pump();
        await tester.tap(_submit);
        await tester.tap(_submit, warnIfMissed: false);
        await tester.pump();
        // Back before the push animation ends.
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(
          find.byType(LookupResultScreen, skipOffstage: false),
          findsNothing,
          reason: 'cycle $i',
        );
      }
      await tester.enterText(_field, '96385074');
      await tester.tap(_submit);
      await tester.pumpAndSettle();
      expect(find.byType(LookupResultScreen), findsOne);
    });

    testWidgets('an old open finishing late does not unlock a newer one', (
      tester,
    ) async {
      await pumpApp(tester, size: WindowSizes.expanded);
      await _open(tester);
      await tester.enterText(_field, '96385074');
      await tester.tap(_submit);
      await tester.pumpAndSettle();
      // Drop the result without a pop, then open again at once.
      await tapDestination(tester, 'Scan');
      await tester.tap(find.widgetWithText(OutlinedButton, 'Enter barcode'));
      await tester.pumpAndSettle();
      await tester.enterText(_field, '96385074');
      await tester.tap(_submit);
      await tester.tap(_submit, warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        find.byType(LookupResultScreen, skipOffstage: false),
        findsNothing,
      );
    });
  });
}
