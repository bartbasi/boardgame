import 'package:flutter/material.dart';

import '../../../core/widgets/placeholder_body.dart';
import '../../../l10n/app_localizations.dart';

/// A screen pushed on top of Collection, standing in for the item and game
/// detail screens until they are built.
class CollectionItemPlaceholderScreen extends StatelessWidget {
  const CollectionItemPlaceholderScreen({required this.number, super.key});

  /// Row number of the placeholder item (1 based).
  final int number;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).devPlaceholderItem(number)),
      ),
      body: const PlaceholderBody(),
    );
  }
}
