import 'package:flutter/material.dart';

import '../../../core/widgets/placeholder_body.dart';
import '../../../l10n/app_localizations.dart';

/// Scan destination, the start destination. Placeholder until the scanner
/// tickets build the camera view.
class ScanScreen extends StatelessWidget {
  const ScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).scannerTitle)),
      body: const PlaceholderBody(),
    );
  }
}
