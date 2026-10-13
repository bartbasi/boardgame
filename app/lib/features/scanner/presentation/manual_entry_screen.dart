import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../core/domain/result.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/barcode.dart';
import 'barcode_field.dart';

/// Manual barcode entry (docs/ux/screens/manual-entry.md, T-031).
///
/// Validates on the device with `Barcode.parse` and makes no network call:
/// a valid code goes to [onSubmit] (the router opens the lookup result,
/// which handles loading and offline). An invalid code shows a copy.md
/// error under the field, keeps focus in the field, and announces the
/// error to screen readers.
class ManualEntryScreen extends StatefulWidget {
  const ManualEntryScreen({
    required this.onSubmit,
    required this.onScanInstead,
    required this.onSearchInstead,
    super.key,
  });

  /// Opens the lookup result for a valid barcode.
  final ValueChanged<Barcode> onSubmit;

  /// `manualEntry.scanInstead`: back to the scanner.
  final VoidCallback onScanInstead;

  /// `manualEntry.searchInstead`: to title search.
  final VoidCallback onSearchInstead;

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

/// The copy.md message for [failure] (manual-entry.md section 4).
///
/// An empty or whitespace-only submit is `wrongLength` with length 0
/// (T-026) and gets `manualEntry.errorEmpty`; only `wrongLength` shows the
/// length.
String manualEntryErrorMessage(
  AppLocalizations l10n,
  InvalidBarcodeFailure failure,
) => switch (failure.reason) {
  InvalidBarcodeReason.wrongLength when failure.length == 0 =>
    l10n.manualEntryErrorEmpty,
  InvalidBarcodeReason.wrongLength => l10n.manualEntryErrorLength(
    failure.length,
  ),
  InvalidBarcodeReason.nonDigit => l10n.manualEntryErrorNonDigit,
  InvalidBarcodeReason.badCheckDigit => l10n.manualEntryErrorCheckDigit,
};

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  InvalidBarcodeFailure? _error;
  String _lastText = '';

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// The error clears as soon as the user edits the field (not on cursor
  /// moves).
  void _onTextChanged() {
    final text = _controller.text;
    if (text == _lastText) return;
    _lastText = text;
    if (_error != null) setState(() => _error = null);
  }

  void _submit() {
    switch (Barcode.parse(_controller.text)) {
      case Ok(:final value):
        widget.onSubmit(value);
      case Err(:final failure):
        // Barcode.parse fails only with InvalidBarcodeFailure.
        final invalid = failure as InvalidBarcodeFailure;
        setState(() => _error = invalid);
        _focusNode.requestFocus();
        final l10n = AppLocalizations.of(context);
        SemanticsService.sendAnnouncement(
          View.of(context),
          l10n.manualEntryErrorAnnouncement(
            manualEntryErrorMessage(l10n, invalid),
          ),
          Directionality.of(context),
          assertiveness: Assertiveness.assertive,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final error = _error;
    final window = MediaQuery.sizeOf(context);
    // Phone landscape: the column sits at the leading 55% so the keyboard
    // does not cover the submit button (manual-entry.md section 2).
    final phoneLandscape = window.width > window.height && window.height < 600;

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BarcodeField(
          controller: _controller,
          focusNode: _focusNode,
          autofocus: true,
          onSubmitted: _submit,
          onClear: () {
            _focusNode.requestFocus();
          },
          errorText: error == null
              ? null
              : manualEntryErrorMessage(l10n, error),
        ),
        const SizedBox(height: 16),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: _submit,
          child: Text(l10n.manualEntrySubmit, textAlign: TextAlign.center),
        ),
        const SizedBox(height: 8),
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: widget.onScanInstead,
          child: Text(l10n.manualEntryScanInstead, textAlign: TextAlign.center),
        ),
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: widget.onSearchInstead,
          child: Text(
            l10n.manualEntrySearchInstead,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.manualEntryTitle)),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(phoneLandscape ? 24 : 16),
        child: phoneLandscape
            ? Align(
                alignment: AlignmentDirectional.topStart,
                child: FractionallySizedBox(widthFactor: 0.55, child: column),
              )
            : Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: column,
                ),
              ),
      ),
    );
  }
}
