import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Temporary body for destinations that are not built yet (T-012).
///
/// Scrolls, so large text never overflows. [actions] show under the text,
/// for entry points that already work (for example manual barcode entry on
/// the Scan placeholder, T-031).
class PlaceholderBody extends StatelessWidget {
  const PlaceholderBody({this.actions = const [], super.key});

  /// Buttons shown under the placeholder text.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          children: [
            Text(
              l10n.devPlaceholderBody,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            for (final action in actions) ...[
              const SizedBox(height: 16),
              action,
            ],
          ],
        ),
      ),
    );
  }
}
