import 'package:flutter/material.dart';

import '../../../core/widgets/placeholder_body.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/barcode.dart';

/// Lookup result for one barcode. Placeholder until T-033 builds the lookup
/// (skeleton, match, candidates, none, offline); for now it only shows which
/// code was looked up, so manual entry (T-031) and the scanner (T-030) have
/// a real destination.
class LookupResultScreen extends StatelessWidget {
  const LookupResultScreen({required this.barcode, super.key});

  /// The code to look up, as the user typed or scanned it.
  final Barcode barcode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).lookupTitle(barcode.digits)),
      ),
      body: const PlaceholderBody(),
    );
  }
}
