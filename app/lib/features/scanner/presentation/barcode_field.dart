import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';

/// The BarcodeField component (docs/ux/components.md): a numeric text field
/// that keeps ASCII digits only, stops at [maxDigits], counts the digits,
/// and has a clear button while it has text.
///
/// The parent owns validation: it passes [errorText] after a submit, and
/// clears it when the text changes.
class BarcodeField extends StatelessWidget {
  const BarcodeField({
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    required this.onClear,
    this.errorText,
    this.autofocus = false,
    super.key,
  });

  /// The longest barcode the app accepts (EAN-13).
  static const int maxDigits = 13;

  /// Drops every character that is not an ASCII digit 0 to 9, whether typed
  /// or pasted, then cuts the text at [maxDigits]. Other Unicode digits are
  /// dropped too, because `Barcode.parse` would reject them (T-026).
  static final List<TextInputFormatter> inputFormatters = [
    FilteringTextInputFormatter.allow(RegExp('[0-9]')),
    LengthLimitingTextInputFormatter(maxDigits),
  ];

  /// Holds the typed digits.
  final TextEditingController controller;

  /// Focus of the field; the parent keeps focus here after an error.
  final FocusNode focusNode;

  /// Called by the keyboard's action key. The field keeps focus.
  final VoidCallback onSubmitted;

  /// Called by the clear button, after the text was cleared.
  final VoidCallback onClear;

  /// The error to show under the field with an error icon, or null for the
  /// helper text.
  final String? errorText;

  /// Whether the field takes focus (and opens the keyboard) when shown.
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final error = errorText;
    final helperStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final count = value.text.length;
        return TextField(
          controller: controller,
          focusNode: focusNode,
          autofocus: autofocus,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.search,
          inputFormatters: inputFormatters,
          autocorrect: false,
          enableSuggestions: false,
          // With onEditingComplete set, the keyboard action does not take
          // focus away from the field.
          onEditingComplete: onSubmitted,
          // Scrolls far enough below the field to bring the submit button
          // into view above the keyboard too (manual-entry.md section 2).
          scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 160),
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: l10n.manualEntryFieldLabel,
            // Helper or error, and the digit counter, are drawn together in
            // the counter slot (see _Subtext). The decorator would put them
            // side by side and give the message only the width the counter
            // leaves, which at large text is almost nothing (T-031-B2). The
            // empty error widget keeps the error border and colors.
            error: error == null ? null : const SizedBox.shrink(),
            counter: _Subtext(
              message: error == null
                  ? Text(l10n.manualEntryHelper, style: helperStyle)
                  : _ErrorLine(
                      message: error,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                      iconColor: theme.colorScheme.error,
                    ),
              isError: error != null,
              counter: Text(
                l10n.manualEntryDigitCounter(count),
                style: helperStyle,
                textAlign: TextAlign.end,
              ),
              announceCount: focusNode.hasFocus,
            ),
            suffixIcon: count == 0
                ? null
                : IconButton(
                    tooltip: l10n.itemEditClearField(
                      l10n.manualEntryFieldLabel,
                    ),
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      controller.clear();
                      onClear();
                    },
                  ),
          ),
        );
      },
    );
  }
}

/// The line under the field: the helper or the error at the full width of
/// the field, then the digit counter on its own line at the end.
///
/// Each part is its own semantics node, so screen readers read the helper or
/// error and the counter as parts of the field, as with the decorator's own
/// helper and counter.
class _Subtext extends StatelessWidget {
  const _Subtext({
    required this.message,
    required this.isError,
    required this.counter,
    required this.announceCount,
  });

  final Widget message;
  final bool isError;
  final Widget counter;

  /// Whether counter changes are announced (while the field has focus, as
  /// the decorator does for its counter).
  final bool announceCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          container: true,
          // The screen announces a new error itself (manual entry); where
          // announcements are not supported, the error is a live region,
          // as the decorator's own error is.
          liveRegion: isError && !MediaQuery.supportsAnnounceOf(context),
          child: message,
        ),
        Semantics(container: true, liveRegion: announceCount, child: counter),
      ],
    );
  }
}

/// Error text with an error icon, so the error is not shown by color alone.
class _ErrorLine extends StatelessWidget {
  const _ErrorLine({
    required this.message,
    required this.style,
    required this.iconColor,
  });

  final String message;
  final TextStyle? style;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Decorative: the text says the same thing.
        Icon(Icons.error, size: 16, color: iconColor),
        const SizedBox(width: 4),
        Flexible(child: Text(message, style: style)),
      ],
    );
  }
}
