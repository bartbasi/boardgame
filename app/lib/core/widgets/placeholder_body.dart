import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Temporary body for destinations that are not built yet (T-012).
///
/// Scrolls, so large text never overflows.
class PlaceholderBody extends StatelessWidget {
  const PlaceholderBody({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Text(
          l10n.devPlaceholderBody,
          style: Theme.of(context).textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
