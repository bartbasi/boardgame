import 'package:flutter/material.dart';

import '../../../core/widgets/placeholder_body.dart';
import '../../../l10n/app_localizations.dart';

/// Scan destination, the start destination. Placeholder until the scanner
/// tickets build the camera view (T-030); the manual entry action already
/// works (T-031).
class ScanScreen extends StatelessWidget {
  const ScanScreen({required this.onManualEntry, super.key});

  /// Opens manual barcode entry (`scanner.actionManual`).
  final VoidCallback onManualEntry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.scannerTitle)),
      body: PlaceholderBody(
        actions: [
          OutlinedButton.icon(
            onPressed: onManualEntry,
            icon: const Icon(Icons.dialpad),
            label: Text(l10n.scannerActionManual),
          ),
        ],
      ),
    );
  }
}
